//
//  BrowserBundleIdentifierTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Browser bundle identifiers")
struct BrowserBundleIdentifierTests {

    @Test("Each browser maps to its macOS bundle identifier")
    func bundleIdentifiers() {
        #expect(Browser.safari.bundleIdentifier == "com.apple.Safari")
        #expect(Browser.chrome.bundleIdentifier == "com.google.Chrome")
    }

    @Test("A double drives the running/closed decision")
    func detectorDouble() {
        struct StubDetector: RunningBrowserDetecting {
            let running: Set<Browser>
            func isRunning(_ browser: Browser) -> Bool { running.contains(browser) }
        }
        let detector = StubDetector(running: [.chrome])
        #expect(detector.isRunning(.chrome))
        #expect(detector.isRunning(.safari) == false)
    }
}
