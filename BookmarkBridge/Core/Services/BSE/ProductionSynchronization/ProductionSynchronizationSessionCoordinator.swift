//
//  ProductionSynchronizationSessionCoordinator.swift
//  BookmarkBridge
//

/// Per-service asynchronous FIFO gate. Ownership is retained across suspension
/// points, unlike ordinary actor method isolation, so one complete production
/// session finishes before the next begins.
actor ProductionSynchronizationSessionCoordinator {
    private struct Waiter {
        let id: UInt64
        let continuation: CheckedContinuation<Void, any Error>
    }

    private var isSessionActive = false
    private var nextWaiterID: UInt64 = 0
    private var waiters: [Waiter] = []

    func withSession<Result: Sendable>(
        _ operation: @Sendable () async throws -> Result
    ) async throws -> Result {
        try await acquire()
        do {
            try Task.checkCancellation()
            let result = try await operation()
            release()
            return result
        } catch {
            release()
            throw error
        }
    }

    func acquire() async throws {
        try Task.checkCancellation()
        guard isSessionActive else {
            isSessionActive = true
            return
        }

        let waiterID = nextWaiterID
        nextWaiterID &+= 1
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters.append(Waiter(
                    id: waiterID,
                    continuation: continuation
                ))
            }
        } onCancel: {
            Task {
                await self.cancel(waiterID: waiterID)
            }
        }
    }

    func release() {
        guard isSessionActive else { return }
        guard !waiters.isEmpty else {
            isSessionActive = false
            return
        }
        let waiter = waiters.removeFirst()
        waiter.continuation.resume()
    }

    var waitingSessionCount: Int {
        waiters.count
    }

    private func cancel(waiterID: UInt64) {
        guard let index = waiters.firstIndex(where: {
            $0.id == waiterID
        }) else {
            return
        }
        let waiter = waiters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }
}
