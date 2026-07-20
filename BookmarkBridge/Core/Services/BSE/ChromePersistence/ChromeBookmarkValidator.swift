//
//  ChromeBookmarkValidator.swift
//  BookmarkBridge
//

import Foundation

nonisolated protocol ChromeBookmarkValidating: Sendable {
    func validate(_ document: ChromeBookmarkDocument) throws
}

/// Structural validation only. No Chrome value is repaired, normalized or discarded.
nonisolated struct ChromeBookmarkValidator: ChromeBookmarkValidating {
    private static let supportedRootKeys = Set(["bookmark_bar", "other", "synced"])

    func validate(_ document: ChromeBookmarkDocument) throws {
        let rawObject: Any
        do {
            rawObject = try JSONSerialization.jsonObject(with: document.data)
        } catch {
            throw ChromePersistenceError.invalidJSON
        }
        guard let object = rawObject as? [String: Any] else {
            throw ChromePersistenceError.invalidJSON
        }
        guard let rootsValue = object["roots"] else {
            throw ChromePersistenceError.invalidStructure(.rootsMissing)
        }
        guard let roots = rootsValue as? [String: Any] else {
            throw ChromePersistenceError.invalidStructure(.invalidRoots)
        }
        if let version = object["version"], !(version is String), !(version is NSNumber) {
            throw ChromePersistenceError.invalidStructure(.invalidVersion)
        }
        if let checksum = object["checksum"], !(checksum is String) {
            throw ChromePersistenceError.invalidStructure(.invalidChecksum)
        }

        var identifiers = Set<String>()
        var GUIDs = Set<String>()
        for key in roots.keys.sorted() {
            guard Self.supportedRootKeys.contains(key),
                  let root = roots[key] as? [String: Any],
                  root["type"] as? String == "folder" else {
                throw ChromePersistenceError.invalidStructure(.invalidRoot(key: key))
            }
            try validateNode(
                root,
                path: [key],
                identifiers: &identifiers,
                GUIDs: &GUIDs
            )
        }
    }

    private func validateNode(
        _ node: [String: Any],
        path: [String],
        identifiers: inout Set<String>,
        GUIDs: inout Set<String>
    ) throws {
        guard let identifier = node["id"] as? String, !identifier.isEmpty else {
            throw ChromePersistenceError.invalidStructure(.missingIdentifier(path: path))
        }
        guard identifiers.insert(identifier).inserted else {
            throw ChromePersistenceError.invalidStructure(.duplicateIdentifier(identifier))
        }
        if let GUIDValue = node["guid"] {
            guard let GUID = GUIDValue as? String, !GUID.isEmpty else {
                throw ChromePersistenceError.invalidStructure(.invalidGUID(path: path))
            }
            guard GUIDs.insert(GUID).inserted else {
                throw ChromePersistenceError.invalidStructure(.duplicateGUID(GUID))
            }
        }
        guard node["name"] is String else {
            throw ChromePersistenceError.invalidStructure(.invalidName(path: path))
        }

        switch node["type"] as? String {
        case "folder":
            guard let children = node["children"] as? [Any] else {
                throw ChromePersistenceError.invalidStructure(.invalidChildren(path: path))
            }
            guard node["url"] == nil else {
                throw ChromePersistenceError.invalidStructure(.invalidURL(path: path))
            }
            for (position, value) in children.enumerated() {
                guard let child = value as? [String: Any] else {
                    throw ChromePersistenceError.invalidStructure(
                        .invalidNode(path: path + [String(position)])
                    )
                }
                try validateNode(
                    child,
                    path: path + [String(position)],
                    identifiers: &identifiers,
                    GUIDs: &GUIDs
                )
            }
        case "url":
            guard node["url"] is String else {
                throw ChromePersistenceError.invalidStructure(.invalidURL(path: path))
            }
            guard node["children"] == nil else {
                throw ChromePersistenceError.invalidStructure(.invalidChildren(path: path))
            }
        default:
            throw ChromePersistenceError.invalidStructure(.unknownNodeType(path: path))
        }
    }
}
