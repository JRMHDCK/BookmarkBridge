//
//  BrowserSourceProviding.swift
//  BookmarkBridge
//

import Foundation

/// Discovers the readable sources of a browser and provides a reader for each.
///
/// A single-profile browser (Safari) yields one reader; a multi-profile browser
/// (Chrome) yields one reader per profile, discovered dynamically. Discovery may
/// require authorization: implementations throw `BookmarkError.authorizationRequired`
/// when access has not been granted.
nonisolated protocol BrowserSourceProviding: Sendable {
    var browser: Browser { get }

    /// Builds a reader per discovered source. Read-only.
    func makeReaders() async throws -> [BookmarkReading]
}
