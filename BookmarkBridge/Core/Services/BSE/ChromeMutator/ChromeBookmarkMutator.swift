//
//  ChromeBookmarkMutator.swift
//  BookmarkBridge
//

import Foundation

/// Applies exactly one planned operation to an in-memory Chrome document.
/// It performs no I/O and never mutates the native identity repository.
nonisolated struct ChromeBookmarkMutator: Sendable {
    private let sourceID: BSESourceID
    private let nativeIdentityRepository: any NativeIdentityRepository
    private let nativeIdentifierProvider: any NativeIdentifierProviding

    init(
        sourceID: BSESourceID,
        nativeIdentityRepository: any NativeIdentityRepository,
        nativeIdentifierProvider: any NativeIdentifierProviding
    ) {
        self.sourceID = sourceID
        self.nativeIdentityRepository = nativeIdentityRepository
        self.nativeIdentifierProvider = nativeIdentifierProvider
    }

    func apply(
        _ operation: SynchronizationOperation,
        to document: ChromeBookmarkDocument
    ) throws -> ChromeBookmarkMutationResult {
        try validate(document)
        let root = try mutableRoot(from: document)
        let index = try ChromeBookmarkIndex(documentRoot: root)

        switch operation {
        case .create(let operation):
            return try create(operation, root: root, index: index, document: document)
        case .delete(let operation):
            return try delete(operation, root: root, index: index, document: document)
        case .rename(let operation):
            return try rename(operation, root: root, index: index, document: document)
        case .updateURL(let operation):
            return try updateURL(operation, root: root, index: index, document: document)
        case .move(let operation):
            return try move(operation, root: root, index: index, document: document)
        case .reorder(let operation):
            return try reorder(operation, root: root, index: index, document: document)
        case .archive(let operation):
            throw ChromeBookmarkMutationError.unsupportedOperation(operation.logicalNodeID)
        }
    }

    private func create(
        _ operation: CreateNodeOperation,
        root: NSMutableDictionary,
        index: ChromeBookmarkIndex,
        document: ChromeBookmarkDocument
    ) throws -> ChromeBookmarkMutationResult {
        guard nativeIdentityRepository.nativeIdentifier(
            for: operation.logicalNodeID,
            sourceID: sourceID
        ) == nil else {
            throw ChromeBookmarkMutationError.nativeIdentityAlreadyExists(operation.logicalNodeID)
        }
        let parent = try resolveParent(operation.parentID, index: index)
        let children = try index.children(of: parent)
        try validateInsertionPosition(operation.position, childCount: children.count)

        switch operation.kind {
        case .folder where operation.url != nil,
             .bookmark where operation.url == nil:
            throw ChromeBookmarkMutationError.invalidCreateOperation(operation.logicalNodeID)
        default:
            break
        }

        let numericNodeID = try index.nextNumericNodeID()
        let resolvedIdentifier: ChromeNativeIdentifier
        let chromeGUID: String?
        if index.containsGUIDIdentities {
            let generatedIdentifier: NativeNodeIdentifier
            do {
                generatedIdentifier = try nativeIdentifierProvider.makeIdentifier()
            } catch {
                throw ChromeBookmarkMutationError.nativeIdentifierGenerationFailed
            }
            chromeGUID = generatedIdentifier.rawValue
        } else {
            // A GUID-less Chrome document remains GUID-less. The existing
            // numeric-id sequence already provides its native identity.
            chromeGUID = nil
        }
        do {
            resolvedIdentifier = try ChromeNativeIdentifierResolver().resolve(
                chromeID: numericNodeID,
                chromeGUID: chromeGUID
            )
        } catch {
            throw ChromeBookmarkMutationError.nativeIdentifierGenerationFailed
        }
        guard !index.contains(resolvedIdentifier.nativeIdentifier) else {
            throw ChromeBookmarkMutationError.duplicateNativeIdentifier(
                resolvedIdentifier.nativeIdentifier.rawValue
            )
        }
        children.insert(
            makeNode(
                operation,
                numericNodeID: numericNodeID,
                chromeGUID: chromeGUID
            ),
            at: operation.position
        )
        return ChromeBookmarkMutationResult(
            document: try finalizedDocument(root: root, preserving: document),
            nativeIdentityChanges: [
                .register(
                    logicalNodeID: operation.logicalNodeID,
                    sourceID: sourceID,
                    nativeIdentifier: resolvedIdentifier.nativeIdentifier
                ),
            ]
        )
    }

    private func delete(
        _ operation: DeleteNodeOperation,
        root: NSMutableDictionary,
        index: ChromeBookmarkIndex,
        document: ChromeBookmarkDocument
    ) throws -> ChromeBookmarkMutationResult {
        let identifier = try resolve(operation.logicalNodeID)
        let node = try index.node(for: identifier)
        guard !index.isPermanentRoot(identifier) else {
            throw ChromeBookmarkMutationError.cannotMutatePermanentRoot(operation.logicalNodeID)
        }
        if node["type"] as? String == "folder",
           let children = index.childIdentifiers(for: identifier),
           !children.isEmpty {
            throw ChromeBookmarkMutationError.nonEmptyFolder(operation.logicalNodeID)
        }

        let parent = try parentNode(of: identifier, index: index)
        let siblings = try index.children(of: parent)
        guard let position = index.position(for: identifier), position < siblings.count else {
            throw ChromeBookmarkMutationError.invalidDocument
        }
        siblings.removeObject(at: position)

        return ChromeBookmarkMutationResult(
            document: try finalizedDocument(root: root, preserving: document),
            nativeIdentityChanges: [
                .remove(logicalNodeID: operation.logicalNodeID, sourceID: sourceID),
            ]
        )
    }

    private func rename(
        _ operation: RenameNodeOperation,
        root: NSMutableDictionary,
        index: ChromeBookmarkIndex,
        document: ChromeBookmarkDocument
    ) throws -> ChromeBookmarkMutationResult {
        let node = try index.node(for: resolve(operation.logicalNodeID))
        guard node["type"] as? String == "folder" || node["type"] as? String == "url" else {
            throw ChromeBookmarkMutationError.invalidDocument
        }
        node["name"] = operation.title
        return try resultWithoutIdentityChanges(root: root, preserving: document)
    }

    private func updateURL(
        _ operation: UpdateURLOperation,
        root: NSMutableDictionary,
        index: ChromeBookmarkIndex,
        document: ChromeBookmarkDocument
    ) throws -> ChromeBookmarkMutationResult {
        let node = try index.node(for: resolve(operation.logicalNodeID))
        guard node["type"] as? String == "url" else {
            throw ChromeBookmarkMutationError.URLUpdateRequiresBookmark(operation.logicalNodeID)
        }
        node["url"] = operation.url.absoluteString
        return try resultWithoutIdentityChanges(root: root, preserving: document)
    }

    private func move(
        _ operation: MoveNodeOperation,
        root: NSMutableDictionary,
        index: ChromeBookmarkIndex,
        document: ChromeBookmarkDocument
    ) throws -> ChromeBookmarkMutationResult {
        let identifier = try resolve(operation.logicalNodeID)
        let node = try index.node(for: identifier)
        guard !index.isPermanentRoot(identifier) else {
            throw ChromeBookmarkMutationError.cannotMutatePermanentRoot(operation.logicalNodeID)
        }
        let newParent = try resolveParent(operation.parentID, index: index)
        let newParentIdentifier = try index.identifier(for: newParent)
        try validateNoCycle(
            moving: identifier,
            below: newParentIdentifier,
            logicalNodeID: operation.logicalNodeID,
            index: index
        )

        let oldParent = try parentNode(of: identifier, index: index)
        let oldChildren = try index.children(of: oldParent)
        let newChildren = try index.children(of: newParent)
        guard let oldPosition = index.position(for: identifier),
              oldPosition < oldChildren.count else {
            throw ChromeBookmarkMutationError.invalidDocument
        }
        let finalChildCount = newChildren === oldChildren
            ? oldChildren.count - 1
            : newChildren.count
        try validateInsertionPosition(operation.position, childCount: finalChildCount)

        oldChildren.removeObject(at: oldPosition)
        newChildren.insert(node, at: operation.position)
        return try resultWithoutIdentityChanges(root: root, preserving: document)
    }

    private func reorder(
        _ operation: ReorderNodeOperation,
        root: NSMutableDictionary,
        index: ChromeBookmarkIndex,
        document: ChromeBookmarkDocument
    ) throws -> ChromeBookmarkMutationResult {
        let identifier = try resolve(operation.logicalNodeID)
        let node = try index.node(for: identifier)
        guard !index.isPermanentRoot(identifier) else {
            throw ChromeBookmarkMutationError.cannotMutatePermanentRoot(operation.logicalNodeID)
        }
        let parent = try parentNode(of: identifier, index: index)
        let siblings = try index.children(of: parent)
        guard let oldPosition = index.position(for: identifier), oldPosition < siblings.count else {
            throw ChromeBookmarkMutationError.invalidDocument
        }
        try validateInsertionPosition(operation.position, childCount: siblings.count - 1)

        siblings.removeObject(at: oldPosition)
        siblings.insert(node, at: operation.position)
        return try resultWithoutIdentityChanges(root: root, preserving: document)
    }

    private func makeNode(
        _ operation: CreateNodeOperation,
        numericNodeID: String,
        chromeGUID: String?
    ) -> NSMutableDictionary {
        var values: [String: Any]
        switch operation.kind {
        case .folder:
            values = [
                "type": "folder",
                "id": numericNodeID,
                "name": operation.title,
                "children": NSMutableArray(),
            ]
        case .bookmark:
            values = [
                "type": "url",
                "id": numericNodeID,
                "name": operation.title,
                "url": operation.url?.absoluteString ?? "",
            ]
        }
        if let chromeGUID {
            values["guid"] = chromeGUID
        }
        return NSMutableDictionary(dictionary: values)
    }

    private func resolve(_ logicalNodeID: LogicalNodeID) throws -> NativeNodeIdentifier {
        guard let identifier = nativeIdentityRepository.nativeIdentifier(
            for: logicalNodeID,
            sourceID: sourceID
        ) else {
            throw ChromeBookmarkMutationError.nativeIdentityMissing(logicalNodeID)
        }
        return identifier
    }

    private func resolveParent(
        _ logicalNodeID: LogicalNodeID?,
        index: ChromeBookmarkIndex
    ) throws -> NSMutableDictionary {
        guard let logicalNodeID else {
            throw ChromeBookmarkMutationError.rootDestinationUnsupported
        }
        guard let identifier = nativeIdentityRepository.nativeIdentifier(
            for: logicalNodeID,
            sourceID: sourceID
        ) else {
            throw ChromeBookmarkMutationError.parentNotFound(logicalNodeID)
        }
        do {
            return try index.node(for: identifier)
        } catch ChromeBookmarkMutationError.nativeNodeNotFound(_) {
            throw ChromeBookmarkMutationError.parentNotFound(logicalNodeID)
        }
    }

    private func parentNode(
        of identifier: NativeNodeIdentifier,
        index: ChromeBookmarkIndex
    ) throws -> NSMutableDictionary {
        guard let parentIdentifier = index.parentIdentifier(for: identifier) else {
            throw ChromeBookmarkMutationError.invalidDocument
        }
        return try index.node(for: parentIdentifier)
    }

    private func validateNoCycle(
        moving identifier: NativeNodeIdentifier,
        below newParentIdentifier: NativeNodeIdentifier,
        logicalNodeID: LogicalNodeID,
        index: ChromeBookmarkIndex
    ) throws {
        var currentIdentifier: NativeNodeIdentifier? = newParentIdentifier
        while let current = currentIdentifier {
            guard current != identifier else {
                throw ChromeBookmarkMutationError.cycleDetected(logicalNodeID)
            }
            currentIdentifier = index.parentIdentifier(for: current)
        }
    }

    private func validateInsertionPosition(_ position: Int, childCount: Int) throws {
        guard position >= 0, position <= childCount else {
            throw ChromeBookmarkMutationError.invalidPosition(position)
        }
    }

    private func mutableRoot(from document: ChromeBookmarkDocument) throws -> NSMutableDictionary {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(
                with: document.data,
                options: [.mutableContainers, .mutableLeaves]
            )
        } catch {
            throw ChromeBookmarkMutationError.invalidDocument
        }
        guard let root = object as? NSMutableDictionary else {
            throw ChromeBookmarkMutationError.invalidDocument
        }
        return root
    }

    private func finalizedDocument(
        root: NSMutableDictionary,
        preserving document: ChromeBookmarkDocument
    ) throws -> ChromeBookmarkDocument {
        _ = try ChromeBookmarkIndex(documentRoot: root)
        if root["checksum"] != nil {
            guard root["checksum"] is String,
                  let roots = root["roots"] as? [String: Any] else {
                throw ChromeBookmarkMutationError.invalidDocument
            }
            root["checksum"] = ChromeChecksum.compute(roots: roots)
        }

        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        } catch {
            throw ChromeBookmarkMutationError.serializationFailed
        }
        do {
            let result = try ChromeBookmarkDocument(
                data: data,
                sourceFingerprint: document.sourceFingerprint
            )
            try validate(result)
            return result
        } catch let error as ChromeBookmarkMutationError {
            throw error
        } catch {
            throw ChromeBookmarkMutationError.serializationFailed
        }
    }

    private func validate(_ document: ChromeBookmarkDocument) throws {
        do {
            try ChromeBookmarkValidator().validate(document)
        } catch {
            throw ChromeBookmarkMutationError.invalidDocument
        }
    }

    private func resultWithoutIdentityChanges(
        root: NSMutableDictionary,
        preserving document: ChromeBookmarkDocument
    ) throws -> ChromeBookmarkMutationResult {
        ChromeBookmarkMutationResult(
            document: try finalizedDocument(root: root, preserving: document),
            nativeIdentityChanges: []
        )
    }
}
