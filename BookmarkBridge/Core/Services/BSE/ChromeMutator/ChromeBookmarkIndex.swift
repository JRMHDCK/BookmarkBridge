//
//  ChromeBookmarkIndex.swift
//  BookmarkBridge
//

import Foundation

/// Ephemeral index over one mutable Chrome JSON tree. It is rebuilt for every
/// mutation and never crosses the mutator boundary.
nonisolated struct ChromeBookmarkIndex {
    private let nodesByIdentifier: [NativeNodeIdentifier: NSMutableDictionary]
    private let parentIdentifierByIdentifier: [
        NativeNodeIdentifier: NativeNodeIdentifier
    ]
    private let positionByIdentifier: [NativeNodeIdentifier: Int]
    private let childIdentifiersByIdentifier: [
        NativeNodeIdentifier: [NativeNodeIdentifier]
    ]
    private let permanentRootIdentifiers: Set<NativeNodeIdentifier>
    private let maximumNumericNodeID: Int64?
    let containsGUIDIdentities: Bool

    init(documentRoot: NSMutableDictionary) throws {
        guard let roots = documentRoot["roots"] as? NSMutableDictionary else {
            throw ChromeBookmarkMutationError.invalidDocument
        }

        var nodes: [NativeNodeIdentifier: NSMutableDictionary] = [:]
        var parents: [NativeNodeIdentifier: NativeNodeIdentifier] = [:]
        var positions: [NativeNodeIdentifier: Int] = [:]
        var children: [NativeNodeIdentifier: [NativeNodeIdentifier]] = [:]
        var permanentRoots = Set<NativeNodeIdentifier>()

        for key in roots.allKeys.compactMap({ $0 as? String }).sorted() {
            guard let node = roots[key] as? NSMutableDictionary else {
                throw ChromeBookmarkMutationError.invalidDocument
            }
            let identifier = try Self.index(
                node: node,
                parentIdentifier: nil,
                position: 0,
                nodes: &nodes,
                parents: &parents,
                positions: &positions,
                children: &children
            )
            permanentRoots.insert(identifier)
        }

        self.nodesByIdentifier = nodes
        self.parentIdentifierByIdentifier = parents
        self.positionByIdentifier = positions
        self.childIdentifiersByIdentifier = children
        self.permanentRootIdentifiers = permanentRoots
        self.maximumNumericNodeID = nodes.values.compactMap {
            ($0["id"] as? String).flatMap(Int64.init)
        }.max()
        self.containsGUIDIdentities = try nodes.values.contains {
            try Self.resolvedIdentifier(in: $0).kind == .chromeGUID
        }
    }

    func node(for identifier: NativeNodeIdentifier) throws -> NSMutableDictionary {
        guard let node = nodesByIdentifier[identifier] else {
            throw ChromeBookmarkMutationError.nativeNodeNotFound(identifier)
        }
        return node
    }

    func parentIdentifier(
        for identifier: NativeNodeIdentifier
    ) -> NativeNodeIdentifier? {
        parentIdentifierByIdentifier[identifier]
    }

    func position(for identifier: NativeNodeIdentifier) -> Int? {
        positionByIdentifier[identifier]
    }

    func childIdentifiers(
        for identifier: NativeNodeIdentifier
    ) -> [NativeNodeIdentifier]? {
        childIdentifiersByIdentifier[identifier]
    }

    func contains(_ identifier: NativeNodeIdentifier) -> Bool {
        nodesByIdentifier[identifier] != nil
    }

    func isPermanentRoot(_ identifier: NativeNodeIdentifier) -> Bool {
        permanentRootIdentifiers.contains(identifier)
    }

    func identifier(
        for node: NSMutableDictionary
    ) throws -> NativeNodeIdentifier {
        try Self.resolvedIdentifier(in: node).nativeIdentifier
    }

    func nextNumericNodeID() throws -> String {
        let maximum = maximumNumericNodeID ?? 0
        guard maximum < Int64.max else {
            throw ChromeBookmarkMutationError.nativeIdentifierGenerationFailed
        }
        return String(maximum + 1)
    }

    func children(of node: NSMutableDictionary) throws -> NSMutableArray {
        guard node["type"] as? String == "folder",
              let children = node["children"] as? NSMutableArray else {
            throw ChromeBookmarkMutationError.parentIsNotFolder(
                (try? identifier(for: node)) ?? NativeNodeIdentifier("")
            )
        }
        return children
    }

    private static func index(
        node: NSMutableDictionary,
        parentIdentifier: NativeNodeIdentifier?,
        position: Int,
        nodes: inout [NativeNodeIdentifier: NSMutableDictionary],
        parents: inout [NativeNodeIdentifier: NativeNodeIdentifier],
        positions: inout [NativeNodeIdentifier: Int],
        children: inout [NativeNodeIdentifier: [NativeNodeIdentifier]]
    ) throws -> NativeNodeIdentifier {
        let identifier = try resolvedIdentifier(in: node).nativeIdentifier
        guard nodes.updateValue(node, forKey: identifier) == nil else {
            throw ChromeBookmarkMutationError.duplicateNativeIdentifier(
                identifier.rawValue
            )
        }
        if let parentIdentifier {
            parents[identifier] = parentIdentifier
        }
        positions[identifier] = position

        switch node["type"] as? String {
        case "folder":
            guard let values = node["children"] as? NSMutableArray,
                  node["url"] == nil else {
                throw ChromeBookmarkMutationError.invalidDocument
            }
            var childIdentifiers: [NativeNodeIdentifier] = []
            childIdentifiers.reserveCapacity(values.count)
            for (childPosition, value) in values.enumerated() {
                guard let child = value as? NSMutableDictionary else {
                    throw ChromeBookmarkMutationError.invalidDocument
                }
                childIdentifiers.append(try index(
                    node: child,
                    parentIdentifier: identifier,
                    position: childPosition,
                    nodes: &nodes,
                    parents: &parents,
                    positions: &positions,
                    children: &children
                ))
            }
            children[identifier] = childIdentifiers
        case "url":
            guard node["url"] is String, node["children"] == nil else {
                throw ChromeBookmarkMutationError.invalidDocument
            }
            children[identifier] = []
        default:
            throw ChromeBookmarkMutationError.invalidDocument
        }
        return identifier
    }

    private static func resolvedIdentifier(
        in node: NSMutableDictionary
    ) throws -> ChromeNativeIdentifier {
        do {
            return try ChromeNativeIdentifierResolver().resolve(
                chromeID: node["id"] as? String,
                chromeGUID: node["guid"] as? String
            )
        } catch {
            throw ChromeBookmarkMutationError.missingNativeIdentifier
        }
    }
}
