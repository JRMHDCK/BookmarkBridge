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

        var nativeIdentifiers = Set<NativeNodeIdentifier>()
        for key in roots.keys.sorted() {
            guard Self.supportedRootKeys.contains(key),
                  let root = roots[key] as? [String: Any],
                  root["type"] as? String == "folder" else {
                throw ChromePersistenceError.invalidStructure(.invalidRoot(key: key))
            }
            try validateNode(
                root,
                path: [key],
                nativeIdentifiers: &nativeIdentifiers
            )
        }
    }

    private func validateNode(
        _ node: [String: Any],
        path: [String],
        nativeIdentifiers: inout Set<NativeNodeIdentifier>
    ) throws {
        let chromeID = node["id"] as? String
        let chromeGUID = node["guid"] as? String
        let resolved: ChromeNativeIdentifier
        do {
            resolved = try ChromeNativeIdentifierResolver().resolve(
                chromeID: chromeID,
                chromeGUID: chromeGUID
            )
        } catch {
            if node["guid"] != nil {
                throw ChromePersistenceError.invalidStructure(.invalidGUID(path: path))
            }
            throw ChromePersistenceError.invalidStructure(.missingIdentifier(path: path))
        }
        guard nativeIdentifiers.insert(resolved.nativeIdentifier).inserted else {
            switch resolved.kind {
            case .chromeGUID:
                throw ChromePersistenceError.invalidStructure(
                    .duplicateGUID(chromeGUID ?? resolved.nativeIdentifier.rawValue)
                )
            case .chromeIDFallback, .opaque:
                throw ChromePersistenceError.invalidStructure(
                    .duplicateIdentifier(chromeID ?? resolved.nativeIdentifier.rawValue)
                )
            }
        }
        if let continuityIdentifier = resolved.continuityIdentifier,
           !nativeIdentifiers.insert(continuityIdentifier).inserted {
            throw ChromePersistenceError.invalidStructure(
                .duplicateIdentifier(chromeID ?? continuityIdentifier.rawValue)
            )
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
                    nativeIdentifiers: &nativeIdentifiers
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
