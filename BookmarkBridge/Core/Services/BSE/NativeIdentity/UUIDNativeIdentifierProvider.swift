//
//  UUIDNativeIdentifierProvider.swift
//  BookmarkBridge
//

import Foundation

/// Default, stateless generator. UUID is confined to this implementation and
/// immediately erased behind the opaque native identifier value.
nonisolated struct UUIDNativeIdentifierProvider: NativeIdentifierProviding {
    func makeIdentifier() -> NativeNodeIdentifier {
        NativeNodeIdentifier(UUID().uuidString)
    }
}
