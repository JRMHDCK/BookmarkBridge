//
//  SafariSnapshotTransformer.swift
//  BookmarkBridge
//

import CryptoKit
import Foundation

/// Pure, deterministic conversion from internal Safari records to BSE values.
/// It performs no file, process, system, or network access.
///
/// The `LogicalNodeID` values created here are provisional keys used only to
/// assemble the current Safari snapshot. Their deterministic repetition for an
/// identical read is not persistent BSE identity, is not cross-browser
/// identity, and must never be used as evidence that a Safari node and a Chrome
/// node are the same. A future persisted BSE identity layer is expected to
/// replace or reconcile these snapshot-local keys.
nonisolated struct SafariSnapshotTransformer: Sendable {
    func transform(
        _ extraction: SafariExtraction,
        sourceID: BSESourceID
    ) throws -> SafariTransformationResult {
        var state = TransformationState(
            sourceID: sourceID,
            issues: extraction.issues
        )

        for record in extraction.records {
            try append(record, parentID: nil, to: &state)
        }

        let tree: BSETree
        do {
            tree = try BSETree(nodes: state.nodes)
        } catch {
            throw SafariReadError.snapshotInconsistent
        }

        return SafariTransformationResult(
            snapshot: BSESnapshot(
                source: sourceID,
                capturedAt: extraction.capturedAt,
                tree: tree
            ),
            issues: state.issues,
            foldersRead: state.foldersRead,
            bookmarksRead: state.bookmarksRead
        )
    }

    private func append(
        _ record: SafariRecord,
        parentID: LogicalNodeID?,
        to state: inout TransformationState
    ) throws {
        switch record {
        case .bookmark(let bookmark):
            try append(bookmark, parentID: parentID, to: &state)
        case .folder(let folder):
            try append(folder, parentID: parentID, to: &state)
        }
    }

    private func append(
        _ folder: SafariFolderRecord,
        parentID: LogicalNodeID?,
        to state: inout TransformationState
    ) throws {
        guard let provisionalLogicalID = provisionalLogicalID(
            for: folder.nativeIdentifier,
            path: folder.path,
            state: &state
        ) else { return }

        let title = title(folder.title, path: folder.path, issues: &state.issues)
        do {
            state.nodes.append(try BSENode(
                logicalID: provisionalLogicalID,
                kind: .folder,
                title: title,
                parentID: parentID,
                position: folder.position
            ))
        } catch {
            throw SafariReadError.snapshotInconsistent
        }
        state.foldersRead += 1

        for child in folder.children {
            try append(child, parentID: provisionalLogicalID, to: &state)
        }
    }

    private func append(
        _ bookmark: SafariBookmarkRecord,
        parentID: LogicalNodeID?,
        to state: inout TransformationState
    ) throws {
        guard let parentID else {
            state.issues.append(.unsupportedNode(path: bookmark.path))
            return
        }
        guard let provisionalLogicalID = provisionalLogicalID(
            for: bookmark.nativeIdentifier,
            path: bookmark.path,
            state: &state
        ) else { return }

        let title = title(bookmark.title, path: bookmark.path, issues: &state.issues)
        guard let rawURL = bookmark.urlString, !rawURL.isEmpty else {
            state.issues.append(.missingURL(path: bookmark.path))
            return
        }
        guard let url = URL(string: rawURL), url.scheme != nil else {
            state.issues.append(.invalidURL(path: bookmark.path))
            return
        }

        do {
            state.nodes.append(try BSENode(
                logicalID: provisionalLogicalID,
                kind: .bookmark,
                title: title,
                parentID: parentID,
                position: bookmark.position,
                url: url
            ))
        } catch {
            throw SafariReadError.snapshotInconsistent
        }
        state.bookmarksRead += 1
    }

    /// Derives a deterministic, Safari-read-only key for the current snapshot.
    /// This key is neither durable BSE identity nor an inter-browser match key.
    private func provisionalLogicalID(
        for nativeIdentifier: String?,
        path: SafariRecordPath,
        state: inout TransformationState
    ) -> LogicalNodeID? {
        guard let nativeIdentifier, !nativeIdentifier.isEmpty else {
            state.issues.append(.missingNativeIdentifier(path: path))
            return nil
        }
        guard state.nativeIdentifiers.insert(nativeIdentifier).inserted else {
            state.issues.append(.duplicateNativeIdentifier(path: path))
            return nil
        }

        let material = "\(state.sourceID.rawValue.uuidString)\u{0}\(nativeIdentifier)"
        var bytes = Array(SHA256.hash(data: Data(material.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let uuid = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
        return LogicalNodeID(uuid)
    }

    private func title(
        _ title: String?,
        path: SafariRecordPath,
        issues: inout [SafariReadIssue]
    ) -> String {
        guard let title, !title.isEmpty else {
            issues.append(.missingTitle(path: path))
            return ""
        }
        return title
    }
}

nonisolated struct SafariTransformationResult: Hashable, Sendable {
    let snapshot: BSESnapshot
    let issues: [SafariReadIssue]
    let foldersRead: Int
    let bookmarksRead: Int
}

nonisolated private struct TransformationState {
    let sourceID: BSESourceID
    var nodes: [BSENode] = []
    var issues: [SafariReadIssue]
    var nativeIdentifiers: Set<String> = []
    var foldersRead = 0
    var bookmarksRead = 0
}
