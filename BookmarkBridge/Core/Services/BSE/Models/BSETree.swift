//
//  BSETree.swift
//  BookmarkBridge
//

import Foundation

/// A validated root projection from a BSE tree.
nonisolated struct BSERoot: Hashable, Codable, Sendable, Identifiable {
    let node: BSENode

    var id: LogicalNodeID { node.logicalID }

    init(node: BSENode) throws {
        if let parentID = node.parentID {
            throw BSEModelValidationError.rootHasParent(nodeID: node.logicalID, parentID: parentID)
        }
        guard node.kind == .folder else {
            throw BSEModelValidationError.bookmarkCannotBeRoot(node.logicalID)
        }
        self.node = node
    }

    fileprivate init(validatedNode node: BSENode) {
        self.node = node
    }

    private enum CodingKeys: String, CodingKey {
        case node
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(node: container.decode(BSENode.self, forKey: .node))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(node, forKey: .node)
    }
}

/// A complete, immutable and structurally validated BSE tree.
///
/// Nodes are exposed in canonical pre-order: roots and siblings are sorted by
/// logical position, then by `LogicalNodeID`. Construction order therefore has
/// no effect on equality, hashing, encoding, or traversal.
nonisolated struct BSETree: Hashable, Codable, Sendable {
    private let nodesByID: [LogicalNodeID: BSENode]
    let nodes: [BSENode]

    var roots: [BSERoot] {
        nodes
            .filter { $0.parentID == nil }
            .map { BSERoot(validatedNode: $0) }
    }

    var count: Int { nodes.count }
    var isEmpty: Bool { nodes.isEmpty }

    init(nodes: [BSENode]) throws {
        let index = try Self.makeIndex(nodes)
        try Self.validateParents(in: index)
        try Self.validateRoots(in: index)
        try Self.validateNoCycles(in: index)

        self.nodesByID = index
        self.nodes = Self.canonicalOrder(index)
    }

    func node(for logicalID: LogicalNodeID) -> BSENode? {
        nodesByID[logicalID]
    }

    func children(of parentID: LogicalNodeID) -> [BSENode] {
        nodes.filter { $0.parentID == parentID }
    }

    static func == (lhs: BSETree, rhs: BSETree) -> Bool {
        lhs.nodes == rhs.nodes
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(nodes)
    }

    private static func makeIndex(_ nodes: [BSENode]) throws -> [LogicalNodeID: BSENode] {
        var index: [LogicalNodeID: BSENode] = [:]
        for node in nodes {
            guard index.updateValue(node, forKey: node.logicalID) == nil else {
                throw BSEModelValidationError.duplicateLogicalNodeID(node.logicalID)
            }
        }
        return index
    }

    private static func validateParents(in index: [LogicalNodeID: BSENode]) throws {
        for node in index.values {
            if let parentID = node.parentID, index[parentID] == nil {
                throw BSEModelValidationError.parentNotFound(nodeID: node.logicalID, parentID: parentID)
            }
        }
    }

    private static func validateRoots(in index: [LogicalNodeID: BSENode]) throws {
        for node in index.values where node.parentID == nil && node.kind != .folder {
            throw BSEModelValidationError.bookmarkCannotBeRoot(node.logicalID)
        }
    }

    private enum VisitState {
        case visiting
        case visited
    }

    private static func validateNoCycles(in index: [LogicalNodeID: BSENode]) throws {
        var states: [LogicalNodeID: VisitState] = [:]

        func visit(_ logicalID: LogicalNodeID) throws {
            switch states[logicalID] {
            case .visiting:
                throw BSEModelValidationError.cycleDetected(logicalID)
            case .visited:
                return
            case nil:
                break
            }

            states[logicalID] = .visiting
            if let parentID = index[logicalID]?.parentID {
                try visit(parentID)
            }
            states[logicalID] = .visited
        }

        for logicalID in index.keys.sorted() {
            try visit(logicalID)
        }
    }

    private static func canonicalOrder(_ index: [LogicalNodeID: BSENode]) -> [BSENode] {
        let areOrdered: (BSENode, BSENode) -> Bool = { lhs, rhs in
            if lhs.position != rhs.position { return lhs.position < rhs.position }
            return lhs.logicalID < rhs.logicalID
        }

        var childrenByParent: [LogicalNodeID: [BSENode]] = [:]
        let roots = index.values.filter { $0.parentID == nil }.sorted(by: areOrdered)
        for node in index.values {
            if let parentID = node.parentID {
                childrenByParent[parentID, default: []].append(node)
            }
        }
        for parentID in childrenByParent.keys {
            childrenByParent[parentID]?.sort(by: areOrdered)
        }

        var ordered: [BSENode] = []
        func append(_ node: BSENode) {
            ordered.append(node)
            for child in childrenByParent[node.logicalID] ?? [] {
                append(child)
            }
        }
        for root in roots {
            append(root)
        }
        return ordered
    }

    private enum CodingKeys: String, CodingKey {
        case nodes
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(nodes: container.decode([BSENode].self, forKey: .nodes))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodes, forKey: .nodes)
    }
}
