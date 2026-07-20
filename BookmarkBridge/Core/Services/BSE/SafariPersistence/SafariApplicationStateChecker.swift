//
//  SafariApplicationStateChecker.swift
//  BookmarkBridge
//

import AppKit

nonisolated struct SafariApplicationStateChecker: SafariApplicationStateChecking {
    private let isSafariRunning: @Sendable () -> Bool

    init(isSafariRunning: @escaping @Sendable () -> Bool = {
        !NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.Safari"
        ).isEmpty
    }) {
        self.isSafariRunning = isSafariRunning
    }

    func ensureSafariIsClosed() throws {
        guard !isSafariRunning() else {
            throw SafariPersistenceError.safariIsOpen
        }
    }
}
