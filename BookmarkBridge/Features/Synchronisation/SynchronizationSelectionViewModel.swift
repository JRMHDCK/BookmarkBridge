//
//  SynchronizationSelectionViewModel.swift
//  BookmarkBridge
//

import Foundation
import Observation

/// Session-only selection state for the trees displayed before a BSE preview.
@MainActor
@Observable
final class SynchronizationSelectionViewModel {
    private(set) var sources: [SearchableSource] = []
    private var selectedIDs: [BookmarkSourceID: Set<BookmarkID>] = [:]
    private var knownIDs: [BookmarkSourceID: Set<BookmarkID>] = [:]
    private var counterpartExclusions: Set<String> = []

    func configure(sources: [SearchableSource]) {
        self.sources = sources
        for source in sources {
            let all = Set(Self.flatten(source.tree).map(\.id))
            let previousKnown = knownIDs[source.source.id] ?? []
            if var selected = selectedIDs[source.source.id] {
                selected.formIntersection(all)
                selected.formUnion(all.subtracting(previousKnown))
                selectedIDs[source.source.id] = selected
            } else {
                selectedIDs[source.source.id] = all
            }
            knownIDs[source.source.id] = all
        }
    }

    func isSelected(_ node: BookmarkNode, in sourceID: BookmarkSourceID) -> Bool {
        selectedIDs[sourceID]?.contains(node.id) ?? true
    }

    func isPartiallySelected(
        _ node: BookmarkNode,
        in sourceID: BookmarkSourceID
    ) -> Bool {
        let ids = Set(Self.flatten(node).map(\.id))
        let selectedCount = ids.intersection(selectedIDs[sourceID] ?? ids).count
        return selectedCount > 0 && selectedCount < ids.count
    }

    func sourceIsSelected(_ source: SearchableSource) -> Bool {
        let all = Set(Self.flatten(source.tree).map(\.id))
        return all.isSubset(of: selectedIDs[source.source.id] ?? all)
    }

    func sourceIsPartiallySelected(_ source: SearchableSource) -> Bool {
        let all = Set(Self.flatten(source.tree).map(\.id))
        let count = all.intersection(selectedIDs[source.source.id] ?? all).count
        return count > 0 && count < all.count
    }

    func hasSelection(for sourceID: BookmarkSourceID) -> Bool {
        !(selectedIDs[sourceID] ?? knownIDs[sourceID] ?? []).isEmpty
    }

    var canPreview: Bool {
        sources.contains {
            $0.source.browser == .safari && hasSelection(for: $0.source.id)
        } && sources.contains {
            $0.source.browser == .chrome && hasSelection(for: $0.source.id)
        }
    }

    func toggleSource(_ source: SearchableSource) {
        let all = Set(Self.flatten(source.tree).map(\.id))
        let shouldSelect = !all.isSubset(of: selectedIDs[source.source.id] ?? all)
        set(all, selected: shouldSelect, in: source.source.id)
    }

    func toggle(_ node: BookmarkNode, in source: SearchableSource) {
        let subtreeIDs = Set(Self.flatten(node).map(\.id))
        let selected = selectedIDs[source.source.id] ?? knownIDs[source.source.id] ?? []
        let shouldSelect = !subtreeIDs.isSubset(of: selected)
        set(subtreeIDs, selected: shouldSelect, in: source.source.id)
        let semanticKeys = Set(Self.flatten(node).map(Self.semanticKey))
        if shouldSelect {
            counterpartExclusions.subtract(semanticKeys)
        } else {
            counterpartExclusions.formUnion(semanticKeys)
        }
        if shouldSelect {
            selectAncestors(of: node.id, in: source)
        }
        propagateCounterparts(of: node, selected: shouldSelect, excluding: source.source.id)
    }

    func scope(for sourceID: BookmarkSourceID) -> SynchronizationSelectionScope {
        guard let known = knownIDs[sourceID],
              let selected = selectedIDs[sourceID],
              selected != known || !counterpartExclusions.isEmpty else {
            return .all
        }
        return .nativeIdentifiers(
            Set(selected.map { nativeIdentifier($0, for: sourceID.browser) }),
            excludingSemanticKeys: counterpartExclusions
        )
    }

    private func set(
        _ ids: Set<BookmarkID>,
        selected: Bool,
        in sourceID: BookmarkSourceID
    ) {
        var current = selectedIDs[sourceID] ?? knownIDs[sourceID] ?? []
        if selected {
            current.formUnion(ids)
        } else {
            current.subtract(ids)
        }
        selectedIDs[sourceID] = current
    }

    private func selectAncestors(of id: BookmarkID, in source: SearchableSource) {
        let parents = Self.parentIDs(in: source.tree)
        var current = parents[id]
        while let parent = current {
            set([parent], selected: true, in: source.source.id)
            current = parents[parent]
        }
    }

    /// Mirror a node toggle to unambiguous semantic counterparts. This keeps a
    /// filtered source and target symmetrical, so exclusion alone cannot appear
    /// to BSE as a deletion. Ambiguous duplicate URLs are intentionally left
    /// independent instead of guessing.
    private func propagateCounterparts(
        of node: BookmarkNode,
        selected: Bool,
        excluding sourceID: BookmarkSourceID
    ) {
        let key = Self.semanticKey(for: node)
        for source in sources where source.source.id != sourceID {
            let matches = Self.flatten(source.tree).filter {
                Self.semanticKey(for: $0) == key
            }
            guard matches.count == 1 else { continue }
            let match = matches[0]
            set(
                Set(Self.flatten(match).map(\.id)),
                selected: selected,
                in: source.source.id
            )
            if selected {
                selectAncestors(of: match.id, in: source)
            }
        }
    }

    private func nativeIdentifier(
        _ id: BookmarkID,
        for browser: Browser
    ) -> String {
        switch browser {
        case .safari:
            return id.rawValue
        case .chrome:
            let raw = id.rawValue.hasPrefix("chrome:")
                ? String(id.rawValue.dropFirst("chrome:".count))
                : id.rawValue
            return "id:\(raw)"
        }
    }

    private static func semanticKey(for node: BookmarkNode) -> String {
        switch node {
        case .folder(let folder):
            "folder:\(folder.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))"
        case .bookmark(let bookmark):
            "bookmark:\(bookmark.url.absoluteString)"
        }
    }

    private static func flatten(_ tree: BookmarkTree) -> [BookmarkNode] {
        tree.roots.flatMap { flatten(.folder($0)) }
    }

    private static func flatten(_ node: BookmarkNode) -> [BookmarkNode] {
        switch node {
        case .bookmark:
            [node]
        case .folder(let folder):
            [node] + folder.children.flatMap(flatten)
        }
    }

    private static func parentIDs(in tree: BookmarkTree) -> [BookmarkID: BookmarkID] {
        var result: [BookmarkID: BookmarkID] = [:]
        func visit(_ node: BookmarkNode, parent: BookmarkID?) {
            if let parent { result[node.id] = parent }
            if case .folder(let folder) = node {
                for child in folder.children { visit(child, parent: folder.id) }
            }
        }
        for root in tree.roots { visit(.folder(root), parent: nil) }
        return result
    }
}
