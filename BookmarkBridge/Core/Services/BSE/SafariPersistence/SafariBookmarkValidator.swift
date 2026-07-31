//
//  SafariBookmarkValidator.swift
//  BookmarkBridge
//

import Foundation

nonisolated protocol SafariBookmarkValidating: Sendable {
    func validate(_ document: SafariBookmarkDocument) throws
}

/// Structural validation only. No value is repaired, normalized or discarded.
nonisolated struct SafariBookmarkValidator: SafariBookmarkValidating {
    func validate(_ document: SafariBookmarkDocument) throws {
        let propertyList: Any
        do {
            propertyList = try PropertyListSerialization.propertyList(
                from: document.data,
                options: [],
                format: nil
            )
        } catch {
            throw SafariPersistenceError.invalidPropertyList
        }

        guard let root = propertyList as? [String: Any] else {
            throw SafariPersistenceError.invalidStructure(.rootIsNotDictionary)
        }
        guard root["WebBookmarkType"] as? String == "WebBookmarkTypeList" else {
            throw SafariPersistenceError.invalidStructure(.unrecognizedRoot)
        }

        var seenUUIDs = Set<String>()
        try validateNode(root, path: [], seenUUIDs: &seenUUIDs)
    }

    private func validateNode(
        _ node: [String: Any],
        path: [Int],
        seenUUIDs: inout Set<String>
    ) throws {
        guard let uuid = node["WebBookmarkUUID"] as? String, !uuid.isEmpty else {
            throw SafariPersistenceError.invalidStructure(.missingUUID(path: path))
        }
        guard seenUUIDs.insert(uuid).inserted else {
            throw SafariPersistenceError.invalidStructure(.duplicateUUID(uuid))
        }

        if node["Title"] != nil, node["Title"] as? String == nil {
            throw SafariPersistenceError.invalidStructure(.invalidTitle(path: path))
        }

        switch node["WebBookmarkType"] as? String {
        case "WebBookmarkTypeList":
            guard node["Children"] == nil || node["Children"] is [Any] else {
                throw SafariPersistenceError.invalidStructure(.invalidChildren(path: path))
            }
            let children = node["Children"] as? [Any] ?? []
            for (index, child) in children.enumerated() {
                guard let childNode = child as? [String: Any] else {
                    throw SafariPersistenceError.invalidStructure(
                        .invalidNode(path: path + [index])
                    )
                }
                try validateNode(childNode, path: path + [index], seenUUIDs: &seenUUIDs)
            }
        case "WebBookmarkTypeLeaf":
            guard node["URLString"] is String else {
                throw SafariPersistenceError.invalidStructure(.invalidURL(path: path))
            }
            if let uriValue = node["URIDictionary"] {
                guard let uriDictionary = uriValue as? [String: Any],
                      uriDictionary["title"] == nil || uriDictionary["title"] is String else {
                    throw SafariPersistenceError.invalidStructure(
                        .invalidURIDictionary(path: path)
                    )
                }
            }
            guard node["Children"] == nil else {
                throw SafariPersistenceError.invalidStructure(.invalidChildren(path: path))
            }
        case "WebBookmarkTypeProxy":
            guard let identifier = node["WebBookmarkIdentifier"] as? String,
                  !identifier.isEmpty else {
                throw SafariPersistenceError.invalidStructure(
                    .invalidNode(path: path)
                )
            }
            guard node["Children"] == nil else {
                throw SafariPersistenceError.invalidStructure(
                    .invalidChildren(path: path)
                )
            }
        default:
            throw SafariPersistenceError.invalidStructure(.invalidNode(path: path))
        }
    }
}
