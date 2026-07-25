//
//  ProductionSynchronizationSessionCoordinatorTests.swift
//  BookmarkBridgeTests
//

import Testing
@testable import BookmarkBridge

@Suite("BSE-793 Production Synchronization Serialization")
struct ProductionSynchronizationSessionCoordinatorTests {
    @Test("Concurrent sessions on one instance execute FIFO without overlap")
    func sameInstanceIsFIFOAndDoesNotOverlap() async throws {
        let coordinator = ProductionSynchronizationSessionCoordinator()
        let firstGate = ProductionSessionTestGate()
        let recorder = ProductionSessionRecorder()

        let first = Task {
            try await coordinator.withSession {
                await recorder.enter("first")
                await firstGate.wait()
                await recorder.leave("first")
            }
        }
        try await waitUntil {
            await recorder.events == ["first.start"]
        }

        let second = Task {
            try await coordinator.withSession {
                await recorder.enter("second")
                await recorder.leave("second")
            }
        }
        try await waitUntil {
            await coordinator.waitingSessionCount == 1
        }

        let third = Task {
            try await coordinator.withSession {
                await recorder.enter("third")
                await recorder.leave("third")
            }
        }
        try await waitUntil {
            await coordinator.waitingSessionCount == 2
        }

        #expect(await recorder.events == ["first.start"])
        await firstGate.open()
        try await first.value
        try await second.value
        try await third.value

        #expect(await recorder.maximumActiveCount == 1)
        #expect(await recorder.events == [
            "first.start",
            "first.end",
            "second.start",
            "second.end",
            "third.start",
            "third.end"
        ])
    }

    @Test("A failed first session releases the next FIFO waiter")
    func failureDoesNotPoisonTheQueue() async throws {
        let coordinator = ProductionSynchronizationSessionCoordinator()
        let failureGate = ProductionSessionTestGate()
        let recorder = ProductionSessionRecorder()

        let first = Task {
            try await coordinator.withSession {
                await recorder.enter("first")
                await failureGate.wait()
                await recorder.leave("first")
                throw ProductionSessionTestError.expected
            }
        }
        try await waitUntil {
            await recorder.events == ["first.start"]
        }

        let second = Task {
            try await coordinator.withSession {
                await recorder.enter("second")
                await recorder.leave("second")
            }
        }
        try await waitUntil {
            await coordinator.waitingSessionCount == 1
        }

        await failureGate.open()
        await #expect(throws: ProductionSessionTestError.expected) {
            try await first.value
        }
        try await second.value

        #expect(await recorder.maximumActiveCount == 1)
        #expect(await recorder.events == [
            "first.start",
            "first.end",
            "second.start",
            "second.end"
        ])
    }

    @Test("Restoration completes before the next session starts")
    func restorationCompletesBeforeNextSession() async throws {
        let coordinator = ProductionSynchronizationSessionCoordinator()
        let restorationGate = ProductionSessionTestGate()
        let events = ProductionSessionEventLog()

        let first = Task {
            try await coordinator.withSession {
                await events.append("first.write")
                await events.append("first.restore.start")
                await restorationGate.wait()
                await events.append("first.restore.end")
                throw ProductionSessionTestError.expected
            }
        }
        try await waitUntil {
            await events.values.last == "first.restore.start"
        }

        let second = Task {
            try await coordinator.withSession {
                await events.append("second.start")
            }
        }
        try await waitUntil {
            await coordinator.waitingSessionCount == 1
        }

        #expect(!(await events.values.contains("second.start")))
        await restorationGate.open()
        await #expect(throws: ProductionSessionTestError.expected) {
            try await first.value
        }
        try await second.value

        #expect(await events.values == [
            "first.write",
            "first.restore.start",
            "first.restore.end",
            "second.start"
        ])
    }

    @Test("Distinct service coordinators do not share a global lock")
    func distinctInstancesCanOverlap() async throws {
        let firstCoordinator = ProductionSynchronizationSessionCoordinator()
        let secondCoordinator = ProductionSynchronizationSessionCoordinator()
        let gate = ProductionSessionTestGate()
        let recorder = ProductionSessionRecorder()

        let first = Task {
            try await firstCoordinator.withSession {
                await recorder.enter("first")
                await gate.wait()
                await recorder.leave("first")
            }
        }
        let second = Task {
            try await secondCoordinator.withSession {
                await recorder.enter("second")
                await gate.wait()
                await recorder.leave("second")
            }
        }

        try await waitUntil {
            await recorder.activeCount == 2
        }
        #expect(await recorder.maximumActiveCount == 2)

        await gate.open()
        try await first.value
        try await second.value
    }

    @Test("Cancelling a queued session removes it and preserves FIFO progress")
    func queuedCancellationDoesNotBlockFollowingSessions() async throws {
        let coordinator = ProductionSynchronizationSessionCoordinator()
        try await coordinator.acquire()

        let cancelled = Task {
            try await coordinator.withSession {}
        }
        try await waitUntil {
            await coordinator.waitingSessionCount == 1
        }
        cancelled.cancel()
        try await waitUntil {
            await coordinator.waitingSessionCount == 0
        }

        let events = ProductionSessionEventLog()
        let following = Task {
            try await coordinator.withSession {
                await events.append("following.start")
            }
        }
        try await waitUntil {
            await coordinator.waitingSessionCount == 1
        }

        await coordinator.release()
        await #expect(throws: CancellationError.self) {
            try await cancelled.value
        }
        try await following.value
        #expect(await events.values == ["following.start"])
    }

    private func waitUntil(
        _ condition: @escaping @Sendable () async -> Bool
    ) async throws {
        for _ in 0..<10_000 {
            if await condition() {
                return
            }
            await Task.yield()
        }
        throw ProductionSessionTestError.timeout
    }
}

private enum ProductionSessionTestError: Error {
    case expected
    case timeout
}

private actor ProductionSessionTestGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        for waiter in pending {
            waiter.resume()
        }
    }
}

private actor ProductionSessionEventLog {
    private(set) var values: [String] = []

    func append(_ value: String) {
        values.append(value)
    }
}

private actor ProductionSessionRecorder {
    private(set) var events: [String] = []
    private(set) var activeCount = 0
    private(set) var maximumActiveCount = 0

    func enter(_ session: String) {
        activeCount += 1
        maximumActiveCount = max(maximumActiveCount, activeCount)
        events.append("\(session).start")
    }

    func leave(_ session: String) {
        events.append("\(session).end")
        activeCount -= 1
    }
}
