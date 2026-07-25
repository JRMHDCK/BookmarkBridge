//
//  ChromeSnapshotTransformer.swift
//  BookmarkBridge
//

import CryptoKit
import Foundation

/// Pure, deterministic conversion from internal Chrome records to BSE values.
/// It performs no file, process, system, or network access.
///
/// The `LogicalNodeID` values created here are provisional snapshot-local keys.
/// Repetition for an identical read is not persistent BSE identity, is not
/// inter-browser identity, and is never evidence that Chrome and Safari nodes
/// are the same. A future persisted BSE identity layer must replace or reconcile
/// these keys.
nonisolated struct ChromeSnapshotTransformer: Sendable {
    func transform(
        _ extraction: ChromeExtraction,
        sourceID: BSESourceID
    ) throws -> ChromeTransformationResult {
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
            throw ChromeReadError.snapshotInconsistent
        }

        return ChromeTransformationResult(
            snapshot: BSESnapshot(
                source: sourceID,
                capturedAt: extraction.capturedAt,
                tree: tree
            ),
            nativeIdentityObservations: try orderedObservations(
                state.nativeIdentityObservations,
                tree: tree
            ),
            issues: state.issues,
            foldersRead: state.foldersRead,
            bookmarksRead: state.bookmarksRead
        )
    }

    private func append(
        _ record: ChromeRecord,
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
        _ folder: ChromeFolderRecord,
        parentID: LogicalNodeID?,
        to state: inout TransformationState
    ) throws {
        guard let identity = provisionalIdentity(
            chromeID: folder.chromeID,
            chromeGUID: folder.chromeGUID,
            path: folder.path,
            state: &state
        ) else { return }

        let title = title(folder.title, path: folder.path, issues: &state.issues)
        do {
            state.nodes.append(try BSENode(
                logicalID: identity.logicalNodeID,
                kind: .folder,
                permanentRootRole: folder.path.positions.isEmpty
                    ? folder.path.root.permanentRootRole
                    : nil,
                title: title,
                parentID: parentID,
                position: folder.position
            ))
        } catch {
            throw ChromeReadError.snapshotInconsistent
        }
        state.nativeIdentityObservations.append(NativeIdentityObservation(
            sourceID: state.sourceID,
            provisionalLogicalNodeID: identity.logicalNodeID,
            nativeIdentifier: identity.resolved.nativeIdentifier,
            nativeIdentityKind: identity.resolved.kind,
            continuityIdentifier: identity.resolved.continuityIdentifier,
            continuityIdentityKind: identity.resolved.continuityKind
        ))
        state.foldersRead += 1

        for child in folder.children {
            try append(child, parentID: identity.logicalNodeID, to: &state)
        }
    }

    private func append(
        _ bookmark: ChromeBookmarkRecord,
        parentID: LogicalNodeID?,
        to state: inout TransformationState
    ) throws {
        guard let parentID else {
            state.issues.append(.unsupportedNode(path: bookmark.path))
            return
        }
        guard let identity = provisionalIdentity(
            chromeID: bookmark.chromeID,
            chromeGUID: bookmark.chromeGUID,
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
                logicalID: identity.logicalNodeID,
                kind: .bookmark,
                title: title,
                parentID: parentID,
                position: bookmark.position,
                url: url
            ))
        } catch {
            throw ChromeReadError.snapshotInconsistent
        }
        state.nativeIdentityObservations.append(NativeIdentityObservation(
            sourceID: state.sourceID,
            provisionalLogicalNodeID: identity.logicalNodeID,
            nativeIdentifier: identity.resolved.nativeIdentifier,
            nativeIdentityKind: identity.resolved.kind,
            continuityIdentifier: identity.resolved.continuityIdentifier,
            continuityIdentityKind: identity.resolved.continuityKind
        ))
        state.bookmarksRead += 1
    }

    /// Derives a deterministic Chrome-read-only key for the current snapshot.
    /// This key is neither durable BSE identity nor an inter-browser match key.
    private func provisionalIdentity(
        chromeID: String?,
        chromeGUID: String?,
        path: ChromeRecordPath,
        state: inout TransformationState
    ) -> ProvisionalNativeIdentity? {
        let resolved: ChromeNativeIdentifier
        do {
            resolved = try ChromeNativeIdentifierResolver().resolve(
                chromeID: chromeID,
                chromeGUID: chromeGUID
            )
        } catch let error as ChromeNativeIdentifierError {
            state.issues.append(.invalidNativeIdentifier(path: path, reason: error))
            return nil
        } catch {
            state.issues.append(.missingNativeIdentifier(path: path))
            return nil
        }
        guard state.nativeIdentifiers.insert(
            resolved.nativeIdentifier.rawValue
        ).inserted else {
            state.issues.append(.duplicateNativeIdentifier(path: path))
            return nil
        }

        let material = state.sourceID.rawValue.uuidString
            + "\u{0}"
            + resolved.nativeIdentifier.rawValue
        var bytes = Array(SHA256.hash(data: Data(material.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let uuid = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
        return ProvisionalNativeIdentity(
            logicalNodeID: LogicalNodeID(uuid),
            resolved: resolved
        )
    }

    private func orderedObservations(
        _ observations: [NativeIdentityObservation],
        tree: BSETree
    ) throws -> [NativeIdentityObservation] {
        let byLogicalID = Dictionary(
            observations.map { ($0.provisionalLogicalNodeID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        guard byLogicalID.count == tree.nodes.count else {
            throw ChromeReadError.snapshotInconsistent
        }
        return try tree.nodes.map { node in
            guard let observation = byLogicalID[node.logicalID] else {
                throw ChromeReadError.snapshotInconsistent
            }
            return observation
        }
    }

    private func title(
        _ title: String?,
        path: ChromeRecordPath,
        issues: inout [ChromeReadIssue]
    ) -> String {
        guard let title, !title.isEmpty else {
            issues.append(.missingTitle(path: path))
            return ""
        }
        return title
    }
}

nonisolated struct ChromeTransformationResult: Hashable, Sendable {
    let snapshot: BSESnapshot
    let nativeIdentityObservations: [NativeIdentityObservation]
    let issues: [ChromeReadIssue]
    let foldersRead: Int
    let bookmarksRead: Int
}

nonisolated private struct TransformationState {
    let sourceID: BSESourceID
    var nodes: [BSENode] = []
    var nativeIdentityObservations: [NativeIdentityObservation] = []
    var issues: [ChromeReadIssue]
    var nativeIdentifiers: Set<String> = []
    var foldersRead = 0
    var bookmarksRead = 0
}

nonisolated private struct ProvisionalNativeIdentity {
    let logicalNodeID: LogicalNodeID
    let resolved: ChromeNativeIdentifier
}
