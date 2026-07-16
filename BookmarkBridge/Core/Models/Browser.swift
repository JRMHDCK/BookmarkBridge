//
//  Browser.swift
//  BookmarkBridge
//

import Foundation

/// A web browser whose bookmarks BookmarkBridge can read.
///
/// Supporting a new browser is an additive change (Open/Closed): declare a case
/// here and provide the matching `Core/Services` implementations — no existing
/// type needs to change.
nonisolated enum Browser: String, Sendable, Codable, CaseIterable, Identifiable {
    case safari
    case chrome

    var id: String { rawValue }

    /// Human-readable name for display in the UI.
    var displayName: String {
        switch self {
        case .safari: "Safari"
        case .chrome: "Google Chrome"
        }
    }

    /// The macOS bundle identifier, used to detect whether the browser is
    /// running before attempting a write (writing must never race the browser).
    var bundleIdentifier: String {
        switch self {
        case .safari: "com.apple.Safari"
        case .chrome: "com.google.Chrome"
        }
    }
}
