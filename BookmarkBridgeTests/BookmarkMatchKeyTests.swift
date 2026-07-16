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
}
