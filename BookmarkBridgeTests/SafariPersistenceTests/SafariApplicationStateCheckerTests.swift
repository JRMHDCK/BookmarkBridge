//
//  SafariApplicationStateCheckerTests.swift
//  BookmarkBridgeTests
//

import Testing
@testable import BookmarkBridge

@Suite("Safari application state checker")
struct SafariApplicationStateCheckerTests {
    @Test("Closed Safari allows persistence")
    func safariClosed() throws {
        try SafariApplicationStateChecker(isSafariRunning: { false })
            .ensureSafariIsClosed()
    }

    @Test("Open Safari is rejected explicitly")
    func safariOpen() {
        let checker = SafariApplicationStateChecker(isSafariRunning: { true })

        #expect(throws: SafariApplicationStateError.safariIsOpen) {
            try checker.ensureSafariIsClosed()
        }
    }

    @Test("State checking contract is Sendable")
    func strictConcurrency() {
        let checker = SafariApplicationStateChecker(isSafariRunning: { false })
        requireSendable(checker)
        requireSendable(checker as any SafariApplicationStateChecking)
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}
