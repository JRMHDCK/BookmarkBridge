//
//  SynchronizationPreviewRequest.swift
//  BookmarkBridge
//

import Foundation

nonisolated enum SynchronizationSelectionScope: Hashable, Sendable {
    case all
    case nativeIdentifiers(
        Set<String>,
        excludingSemanticKeys: Set<String> = []
    )
}

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
    let safariSelection: SynchronizationSelectionScope
    let chromeSelection: SynchronizationSelectionScope

    init(
        direction: ProductionSynchronizationDirection,
        safariSourceID: BSESourceID,
        chromeSourceID: BSESourceID,
        safariBookmarksURL: URL,
        chromeBookmarksURL: URL,
        chromeProfileIdentifier: ChromeProfileIdentifier,
        safariSecurityScopeURL: URL? = nil,
        chromeSecurityScopeURL: URL? = nil,
        safariSelection: SynchronizationSelectionScope = .all,
        chromeSelection: SynchronizationSelectionScope = .all
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
        self.safariSelection = safariSelection
        self.chromeSelection = chromeSelection
    }

    func selecting(
        safari safariSelection: SynchronizationSelectionScope,
        chrome chromeSelection: SynchronizationSelectionScope
    ) -> Self {
        Self(
            direction: direction,
            safariSourceID: safariSourceID,
            chromeSourceID: chromeSourceID,
            safariBookmarksURL: safariBookmarksURL,
            chromeBookmarksURL: chromeBookmarksURL,
            chromeProfileIdentifier: chromeProfileIdentifier,
            safariSecurityScopeURL: safariSecurityScopeURL,
            chromeSecurityScopeURL: chromeSecurityScopeURL,
            safariSelection: safariSelection,
            chromeSelection: chromeSelection
        )
    }
}
