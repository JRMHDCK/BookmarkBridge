//
//  ChromeLocalStateFixtureTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Chrome Local State fixture (raw JSON)")
struct ChromeLocalStateFixtureTests {

    typealias JSON = [String: Any]

    private func infoCache() throws -> JSON {
        let object = try #require(
            try JSONSerialization.jsonObject(with: ChromeLocalStateFixture.data()) as? JSON
        )
        let profile = try #require(object["profile"] as? JSON)
        return try #require(profile["info_cache"] as? JSON)
    }

    @Test("Maps each profile directory to its user-facing name")
    func mapsProfileNames() throws {
        let cache = try infoCache()
        let defaultEntry = try #require(cache[ChromeLocalStateFixture.Expected.defaultDir] as? JSON)
        let secondEntry = try #require(cache[ChromeLocalStateFixture.Expected.secondDir] as? JSON)
        #expect(defaultEntry["name"] as? String == ChromeLocalStateFixture.Expected.defaultName)
        #expect(secondEntry["name"] as? String == ChromeLocalStateFixture.Expected.secondName)
    }

    @Test("The fixture is deterministic")
    func isDeterministic() {
        let first = ChromeLocalStateFixture.propertyList() as NSDictionary
        #expect(first.isEqual(to: ChromeLocalStateFixture.propertyList() as [AnyHashable: Any]))
    }

    @Test("The fixture contains no personal data")
    func containsNoPersonalData() throws {
        let text = String(decoding: try ChromeLocalStateFixture.data(), as: UTF8.self).lowercased()
        for token in ["jerome", "jérôme", "bricks.co", "@bricks"] {
            #expect(!text.contains(token), "fixture leaked personal token: \(token)")
        }
    }
}
