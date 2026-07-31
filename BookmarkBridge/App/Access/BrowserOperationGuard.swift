//
//  BrowserOperationGuard.swift
//  BookmarkBridge
//

import AppKit
import Foundation

@MainActor
protocol BrowserLifecycleControlling: AnyObject {
    func runningBrowsers() -> Set<Browser>
    func closeAndWait(for browsers: Set<Browser>) async throws
}

@MainActor
final class SystemBrowserLifecycleController: BrowserLifecycleControlling {
    private let timeout: Duration
    private let pollInterval: Duration

    init(
        timeout: Duration = .seconds(10),
        pollInterval: Duration = .milliseconds(100)
    ) {
        self.timeout = timeout
        self.pollInterval = pollInterval
    }

    func runningBrowsers() -> Set<Browser> {
        Set(Browser.allCases.filter { browser in
            !applications(for: browser).isEmpty
        })
    }

    func closeAndWait(for browsers: Set<Browser>) async throws {
        for browser in browsers.sorted(by: { $0.rawValue < $1.rawValue }) {
            let runningApplications = applications(for: browser)
            guard runningApplications.allSatisfy({ $0.terminate() }) else {
                throw BrowserOperationGuardError.terminationRequestFailed(
                    browser
                )
            }
        }

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !runningBrowsers().isDisjoint(with: browsers) {
            guard clock.now < deadline else {
                throw BrowserOperationGuardError.terminationTimedOut(
                    runningBrowsers().intersection(browsers).sorted {
                        $0.rawValue < $1.rawValue
                    }
                )
            }
            try await Task.sleep(for: pollInterval)
        }
    }

    private func applications(for browser: Browser) -> [NSRunningApplication] {
        NSRunningApplication.runningApplications(
            withBundleIdentifier: browser.bundleIdentifier
        )
    }
}

nonisolated enum BrowserOperationGuardError: Error, Hashable, Sendable {
    case terminationRequestFailed(Browser)
    case terminationTimedOut([Browser])
}

@MainActor
final class BrowserOperationGuard {
    private let lifecycleController: any BrowserLifecycleControlling

    init(lifecycleController: any BrowserLifecycleControlling) {
        self.lifecycleController = lifecycleController
    }

    func runningBrowsers() -> [Browser] {
        lifecycleController.runningBrowsers().sorted {
            $0.rawValue < $1.rawValue
        }
    }

    func closeAndWait(for browsers: [Browser]) async throws {
        try await lifecycleController.closeAndWait(for: Set(browsers))
        let stillRunning = lifecycleController.runningBrowsers()
            .intersection(browsers)
        guard stillRunning.isEmpty else {
            throw BrowserOperationGuardError.terminationTimedOut(
                stillRunning.sorted { $0.rawValue < $1.rawValue }
            )
        }
    }
}
