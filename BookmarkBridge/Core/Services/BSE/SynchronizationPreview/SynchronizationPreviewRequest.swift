//
//  SynchronizationPreviewRequest.swift
//  BookmarkBridge
//

import Foundation

/// Explicit locations and source identities for one browser-neutral preview.
nonisolated struct SynchronizationPreviewRequest: Hashable, Sendable {
    let direction: ProductionSynchronizationDirection
    let safariSourceID: BSESourceID
    let chromeSourceID: BSESourceID
    let safariBookmarksURL: URL
    let chromeBookmarksURL: URL
    let chromeProfileIdentifier: ChromeProfileIdentifier
    /// The resource selected by the user for Safari. This is normally the
    /// bookmarks file itself.
    let safariSecurityScopeURL: URL
    /// The resource selected by the user for Chrome. Chrome authorization is
    /// granted for its data directory, not for a derived profile file.
    let chromeSecurityScopeURL: URL

    init(
        direction: ProductionSynchronizationDirection,
        safariSourceID: BSESourceID,
        chromeSourceID: BSESourceID,
        safariBookmarksURL: URL,
        chromeBookmarksURL: URL,
        chromeProfileIdentifier: ChromeProfileIdentifier,
        safariSecurityScopeURL: URL? = nil,
        chromeSecurityScopeURL: URL? = nil
    ) {
        self.direction = direction
        self.safariSourceID = safariSourceID
        self.chromeSourceID = chromeSourceID
        self.safariBookmarksURL = safariBookmarksURL
        self.chromeBookmarksURL = chromeBookmarksURL
        self.chromeProfileIdentifier = chromeProfileIdentifier
        self.safariSecurityScopeURL =
            safariSecurityScopeURL ?? safariBookmarksURL
        self.chromeSecurityScopeURL =
            chromeSecurityScopeURL ?? chromeBookmarksURL
    }
}
