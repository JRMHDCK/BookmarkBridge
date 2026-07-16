//
//  BookmarkMatchKeyTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BookmarkMatchKey")
struct BookmarkMatchKeyTests {

    private func key(_ string: String) -> String {
        BookmarkMatchKey.key(for: URL(string: string)!)
    }

    @Test("Scheme and host are case-insensitive")
    func caseInsensitiveSchemeHost() {
        #expect(key("HTTPS://Example.COM/Path") == key("https://example.com/Path"))
    }

    @Test("Trailing slashes are ignored, including the root")
    func trailingSlashIgnored() {
        #expect(key("https://example.com/foo/") == key("https://example.com/foo"))
        #expect(key("https://example.com/") == key("https://example.com"))
    }

    @Test("The path case is preserved (distinct pages stay distinct)")
    func pathCasePreserved() {
        #expect(key("https://example.com/Path") != key("https://example.com/path"))
    }

    @Test("Distinct queries stay distinct")
    func distinctQueries() {
        #expect(key("https://example.com/s?q=1") != key("https://example.com/s?q=2"))
    }

    @Test("The fragment is preserved")
    func fragmentPreserved() {
        #expect(key("https://example.com/p#a") != key("https://example.com/p#b"))
    }

    // MARK: - Tracking parameters

    @Test("Known tracking parameters are dropped")
    func dropsTrackingParameters() {
        let bare = key("https://example.com/p")
        #expect(key("https://example.com/p?utm_source=nl&utm_medium=email") == bare)
        #expect(key("https://example.com/p?fbclid=abc") == bare)
        #expect(key("https://example.com/p?gclid=abc") == bare)
        #expect(key("https://example.com/p?msclkid=abc") == bare)
        #expect(key("https://example.com/p?dclid=abc") == bare)
        #expect(key("https://example.com/p?mc_cid=abc&mc_eid=def") == bare)
        #expect(key("https://example.com/p?UTM_Source=x") == bare)   // case-insensitive
    }

    @Test("Non-tracking parameters are kept; tracking ones are stripped around them")
    func keepsMeaningfulParameters() {
        #expect(key("https://example.com/p?id=123") != key("https://example.com/p"))
        #expect(key("https://example.com/p?page=2") != key("https://example.com/p?page=3"))
        // Only the tracking part is removed, the rest is preserved.
        #expect(key("https://example.com/p?id=123&utm_source=x") == key("https://example.com/p?id=123"))
    }
}
