//
//  SecurityScopedFileControlling.swift
//  BookmarkBridge
//

import Foundation

/// The low-level security-scoped file operations used by `FileAccessProviding`.
///
/// Extracting these behind a protocol keeps `SandboxFileAccessProvider` free of
/// direct system calls, so its behaviour (start/stop balancing, error handling)
/// is unit-testable with a spy — without touching the real filesystem or Safari.
nonisolated protocol SecurityScopedFileControlling: Sendable {
    func fileExists(at url: URL) -> Bool
    func isReadable(at url: URL) -> Bool
    /// Begins security-scoped access. Returns `false` for URLs that are not
    /// security-scoped (e.g. plain temporary files), which is not an error.
    func startAccessing(_ url: URL) -> Bool
    func stopAccessing(_ url: URL)
}

/// The production implementation, backed by `FileManager` and `URL`'s
/// security-scoped resource API.
nonisolated struct SystemSecurityScopedFileController: SecurityScopedFileControlling {
    init() {}

    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    func isReadable(at url: URL) -> Bool {
        FileManager.default.isReadableFile(atPath: url.path(percentEncoded: false))
    }

    func startAccessing(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}
