//
//  SafariAccessValidationReport.swift
//  BookmarkBridge
//
//  A small technical report produced by the manual end-to-end validation of the
//  real Safari access chain. It only counts and echoes what was read — it never
//  writes, syncs, diffs, or backs up anything.
//

import Foundation

nonisolated struct SafariAccessValidationReport: Equatable, Sendable {
    let folderCount: Int
    let bookmarkCount: Int
    let totalNodeCount: Int
    let capturedAt: Date
    /// True when the file's identity (size + modification date) was unchanged
    /// across the read — an empirical confirmation of read-only access.
    let isReadOnly: Bool

    /// Builds a report by walking an already-decoded tree.
    static func make(from tree: BookmarkTree, isReadOnly: Bool) -> SafariAccessValidationReport {
        var folders = 0
        var bookmarks = 0

        func walk(_ nodes: [BookmarkNode]) {
            for node in nodes {
                switch node {
                case .bookmark:
                    bookmarks += 1
                case .folder(let folder):
                    folders += 1
                    walk(folder.children)
                }
            }
        }

        for root in tree.roots {
            folders += 1          // each root is itself a folder
            walk(root.children)
        }

        return SafariAccessValidationReport(
            folderCount: folders,
            bookmarkCount: bookmarks,
            totalNodeCount: folders + bookmarks,
            capturedAt: tree.capturedAt,
            isReadOnly: isReadOnly
        )
    }

    /// Human-readable lines for display in the validation harness.
    var summaryLines: [String] {
        [
            "Dossiers : \(folderCount)",
            "Favoris : \(bookmarkCount)",
            "Nœuds totaux : \(totalNodeCount)",
            "capturedAt : \(capturedAt.formatted(date: .abbreviated, time: .standard))",
            "Lecture strictement en lecture seule : \(isReadOnly ? "confirmée ✓" : "NON — fichier modifié ✗")",
        ]
    }
}
