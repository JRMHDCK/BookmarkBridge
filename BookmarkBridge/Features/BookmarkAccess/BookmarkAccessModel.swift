//
//  BookmarkAccessModel.swift
//  BookmarkBridge
//

import Foundation

nonisolated enum BookmarkAccessStatus: Equatable, Sendable {
    case ok
    case fileMissing
    case authorizationMissing
    case authorizationInvalid

    @MainActor
    var label: String {
        switch self {
        case .ok: DocumentationText.value("access.status.ok")
        case .fileMissing: DocumentationText.value("access.status.fileMissing")
        case .authorizationMissing:
            DocumentationText.value("access.status.authorizationMissing")
        case .authorizationInvalid:
            DocumentationText.value("access.status.authorizationInvalid")
        }
    }
}

nonisolated struct SafariBookmarkAccess: Equatable, Sendable {
    let detectedURL: URL
    let authorizedURL: URL?
    let status: BookmarkAccessStatus
}

nonisolated struct ChromeProfileAccess: Identifiable, Equatable, Sendable {
    let directoryName: String
    let profileName: String
    let bookmarksURL: URL

    var id: String { directoryName }
}

nonisolated struct ChromeBookmarkAccess: Equatable, Sendable {
    let authorizedDirectoryURL: URL?
    let profiles: [ChromeProfileAccess]
    let status: BookmarkAccessStatus
}

nonisolated struct BookmarkAccessSnapshot: Equatable, Sendable {
    let safari: SafariBookmarkAccess
    let chrome: ChromeBookmarkAccess
}

@MainActor
protocol BookmarkAccessManaging: Sendable {
    func inspectAccess() async -> BookmarkAccessSnapshot
    func testAccess(
        for browser: Browser,
        chromeProfileDirectory: String?
    ) async -> BookmarkAccessStatus
    func reauthorize(_ browser: Browser) async throws -> Bool
}

@MainActor
protocol ChromeProfileSelectionStoring: Sendable {
    func selectedProfileDirectory() -> String?
    func saveSelectedProfileDirectory(_ directory: String?)
}
