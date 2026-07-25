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
}
