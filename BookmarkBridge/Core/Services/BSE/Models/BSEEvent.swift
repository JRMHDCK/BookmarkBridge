//
//  BSEEvent.swift
//  BookmarkBridge
//

import Foundation

/// The structural event kinds BSE will be able to describe.
nonisolated enum BSEEventKind: String, Hashable, Codable, Sendable {
    case createNode
    case deleteNode
    case renameNode
    case moveNode
}

/// An immutable explanation of one logical tree change.
///
/// Full before/after node values preserve the information needed to inspect a
/// decision and, later, construct a reversible plan. This type only describes
/// an event; it never mutates a tree or writes to an external source.
nonisolated struct BSEEvent: Hashable, Codable, Sendable {
    let kind: BSEEventKind
    let logicalID: LogicalNodeID
    let before: BSENode?
    let after: BSENode?

    init(
        kind: BSEEventKind,
        logicalID: LogicalNodeID,
        before: BSENode?,
        after: BSENode?
    ) throws {
        switch kind {
        case .createNode:
            guard before == nil, after != nil else {
                throw BSEModelValidationError.invalidEventState(kind)
            }
        case .deleteNode:
            guard before != nil, after == nil else {
                throw BSEModelValidationError.invalidEventState(kind)
            }
        case .renameNode, .moveNode:
            guard before != nil, after != nil else {
                throw BSEModelValidationError.invalidEventState(kind)
            }
        }

        for node in [before, after].compactMap({ $0 }) where node.logicalID != logicalID {
            throw BSEModelValidationError.eventNodeIdentifierMismatch(
                expected: logicalID,
                actual: node.logicalID
            )
        }

        if let before, let after {
            switch kind {
            case .renameNode:
                guard before.kind == after.kind,
                      before.title != after.title,
                      before.parentID == after.parentID,
                      before.position == after.position,
                      before.bookmarkPayload == after.bookmarkPayload else {
                    throw BSEModelValidationError.invalidEventState(kind)
                }
            case .moveNode:
                guard before.kind == after.kind,
                      before.title == after.title,
                      before.bookmarkPayload == after.bookmarkPayload,
                      before.parentID != after.parentID || before.position != after.position else {
                    throw BSEModelValidationError.invalidEventState(kind)
                }
            case .createNode, .deleteNode:
                break
            }
        }

        self.kind = kind
        self.logicalID = logicalID
        self.before = before
        self.after = after
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case logicalID
        case before
        case after
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            kind: container.decode(BSEEventKind.self, forKey: .kind),
            logicalID: container.decode(LogicalNodeID.self, forKey: .logicalID),
            before: container.decodeIfPresent(BSENode.self, forKey: .before),
            after: container.decodeIfPresent(BSENode.self, forKey: .after)
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(logicalID, forKey: .logicalID)
        try container.encodeIfPresent(before, forKey: .before)
        try container.encodeIfPresent(after, forKey: .after)
    }
}
