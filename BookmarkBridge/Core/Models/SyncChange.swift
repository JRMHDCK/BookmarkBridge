//
//  SyncChange.swift
//  BookmarkBridge
//

import Foundation

/// A single, reversible edit proposed to reconcile two bookmark trees.
///
/// A change only *describes* an intended edit — it performs nothing. Turning a
/// change into an actual write is the concern of `BookmarkWriting`, introduced
/// in phase 2 and never before the read-only pipeline is proven.
nonisolated enum SyncChange: Hashable, Sendable {
    /// Add `node` under the folder identified by `parent` (nil = a root).
    ///
    /// `sourcePath` records the node's **origin folder path** (root → parent) in
    /// the source tree, captured now so the folder structure can be recreated at
    /// write time without changing this model later. `parent` stays the concrete
    /// target destination (resolved when the tree is rebuilt).
    case add(node: BookmarkNode, parent: BookmarkID?, sourcePath: [BookmarkPathComponent])

    /// Remove the node identified by `id`.
    case remove(id: BookmarkID)

    /// Move the node identified by `id` under a new parent folder (nil = a root).
    case move(id: BookmarkID, newParent: BookmarkID?)

    /// Rename the node identified by `id`.
    case rename(id: BookmarkID, newTitle: String)

    /// Change the URL of the bookmark identified by `id`.
    case updateURL(id: BookmarkID, newURL: URL)

    /// A short, human-readable description for previews and logs.
    var summary: String {
        switch self {
        case .add(let node, _, _): "Ajouter « \(node.title) »"
        case .remove(let id): "Supprimer \(id)"
        case .move(let id, _): "Déplacer \(id)"
        case .rename(let id, let newTitle): "Renommer \(id) → « \(newTitle) »"
        case .updateURL(let id, _): "Mettre à jour l'URL de \(id)"
        }
    }
}
