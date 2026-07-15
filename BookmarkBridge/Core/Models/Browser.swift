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
}
