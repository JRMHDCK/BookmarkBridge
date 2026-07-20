//
//  ChromeApplicationStateCheckerTests.swift
//  BookmarkBridgeTests
//

import Testing
@testable import BookmarkBridge

@Suite("Chrome application state checker")
struct ChromeApplicationStateCheckerTests {
    @Test("The proven Google Chrome bundle identifier is used")
    func bundleIdentifier() {
        #expect(ChromeApplicationStateChecker.bundleIdentifier == "com.google.Chrome")
    }

    @Test("Closed Chrome is accepted")
    func closed() throws {
        try ChromeApplicationStateChecker(isChromeRunning: { false })
            .ensureChromeIsClosed()
    }

    @Test("Running Chrome is rejected")
    func open() {
        #expect(throws: ChromePersistenceError.chromeIsOpen) {
            try ChromeApplicationStateChecker(isChromeRunning: { true })
                .ensureChromeIsClosed()
        }
    }

    @Test("Checker satisfies Sendable")
    func strictConcurrency() {
        requireSendable(ChromeApplicationStateChecker(isChromeRunning: { false }))
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}
