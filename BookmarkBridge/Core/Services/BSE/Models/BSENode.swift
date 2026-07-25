//
//  BSENode.swift
//  BookmarkBridge
//

import Foundation

/// The two universal node kinds understood by the BSE model.
nonisolated enum NodeKind: String, Hashable, Codable, Sendable {
    case folder
    case bookmark
}

/// Data carried only by a bookmark node.
nonisolated struct BSEBookmarkPayload: Hashable, Codable, Sendable {
    let url: URL

    init(url: URL) {
        self.url = url
    }
}

/// One immutable node in a BSE tree.
///
/// `position` is the node's zero-based logical position among its siblings.
/// Equal positions remain deterministic because `BSETree` uses `logicalID` as
/// a stable tie-breaker. The validated initializer prevents folders from
/// carrying URLs and bookmarks from existing without one.
nonisolated struct BSENode: Hashable, Codable, Sendable, Identifiable {
    let logicalID: LogicalNodeID
    let kind: NodeKind
    let permanentRootRole: PermanentRootRole?
    let title: String
    let parentID: LogicalNodeID?
    let position: Int
    let bookmarkPayload: BSEBookmarkPayload?

    var id: LogicalNodeID { logicalID }
    var url: URL? { bookmarkPayload?.url }

    init(
        logicalID: LogicalNodeID,
        kind: NodeKind,
        permanentRootRole: PermanentRootRole? = nil,
        title: String,
        parentID: LogicalNodeID? = nil,
        position: Int,
        url: URL? = nil
    ) throws {
        guard position >= 0 else {
            throw BSEModelValidationError.negativePosition(nodeID: logicalID, position: position)
        }

        let payload: BSEBookmarkPayload?
        switch kind {
        case .folder:
            guard url == nil else {
                throw BSEModelValidationError.folderMustNotHaveURL(logicalID)
            }
            payload = nil
        case .bookmark:
            guard let url else {
                throw BSEModelValidationError.bookmarkRequiresURL(logicalID)
            }
            payload = BSEBookmarkPayload(url: url)
        }
        guard permanentRootRole == nil
                || kind == .folder && parentID == nil else {
            throw BSEModelValidationError.invalidPermanentRoot(logicalID)
        }

        self.logicalID = logicalID
        self.kind = kind
        self.permanentRootRole = permanentRootRole
        self.title = title
        self.parentID = parentID
        self.position = position
        self.bookmarkPayload = payload
    }

    private enum CodingKeys: String, CodingKey {
        case logicalID
        case kind
        case permanentRootRole
        case title
        case parentID
        case position
        case url
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            logicalID: container.decode(LogicalNodeID.self, forKey: .logicalID),
            kind: container.decode(NodeKind.self, forKey: .kind),
            permanentRootRole: container.decodeIfPresent(
                PermanentRootRole.self,
                forKey: .permanentRootRole
            ),
            title: container.decode(String.self, forKey: .title),
            parentID: container.decodeIfPresent(LogicalNodeID.self, forKey: .parentID),
            position: container.decode(Int.self, forKey: .position),
            url: container.decodeIfPresent(URL.self, forKey: .url)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(logicalID, forKey: .logicalID)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(
            permanentRootRole,
            forKey: .permanentRootRole
        )
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(parentID, forKey: .parentID)
        try container.encode(position, forKey: .position)
        try container.encodeIfPresent(url, forKey: .url)
    }
}
