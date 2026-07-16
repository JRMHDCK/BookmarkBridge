//
//  Breadcrumb.swift
//  BookmarkBridge
//

import Foundation

/// One clickable crumb in the explorer breadcrumb trail.
///
/// `path` is the navigation path to apply when the crumb is tapped (the prefix
/// up to and including this level), so the view stays free of navigation logic.
/// The last crumb (`isCurrent`) represents the current level and is not tappable.
nonisolated struct BreadcrumbItem: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let isCurrent: Bool
    let path: [ExplorerStep]
}

/// The breadcrumb trail for a given explorer path, built by a testable mapper.
/// Root folder names use the same friendly titles as the explorer.
nonisolated struct Breadcrumb: Equatable, Sendable {
    let items: [BreadcrumbItem]

    init(items: [BreadcrumbItem]) {
        self.items = items
    }

    init(path: [ExplorerStep]) {
        self.items = path.enumerated().map { index, step in
            BreadcrumbItem(
                id: index,
                title: Self.title(for: step),
                isCurrent: index == path.count - 1,
                path: Array(path.prefix(index + 1))
            )
        }
    }

    private static func title(for step: ExplorerStep) -> String {
        switch step {
        case .source(let source, _):
            source.displayName
        case .folder(let folder):
            FolderPresentation.displayTitle(folder.title)
        }
    }
}
