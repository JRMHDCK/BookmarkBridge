//
//  NativeIdentifierProviding.swift
//  BookmarkBridge
//

/// Injectable source of opaque native identities for write-side components.
/// Consumers depend only on `NativeNodeIdentifier`, never on a generation
/// format or concrete generator.
nonisolated protocol NativeIdentifierProviding: Sendable {
    func makeIdentifier() throws -> NativeNodeIdentifier
}
