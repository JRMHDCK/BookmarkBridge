//
//  BookmarkDecoding.swift
//  BookmarkBridge
//

import Foundation

/// Decodes a browser's raw bookmark data into the domain `BookmarkTree`.
///
/// Isolating format concerns (Safari binary plist, Chrome JSON) behind this
/// protocol keeps the domain independent of file formats (Dependency Inversion).
/// Decoding is a pure transformation of already-read `Data`; it performs no I/O
/// and never touches the source file.
nonisolated protocol BookmarkDecoding: Sendable {
    /// The browser whose format this decoder understands.
    var browser: Browser { get }

    /// Decodes previously read `data` into a tree.
    func decodeTree(from data: Data) throws -> BookmarkTree
}
