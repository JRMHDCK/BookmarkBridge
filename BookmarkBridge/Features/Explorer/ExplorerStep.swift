//
//  ExplorerStep.swift
//  BookmarkBridge
//

import Foundation

/// One level of the explorer navigation stack: either a source's root level or a
/// folder within it. Used as the typed navigation path value (wired in a later
/// step) and as the input to the breadcrumb mapper.
nonisolated enum ExplorerStep: Hashable, Sendable {
    case source(BookmarkSource, BookmarkTree)
    case folder(BookmarkFolder)
}

extension ExplorerStep {
    /// The navigation path that reveals a search hit in the explorer: the source,
    /// then each ancestor folder resolved from `tree`.
    ///
    /// A folder hit ends on the folder itself (opening its contents); a bookmark
    /// hit ends on its parent folder, where the bookmark is listed. This produces
    /// the very same `[ExplorerStep]` the dashboard already navigates with, so
    /// selecting a result reuses the existing navigation — no separate routing.
    /// Purely read-only tree traversal.
    ///
    /// Implemented with plain loops (no closures): under `MainActor` default
    /// isolation, closure literals in this `nonisolated` extension would be
    /// inferred main-actor-isolated and trap when run off the main actor.
    nonisolated static func path(to result: BookmarkSearchResult, in tree: BookmarkTree) -> [ExplorerStep] {
        var steps: [ExplorerStep] = [.source(result.source, tree)]
        var level = tree.roots
        for component in result.path {
            var match: BookmarkFolder?
            for folder in level where folder.id == component.id {
                match = folder
                break
            }
            guard let folder = match else { return steps }
            steps.append(.folder(folder))
            var childFolders: [BookmarkFolder] = []
            for node in folder.children {
                if case .folder(let child) = node {
                    childFolders.append(child)
                }
            }
            level = childFolders
        }
        if case .folder(let folder) = result.node {
            steps.append(.folder(folder))
        }
        return steps
    }
}
