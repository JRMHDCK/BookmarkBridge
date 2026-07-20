//
//  SafariBookmarkIndex.swift
//  BookmarkBridge
//

import Foundation

/// Ephemeral index over one mutable plist tree. It is rebuilt after every
/// mutation and never crosses the mutator boundary.
nonisolated struct SafariBookmarkIndex {
    let rootUUID: String
    private let nodesByUUID: [String: NSMutableDictionary]
    private let parentUUIDByUUID: [String: String]
    private let positionByUUID: [String: Int]
    private let childUUIDsByUUID: [String: [String]]

    init(root: NSMutableDictionary) throws {
        var nodesByUUID: [String: NSMutableDictionary] = [:]
        var parentUUIDByUUID: [String: String] = [:]
        var positionByUUID: [String: Int] = [:]
        var childUUIDsByUUID: [String: [String]] = [:]

        let rootUUID = try Self.index(
            node: root,
            parentUUID: nil,
            position: 0,
            nodesByUUID: &nodesByUUID,
            parentUUIDByUUID: &parentUUIDByUUID,
            positionByUUID: &positionByUUID,
            childUUIDsByUUID: &childUUIDsByUUID
        )
        self.rootUUID = rootUUID
        self.nodesByUUID = nodesByUUID
        self.parentUUIDByUUID = parentUUIDByUUID
        self.positionByUUID = positionByUUID
        self.childUUIDsByUUID = childUUIDsByUUID
    }

    func node(for nativeIdentifier: NativeNodeIdentifier) throws -> NSMutableDictionary {
        guard let node = nodesByUUID[nativeIdentifier.rawValue] else {
            throw SafariBookmarkMutationError.nativeNodeNotFound(nativeIdentifier)
        }
        return node
    }

    func parentUUID(for nativeIdentifier: NativeNodeIdentifier) -> String? {
        parentUUIDByUUID[nativeIdentifier.rawValue]
    }

    func position(for nativeIdentifier: NativeNodeIdentifier) -> Int? {
        positionByUUID[nativeIdentifier.rawValue]
    }

    func childUUIDs(for nativeIdentifier: NativeNodeIdentifier) -> [String]? {
        childUUIDsByUUID[nativeIdentifier.rawValue]
    }

    func contains(uuid: String) -> Bool {
        nodesByUUID[uuid] != nil
    }

    func children(of node: NSMutableDictionary) throws -> NSMutableArray {
        guard node["WebBookmarkType"] as? String == "WebBookmarkTypeList",
              let children = node["Children"] as? NSMutableArray else {
            let identifier = NativeNodeIdentifier(
                node["WebBookmarkUUID"] as? String ?? ""
            )
            throw SafariBookmarkMutationError.parentIsNotFolder(identifier)
        }
        return children
    }

    private static func index(
        node: NSMutableDictionary,
        parentUUID: String?,
        position: Int,
        nodesByUUID: inout [String: NSMutableDictionary],
        parentUUIDByUUID: inout [String: String],
        positionByUUID: inout [String: Int],
        childUUIDsByUUID: inout [String: [String]]
    ) throws -> String {
        guard let uuid = node["WebBookmarkUUID"] as? String, !uuid.isEmpty else {
            throw SafariBookmarkMutationError.missingUUID
        }
        guard nodesByUUID.updateValue(node, forKey: uuid) == nil else {
            throw SafariBookmarkMutationError.duplicateUUID(uuid)
        }
        if let parentUUID {
            parentUUIDByUUID[uuid] = parentUUID
        }
        positionByUUID[uuid] = position

        switch node["WebBookmarkType"] as? String {
        case "WebBookmarkTypeList":
            guard let children = node["Children"] as? NSMutableArray else {
                throw SafariBookmarkMutationError.invalidDocument
            }
            var childUUIDs: [String] = []
            childUUIDs.reserveCapacity(children.count)
            for (childPosition, value) in children.enumerated() {
                guard let child = value as? NSMutableDictionary else {
                    throw SafariBookmarkMutationError.invalidDocument
                }
                let childUUID = try index(
                    node: child,
                    parentUUID: uuid,
                    position: childPosition,
                    nodesByUUID: &nodesByUUID,
                    parentUUIDByUUID: &parentUUIDByUUID,
                    positionByUUID: &positionByUUID,
                    childUUIDsByUUID: &childUUIDsByUUID
                )
                childUUIDs.append(childUUID)
            }
            childUUIDsByUUID[uuid] = childUUIDs
        case "WebBookmarkTypeLeaf":
            guard node["Children"] == nil else {
                throw SafariBookmarkMutationError.invalidDocument
            }
            childUUIDsByUUID[uuid] = []
        default:
            throw SafariBookmarkMutationError.invalidDocument
        }
        return uuid
    }
}
