//
//  ProductionSynchronizationRequest.swift
//  BookmarkBridge
//

import Foundation

nonisolated enum ProductionSynchronizationDirection: Hashable, Sendable {
    case safariToChrome
    case chromeToSafari
}

/// Explicit browser locations for one unidirectional production execution.
nonisolated struct ProductionSynchronizationRequest: Hashable, Sendable {
    let direction: ProductionSynchronizationDirection
    let safariSourceID: BSESourceID
    let chromeSourceID: BSESourceID
    let safariBookmarksURL: URL
    let chromeBookmarksURL: URL
    let safariBackupDirectoryURL: URL
    let chromeBackupDirectoryURL: URL
    let chromeProfileIdentifier: ChromeProfileIdentifier
    let safariSecurityScopeURL: URL
    let chromeSecurityScopeURL: URL

    init(
        direction: ProductionSynchronizationDirection,
        safariSourceID: BSESourceID,
        chromeSourceID: BSESourceID,
        safariBookmarksURL: URL,
        chromeBookmarksURL: URL,
        safariBackupDirectoryURL: URL,
        chromeBackupDirectoryURL: URL,
        chromeProfileIdentifier: ChromeProfileIdentifier,
        safariSecurityScopeURL: URL? = nil,
        chromeSecurityScopeURL: URL? = nil
    ) {
        self.direction = direction
        self.safariSourceID = safariSourceID
        self.chromeSourceID = chromeSourceID
        self.safariBookmarksURL = safariBookmarksURL
        self.chromeBookmarksURL = chromeBookmarksURL
        self.safariBackupDirectoryURL = safariBackupDirectoryURL
        self.chromeBackupDirectoryURL = chromeBackupDirectoryURL
        self.chromeProfileIdentifier = chromeProfileIdentifier
        self.safariSecurityScopeURL =
            safariSecurityScopeURL ?? safariBookmarksURL
        self.chromeSecurityScopeURL =
            chromeSecurityScopeURL ?? chromeBookmarksURL
    }
}
