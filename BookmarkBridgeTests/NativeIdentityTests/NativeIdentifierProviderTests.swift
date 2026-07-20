//
//  NativeIdentifierProviderTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Native Identifier Provider")
struct NativeIdentifierProviderTests {
    @Test("The default provider returns a non-empty opaque identifier")
    func generatesIdentifier() {
        let identifier = UUIDNativeIdentifierProvider().makeIdentifier()

        #expect(!identifier.rawValue.isEmpty)
    }

    @Test("The default provider generates distinct identifiers")
    func generatesDistinctIdentifiers() {
        let provider = UUIDNativeIdentifierProvider()
        let identifiers = (0..<128).map { _ in provider.makeIdentifier() }

        #expect(Set(identifiers).count == identifiers.count)
    }

    @Test("UUID representation is immediately encapsulated")
    func encapsulatesGeneratedValue() {
        let identifier = UUIDNativeIdentifierProvider().makeIdentifier()

        #expect(UUID(uuidString: identifier.rawValue) != nil)
    }

    @Test("A deterministic provider can replace the default implementation")
    func deterministicProvider() throws {
        let expected = NativeNodeIdentifier("deterministic-native-id")
        let provider: any NativeIdentifierProviding = DeterministicNativeIdentifierProvider(
            identifier: expected
        )

        #expect(try provider.makeIdentifier() == expected)
        #expect(try provider.makeIdentifier() == expected)
    }

    @Test("Provider errors propagate without reinterpretation")
    func errorPropagation() {
        let provider: any NativeIdentifierProviding = FailingNativeIdentifierProvider()

        #expect(throws: NativeIdentifierProviderTestError.unavailable) {
            _ = try provider.makeIdentifier()
        }
    }

    @Test("Providers cross Swift Concurrency boundaries")
    func strictConcurrency() {
        let defaultProvider = UUIDNativeIdentifierProvider()
        let deterministicProvider = DeterministicNativeIdentifierProvider(
            identifier: NativeNodeIdentifier("fixed")
        )

        requireSendable(defaultProvider)
        requireSendable(defaultProvider as any NativeIdentifierProviding)
        requireSendable(deterministicProvider)
    }

    @Test("Production providers contain no concrete browser dependency")
    func browserAgnosticProductionSources() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let nativeIdentityDirectory = repositoryRoot.appendingPathComponent(
            "BookmarkBridge/Core/Services/BSE/NativeIdentity"
        )
        let providerFiles = [
            "NativeIdentifierProviding.swift",
            "UUIDNativeIdentifierProvider.swift",
        ]

        for fileName in providerFiles {
            let source = try String(
                contentsOf: nativeIdentityDirectory.appendingPathComponent(fileName),
                encoding: .utf8
            ).lowercased()
            #expect(!source.contains("safari"))
            #expect(!source.contains("chrome"))
        }
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}

private nonisolated struct DeterministicNativeIdentifierProvider: NativeIdentifierProviding {
    let identifier: NativeNodeIdentifier

    func makeIdentifier() -> NativeNodeIdentifier {
        identifier
    }
}

private nonisolated struct FailingNativeIdentifierProvider: NativeIdentifierProviding {
    func makeIdentifier() throws -> NativeNodeIdentifier {
        throw NativeIdentifierProviderTestError.unavailable
    }
}

private nonisolated enum NativeIdentifierProviderTestError: Error {
    case unavailable
}
