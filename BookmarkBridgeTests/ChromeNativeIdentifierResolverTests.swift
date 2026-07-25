//
//  ChromeNativeIdentifierResolverTests.swift
//  BookmarkBridgeTests
//

import Testing
@testable import BookmarkBridge

@Suite("BSE Chrome native identifier resolver")
struct ChromeNativeIdentifierResolverTests {
    private let resolver = ChromeNativeIdentifierResolver()

    @Test("A valid GUID is preferred and carries the Chrome id continuity proof")
    func GUIDPreferred() throws {
        let result = try resolver.resolve(chromeID: "42", chromeGUID: "abc")

        #expect(result.nativeIdentifier == NativeNodeIdentifier("guid:abc"))
        #expect(result.kind == .chromeGUID)
        #expect(result.continuityIdentifier == NativeNodeIdentifier("id:42"))
        #expect(result.continuityKind == .chromeIDFallback)
        #expect(result.chromeID == "42")
        #expect(result.chromeGUID == "abc")
    }

    @Test(
        "An absent or invalid GUID falls back to a valid Chrome id",
        arguments: [nil, "", " ", "guid:abc"]
    )
    func IDFallback(chromeGUID: String?) throws {
        let result = try resolver.resolve(chromeID: "42", chromeGUID: chromeGUID)

        #expect(result.nativeIdentifier == NativeNodeIdentifier("id:42"))
        #expect(result.kind == .chromeIDFallback)
        #expect(result.continuityIdentifier == nil)
        #expect(result.continuityKind == nil)
    }

    @Test("A valid GUID remains authoritative when the Chrome id is invalid")
    func GUIDWinsOverInvalidID() throws {
        let result = try resolver.resolve(chromeID: "not-numeric", chromeGUID: "abc")

        #expect(result.nativeIdentifier == NativeNodeIdentifier("guid:abc"))
        #expect(result.continuityIdentifier == nil)
    }

    @Test(
        "No valid native identity is rejected explicitly",
        arguments: [nil, "", "-1", "not-numeric"]
    )
    func invalidID(chromeID: String?) {
        #expect(throws: ChromeNativeIdentifierError.noValidIdentifier(
            chromeID: chromeID,
            chromeGUID: nil
        )) {
            _ = try resolver.resolve(chromeID: chromeID, chromeGUID: nil)
        }
    }

    @Test("GUID and id namespaces cannot collide")
    func namespacesDoNotCollide() throws {
        let GUID = try resolver.resolve(chromeID: nil, chromeGUID: "123")
        let ID = try resolver.resolve(chromeID: "123", chromeGUID: nil)

        #expect(GUID.nativeIdentifier == NativeNodeIdentifier("guid:123"))
        #expect(ID.nativeIdentifier == NativeNodeIdentifier("id:123"))
        #expect(GUID.nativeIdentifier != ID.nativeIdentifier)
    }

    @Test("Resolution is deterministic and Sendable")
    func deterministicAndSendable() throws {
        let first = try resolver.resolve(chromeID: "42", chromeGUID: "abc")
        let second = try resolver.resolve(chromeID: "42", chromeGUID: "abc")

        #expect(first == second)
        requireSendable(resolver)
        requireSendable(first)
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}
