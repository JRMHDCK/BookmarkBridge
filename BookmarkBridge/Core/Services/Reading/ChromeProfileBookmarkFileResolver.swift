//
//  ChromeProfileBookmarkFileResolver.swift
//  BookmarkBridge
//

import Foundation

nonisolated enum ChromeBookmarkFileKind: Hashable, Sendable {
    case local
    case account
}

nonisolated struct ResolvedChromeBookmarkFile: Hashable, Sendable {
    let url: URL
    let kind: ChromeBookmarkFileKind
}

/// Resolves the bookmark file that Chrome actually uses for one profile.
///
/// The dashboard already distinguishes the local `Bookmarks` store from the
/// account-backed `AccountBookmarks` store. Synchronization must make the same
/// decision instead of reconstructing a local filename unconditionally.
nonisolated protocol ChromeProfileBookmarkFileResolving: Sendable {
    func resolve(
        profileDirectory: String,
        in chromeDirectory: BrowserLocation
    ) throws -> ResolvedChromeBookmarkFile
}

nonisolated struct DefaultChromeProfileBookmarkFileResolver:
    ChromeProfileBookmarkFileResolving
{
    private let fileAccess: any FileAccessProviding
    private let profileLocator: any ChromeProfileLocating
    private let decoder: any BookmarkDecoding
    private let readData: @Sendable (URL) throws -> Data

    init(
        fileAccess: any FileAccessProviding = SandboxFileAccessProvider(),
        profileLocator: any ChromeProfileLocating =
            DefaultChromeProfileLocator(),
        decoder: any BookmarkDecoding = ChromeBookmarkDecoder(),
        readData: @escaping @Sendable (URL) throws -> Data = {
            try Data(contentsOf: $0)
        }
    ) {
        self.fileAccess = fileAccess
        self.profileLocator = profileLocator
        self.decoder = decoder
        self.readData = readData
    }

    func resolve(
        profileDirectory: String,
        in chromeDirectory: BrowserLocation
    ) throws -> ResolvedChromeBookmarkFile {
        try fileAccess.withReadOnlyAccess(to: chromeDirectory) { directoryURL in
            guard let profile = try profileLocator.profiles(in: directoryURL)
                .first(where: {
                    $0.profileDirectoryName == profileDirectory
                }) else {
                throw BookmarkError.sourceNotFound(.chrome)
            }
            return try resolvedFile(for: profile)
        }
    }

    private func resolvedFile(
        for profile: ChromeProfileLocation
    ) throws -> ResolvedChromeBookmarkFile {
        switch profile.storage {
        case .bookmarks(let url):
            return ResolvedChromeBookmarkFile(url: url, kind: .local)
        case .account(let url):
            return ResolvedChromeBookmarkFile(url: url, kind: .account)
        case .ambiguous(let bookmarks, let account):
            // Match dashboard discovery: an empty account store does not make
            // an otherwise local profile ambiguous.
            if let data = try? readData(account),
               let tree = try? decoder.decodeTree(from: data),
               tree.bookmarkCount == 0 {
                return ResolvedChromeBookmarkFile(
                    url: bookmarks,
                    kind: .local
                )
            }
            throw BookmarkError.multipleBookmarkStores(.chrome)
        }
    }
}
