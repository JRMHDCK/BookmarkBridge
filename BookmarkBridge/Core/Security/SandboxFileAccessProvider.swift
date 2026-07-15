//
//  SandboxFileAccessProvider.swift
//  BookmarkBridge
//

import Foundation

/// A `FileAccessProviding` that manages security-scoped access in the App
/// Sandbox, strictly read-only.
///
/// Contract:
/// 1. Begin scoped access (if the URL is security-scoped).
/// 2. Verify the file exists and is readable, else throw a typed error.
/// 3. Run `body` with the URL.
/// 4. **Always** release scoped access on the way out (`defer`), so a scope that
///    was started is never leaked — even if `body` throws.
nonisolated struct SandboxFileAccessProvider: FileAccessProviding {
    private let controller: SecurityScopedFileControlling

    init(controller: SecurityScopedFileControlling = SystemSecurityScopedFileController()) {
        self.controller = controller
    }

    func withReadOnlyAccess<T>(
        to location: BrowserLocation,
        _ body: (URL) throws -> T
    ) throws -> T {
        let url = location.fileURL

        let didStartAccess = controller.startAccessing(url)
        defer {
            if didStartAccess {
                controller.stopAccessing(url)
            }
        }

        guard controller.fileExists(at: url) else {
            throw BookmarkError.sourceNotFound(location.browser)
        }
        guard controller.isReadable(at: url) else {
            throw BookmarkError.accessDenied(location)
        }

        return try body(url)
    }
}
