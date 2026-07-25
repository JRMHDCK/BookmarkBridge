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
}
