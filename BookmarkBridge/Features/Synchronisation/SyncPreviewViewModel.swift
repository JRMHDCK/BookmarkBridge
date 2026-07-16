//
//  SyncPreviewViewModel.swift
//  BookmarkBridge
//

import Foundation
import Observation

/// Presentation state for the dry-run preview. It only orchestrates: it asks the
/// `BookmarkSyncPlanner` for a `SyncPreview` and maps it to display rows. No
/// matching/ranking logic lives here, and nothing is ever written.
@MainActor
@Observable
final class SyncPreviewViewModel {

    /// A single bookmark that would be added to one side.
    struct Addition: Identifiable {
        let id: String
        let title: String
        let subtitle: String?
        /// Full origin path, e.g. "Safari › Barre des favoris › Dev".
        let originPath: String
    }

    /// The additions heading to one target browser.
    struct Direction: Identifiable {
        let id: String
        let targetName: String
        let additions: [Addition]
    }

    private(set) var directions: [Direction] = []
    private(set) var totalChanges = 0
    private(set) var isEmpty = true

    private let planner: BookmarkSyncPlanner

    init(planner: BookmarkSyncPlanner = BookmarkSyncPlanner()) {
        self.planner = planner
    }

    /// Computes the read-only preview between two loaded sources.
    func computePreview(
        _ a: (source: BookmarkSource, tree: BookmarkTree),
        _ b: (source: BookmarkSource, tree: BookmarkTree)
    ) {
        let preview = planner.preview(between: a.tree, and: b.tree)
        totalChanges = preview.totalChanges
        isEmpty = preview.isEmpty

        let names: [Browser: String] = [
            a.source.browser: a.source.displayName,
            b.source.browser: b.source.displayName,
        ]

        directions = preview.plans.compactMap { plan in
            let additions = plan.changes.compactMap { change in Self.addition(from: change, sourceBrowser: plan.source, names: names) }
            guard !additions.isEmpty else { return nil }
            return Direction(
                id: plan.target.rawValue,
                targetName: names[plan.target] ?? plan.target.displayName,
                additions: additions
            )
        }
    }

    private static func addition(from change: SyncChange, sourceBrowser: Browser, names: [Browser: String]) -> Addition? {
        guard case .add(let node, _, let sourcePath) = change, case .bookmark(let bookmark) = node else {
            return nil
        }
        let sourceName = names[sourceBrowser] ?? sourceBrowser.displayName
        let origin = ([sourceName] + sourcePath.map { FolderTitleFormatter.friendly($0.title) })
            .joined(separator: " › ")
        return Addition(
            id: "\(sourceBrowser.rawValue)|\(bookmark.id.rawValue)",
            title: bookmark.title.isEmpty ? "(Sans titre)" : bookmark.title,
            subtitle: bookmark.url.host() ?? bookmark.url.absoluteString,
            originPath: origin
        )
    }
}
