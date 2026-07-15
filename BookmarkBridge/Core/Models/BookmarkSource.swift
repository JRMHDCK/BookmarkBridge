//
//  BookmarkSource.swift
//  BookmarkBridge
//

import Foundation

/// A stable identity for a readable bookmark source.
///
/// A "source" is a browser, optionally narrowed to a specific profile. Safari
/// has a single profile (`profile == nil`); Chrome has one source per profile,
/// identified by its **directory name** (`"Default"`, `"Profile 1"`) — stable
/// even when the user renames the profile.
nonisolated struct BookmarkSourceID: Hashable, Sendable, Codable {
    let browser: Browser
    let profile: String?

    init(browser: Browser, profile: String? = nil) {
        self.browser = browser
        self.profile = profile
    }
}

/// A readable bookmark source: its stable identity plus a user-facing name.
nonisolated struct BookmarkSource: Hashable, Sendable, Identifiable {
    let id: BookmarkSourceID
    let displayName: String

    init(id: BookmarkSourceID, displayName: String) {
        self.id = id
        self.displayName = displayName
    }

    init(browser: Browser, profile: String? = nil, displayName: String) {
        self.init(id: BookmarkSourceID(browser: browser, profile: profile), displayName: displayName)
    }

    /// The browser this source belongs to.
    var browser: Browser { id.browser }

    /// A source for a single-profile browser (e.g. Safari), named after the browser.
    static func singleProfile(_ browser: Browser) -> BookmarkSource {
        BookmarkSource(browser: browser, displayName: browser.displayName)
    }
}
