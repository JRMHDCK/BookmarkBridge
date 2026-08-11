//
//  DashboardSynchronizationPreviewComposition.swift
//  BookmarkBridge
//

import CryptoKit
import Foundation

/// Production request composition for the read-only Dashboard preview.
///
/// Locations come from the same persisted security-scoped bookmarks as the V1
/// readers. Source identities are derived deterministically from the browser
/// and Chrome profile, so repeated previews address the same BSE sources.
nonisolated struct DashboardSynchronizationPreviewRequestProvider:
    SynchronizationPreviewRequestProviding
{
    private let safariLocator: any BookmarkSourceLocating
    private let chromeLocator: any BookmarkSourceLocating
    private let chromeBookmarkFileResolver:
        any ChromeProfileBookmarkFileResolving

    init(
        safariLocator: any BookmarkSourceLocating,
        chromeLocator: any BookmarkSourceLocating,
        chromeBookmarkFileResolver:
            any ChromeProfileBookmarkFileResolving =
                DefaultChromeProfileBookmarkFileResolver()
    ) {
        self.safariLocator = safariLocator
        self.chromeLocator = chromeLocator
        self.chromeBookmarkFileResolver = chromeBookmarkFileResolver
    }

    func makeRequest(
        safariSource: BookmarkSource,
        chromeSource: BookmarkSource,
        direction: ProductionSynchronizationDirection
    ) async throws -> SynchronizationPreviewRequest {
        guard safariSource.browser == .safari,
              chromeSource.browser == .chrome,
              let profile = chromeSource.id.profile else {
            throw DashboardSynchronizationPreviewCompositionError.invalidSources
        }

        let safariLocation = try safariLocator.locate(.safari)
        let chromeDirectory = try chromeLocator.locate(.chrome)
        let profileIdentifier = try ChromeProfileIdentifier(profile)
        let chromeBookmarkFile = try chromeBookmarkFileResolver.resolve(
            profileDirectory: profile,
            in: chromeDirectory
        )
        if direction == .safariToChrome,
           chromeBookmarkFile.kind == .account {
            throw SynchronizationPreviewRequestError
                .readOnlyChromeDestination
        }

        return SynchronizationPreviewRequest(
            direction: direction,
            safariSourceID: Self.sourceID(for: safariSource.id),
            chromeSourceID: Self.sourceID(for: chromeSource.id),
            safariBookmarksURL: safariLocation.fileURL,
            chromeBookmarksURL: chromeBookmarkFile.url,
            chromeProfileIdentifier: profileIdentifier,
            safariSecurityScopeURL: safariLocation.fileURL,
            chromeSecurityScopeURL: chromeDirectory.fileURL
        )
    }

    private static func sourceID(
        for source: BookmarkSourceID
    ) -> BSESourceID {
        let seed = [
            "bookmarkbridge",
            "bse-source",
            "v1",
            source.browser.rawValue,
            source.profile ?? "default",
        ].joined(separator: ":")
        var bytes = Array(SHA256.hash(data: Data(seed.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        let uuid = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
        return BSESourceID(uuid)
    }
}

nonisolated private enum DashboardSynchronizationPreviewCompositionError:
    Error
{
    case invalidSources
}

/// Production identity source injected into BSE reconciliation.
nonisolated struct UUIDLogicalIdentityProvider: IdentityProvider {
    func nextLogicalNodeID() throws -> LogicalNodeID {
        LogicalNodeID(UUID())
    }
}

/// Deterministic failure boundary used only if the empty baseline cannot be
/// initialized. It keeps composition total without a force-try or fatal error.
nonisolated struct UnavailableSynchronizationPreviewService:
    SynchronizationPreviewProviding
{
    func preview(
        request: SynchronizationPreviewRequest
    ) async throws -> SynchronizationPreviewResult {
        throw DashboardSynchronizationPreviewCompositionError.invalidSources
    }
}
