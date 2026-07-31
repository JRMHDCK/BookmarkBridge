//
//  BrowserOperationGuardTests.swift
//  BookmarkBridgeTests
//

import Testing
@testable import BookmarkBridge

@MainActor
@Suite("Browser operation guard")
struct BrowserOperationGuardTests {
    @Test("Reports every running browser before protected work")
    func reportsRunningBrowsers() {
        let controller = StubBrowserLifecycleController(
            running: [.chrome, .safari]
        )
        let guardService = BrowserOperationGuard(
            lifecycleController: controller
        )

        #expect(guardService.runningBrowsers() == [.chrome, .safari])
    }

    @Test("Graceful closure waits until every browser is stopped")
    func closesAndWaits() async throws {
        let controller = StubBrowserLifecycleController(
            running: [.chrome, .safari]
        )
        let guardService = BrowserOperationGuard(
            lifecycleController: controller
        )

        try await guardService.closeAndWait(for: [.safari, .chrome])

        #expect(controller.closeRequests == [Set([.safari, .chrome])])
        #expect(guardService.runningBrowsers().isEmpty)
    }

    @Test("A failed graceful closure blocks the protected operation")
    func closureFailure() async {
        let controller = StubBrowserLifecycleController(
            running: [.chrome],
            error: .terminationRequestFailed(.chrome)
        )
        let guardService = BrowserOperationGuard(
            lifecycleController: controller
        )

        await #expect(throws: BrowserOperationGuardError
            .terminationRequestFailed(.chrome)) {
            try await guardService.closeAndWait(for: [.chrome])
        }
        #expect(guardService.runningBrowsers() == [.chrome])
    }
}

@MainActor
private final class StubBrowserLifecycleController:
    BrowserLifecycleControlling
{
    var running: Set<Browser>
    let error: BrowserOperationGuardError?
    private(set) var closeRequests: [Set<Browser>] = []

    init(
        running: Set<Browser>,
        error: BrowserOperationGuardError? = nil
    ) {
        self.running = running
        self.error = error
    }

    func runningBrowsers() -> Set<Browser> {
        running
    }

    func closeAndWait(for browsers: Set<Browser>) async throws {
        closeRequests.append(browsers)
        if let error { throw error }
        running.subtract(browsers)
    }
}
