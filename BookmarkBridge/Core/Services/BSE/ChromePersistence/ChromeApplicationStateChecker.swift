//
//  ChromeApplicationStateChecker.swift
//  BookmarkBridge
//

import AppKit

/// All supported Chrome profiles share the same application process.
nonisolated struct ChromeApplicationStateChecker: ChromeApplicationStateChecking {
    static let bundleIdentifier = "com.google.Chrome"

    private let isChromeRunning: @Sendable () -> Bool

    init(isChromeRunning: @escaping @Sendable () -> Bool = {
        !NSRunningApplication.runningApplications(
            withBundleIdentifier: Self.bundleIdentifier
        ).isEmpty
    }) {
        self.isChromeRunning = isChromeRunning
    }

    func ensureChromeIsClosed() throws {
        guard !isChromeRunning() else {
            throw ChromePersistenceError.chromeIsOpen
        }
    }
}
