//
//  SafariImportDeltaTreeBuilder.swift
//  BookmarkBridge
//

import Foundation

/// Converts only planned creations into an immutable bookmark tree. Existing
/// Chrome bookmarks are deliberately excluded so Safari's additive importer
/// cannot duplicate the whole source library.
nonisolated struct SafariImportDeltaTreeBuilder: Sendable {
    func build(from plan: SynchronizationPlan) -> BookmarkTree {
        let analyzer = SafariImportCompatibilityAnalyzer()
        let creations: [CreateNodeOperation] = plan.operations.compactMap {
            operation -> CreateNodeOperation? in
            guard analyzer.supports(operation),
                  case .create(let creation) = operation else { return nil }
            return creation
        }
        var foldersByID: [LogicalNodeID: CreateNodeOperation] = [:]
        var childrenByParent: [LogicalNodeID: [CreateNodeOperation]] = [:]
        for creation in creations {
            if creation.kind == NodeKind.folder {
                foldersByID[creation.logicalNodeID] = creation
            }
            if let parentID = creation.parentID {
                childrenByParent[parentID, default: []].append(creation)
            }
        }
        let topLevel = creations.filter { creation in
            guard let parentID = creation.parentID else { return true }
            return foldersByID[parentID] == nil
        }.sorted(by: creationOrder)

        var roots: [BookmarkFolder] = topLevel.compactMap { creation in
            guard creation.kind == .folder else { return nil }
            return folder(
                creation,
                childrenByParent: childrenByParent
            )
        }
        let rootBookmarks = topLevel.compactMap(bookmark)
        if !rootBookmarks.isEmpty {
            roots.append(BookmarkFolder(
                id: BookmarkID("bookmarkbridge-import-root"),
                title: "BookmarkBridge Import",
                children: rootBookmarks.map(BookmarkNode.bookmark)
            ))
        }

        return BookmarkTree(
            browser: .chrome,
            roots: roots,
            capturedAt: .distantPast
        )
    }

    private func folder(
        _ creation: CreateNodeOperation,
        childrenByParent:
            [LogicalNodeID: [CreateNodeOperation]]
    ) -> BookmarkFolder {
        let children = (childrenByParent[creation.logicalNodeID] ?? [])
            .sorted(by: creationOrder)
            .compactMap { child -> BookmarkNode? in
                switch child.kind {
                case .folder:
                    return .folder(folder(
                        child,
                        childrenByParent: childrenByParent
                    ))
                case .bookmark:
                    return bookmark(child).map(BookmarkNode.bookmark)
                }
            }
        return BookmarkFolder(
            id: bookmarkID(for: creation.logicalNodeID),
            title: creation.title,
            children: children
        )
    }

    private func bookmark(
        _ creation: CreateNodeOperation
    ) -> Bookmark? {
        guard creation.kind == .bookmark,
              let url = creation.url else { return nil }
        return Bookmark(
            id: bookmarkID(for: creation.logicalNodeID),
            title: creation.title,
            url: url
        )
    }

    private func bookmarkID(for logicalNodeID: LogicalNodeID) -> BookmarkID {
        BookmarkID("bookmarkbridge-import:\(logicalNodeID.description)")
    }

    private func creationOrder(
        _ lhs: CreateNodeOperation,
        _ rhs: CreateNodeOperation
    ) -> Bool {
        if lhs.position != rhs.position {
            return lhs.position < rhs.position
        }
        return lhs.logicalNodeID < rhs.logicalNodeID
    }
}
