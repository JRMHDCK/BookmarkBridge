//
//  ChromeNativeIdentifier.swift
//  BookmarkBridge
//

/// One resolved Chrome identity. Canonical values are namespaced so a Chrome
/// `guid` and numeric `id` with equal text can never collide.
nonisolated struct ChromeNativeIdentifier: Hashable, Sendable {
    let nativeIdentifier: NativeNodeIdentifier
    let kind: NativeIdentityKind
    let continuityIdentifier: NativeNodeIdentifier?
    let continuityKind: NativeIdentityKind?
    let chromeID: String?
    let chromeGUID: String?
}
