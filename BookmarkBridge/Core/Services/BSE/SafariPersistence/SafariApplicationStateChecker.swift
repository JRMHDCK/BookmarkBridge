//
//  SafariApplicationStateChecker.swift
//  BookmarkBridge
//

import AppKit

nonisolated enum SafariApplicationStateError: Error, Hashable, Sendable {
    case safariIsOpen
}

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
            throw SafariApplicationStateError.safariIsOpen
        }
    }
}
