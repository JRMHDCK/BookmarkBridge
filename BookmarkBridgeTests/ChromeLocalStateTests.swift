//
//  ChromeLocalStateTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("ChromeLocalState")
struct ChromeLocalStateTests {

    @Test("Maps profile directories to their user-facing names")
    func mapsDirectoriesToNames() throws {
        let names = ChromeLocalState.profileNames(from: try ChromeLocalStateFixture.data())
        #expect(names == [
            ChromeLocalStateFixture.Expected.defaultDir: ChromeLocalStateFixture.Expected.defaultName,
            ChromeLocalStateFixture.Expected.secondDir: ChromeLocalStateFixture.Expected.secondName,
        ])
    }

    @Test("Returns an empty map for unreadable data")
    func emptyForGarbage() {
        #expect(ChromeLocalState.profileNames(from: Data("not json".utf8)).isEmpty)
    }

    @Test("Returns an empty map when info_cache is missing")
    func emptyWhenInfoCacheMissing() throws {
        let data = try JSONSerialization.data(withJSONObject: ["profile": ["last_used": "Default"]])
        #expect(ChromeLocalState.profileNames(from: data).isEmpty)
    }
}
