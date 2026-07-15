//
//  BookmarkAuthorizationRequesting.swift
//  BookmarkBridge
//

import Foundation

/// Requests interactive authorization to read a browser's bookmarks, persisting
/// it so future launches need no prompt.
///
/// This is the ViewModel's abstraction over the (UI-driven) authorization flow.
/// It keeps the ViewModel free of AppKit and of the concrete coordinator: the
/// concrete implementation (which presents `NSOpenPanel`) is injected from the
/// app layer.
///
/// - Returns: `true` if access was granted and persisted; `false` if the user
///   simply cancelled (no error to surface).
/// - Throws: for genuine failures (wrong file, bookmark/persistence failure).
@MainActor
protocol BookmarkAuthorizationRequesting {
    func requestAuthorization(for browser: Browser) async throws -> Bool
}
