//
//  SafariBookmarkMutator.swift
//  BookmarkBridge
//

import Foundation

/// Pure in-memory application of exactly one already-planned operation.
/// Disk access, backup and system-state checks remain persistence concerns.
nonisolated struct SafariBookmarkMutator: Sendable {
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
        to document: SafariBookmarkDocument
    ) throws -> SafariBookmarkMutationResult {
        let root = try mutableRoot(from: document)
        let index = try SafariBookmarkIndex(root: root)

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
            throw SafariBookmarkMutationError.unsupportedOperation(operation.logicalNodeID)
        }
    }

    private func create(
        _ operation: CreateNodeOperation,
        root: NSMutableDictionary,
        index: SafariBookmarkIndex,
        document: SafariBookmarkDocument
    ) throws -> SafariBookmarkMutationResult {
        guard nativeIdentityRepository.nativeIdentifier(
            for: operation.logicalNodeID,
            sourceID: sourceID
        ) == nil else {
            throw SafariBookmarkMutationError.nativeIdentityAlreadyExists(
                operation.logicalNodeID
            )
        }
        let parent = try resolveParent(
            operation.parentID,
            root: root,
            index: index
        )
        let children = try index.children(of: parent)
        try validateInsertionPosition(operation.position, childCount: children.count)

        switch operation.kind {
        case .folder where operation.url != nil,
             .bookmark where operation.url == nil:
            throw SafariBookmarkMutationError.invalidCreateOperation(operation.logicalNodeID)
        default:
            break
        }

        let nativeIdentifier: NativeNodeIdentifier
        do {
            nativeIdentifier = try nativeIdentifierProvider.makeIdentifier()
        } catch {
            throw SafariBookmarkMutationError.nativeIdentifierGenerationFailed
        }
        guard !nativeIdentifier.rawValue.isEmpty else {
            throw SafariBookmarkMutationError.nativeIdentifierGenerationFailed
        }
        guard !index.contains(uuid: nativeIdentifier.rawValue) else {
            throw SafariBookmarkMutationError.duplicateUUID(nativeIdentifier.rawValue)
        }

        children.insert(
            makeNode(operation, nativeIdentifier: nativeIdentifier),
            at: operation.position
        )
        let result = try finalizedDocument(root: root, preserving: document)
        return SafariBookmarkMutationResult(
            document: result,
            nativeIdentityChanges: [
                .register(
                    logicalNodeID: operation.logicalNodeID,
                    sourceID: sourceID,
                    nativeIdentifier: nativeIdentifier
                ),
            ]
        )
    }

    private func delete(
        _ operation: DeleteNodeOperation,
        root: NSMutableDictionary,
        index: SafariBookmarkIndex,
        document: SafariBookmarkDocument
    ) throws -> SafariBookmarkMutationResult {
        let nativeIdentifier = try resolve(operation.logicalNodeID)
        let node = try index.node(for: nativeIdentifier)
        guard nativeIdentifier.rawValue != index.rootUUID else {
            throw SafariBookmarkMutationError.cannotMutateRoot(operation.logicalNodeID)
        }
        if node["WebBookmarkType"] as? String == "WebBookmarkTypeList",
           let childUUIDs = index.childUUIDs(for: nativeIdentifier),
           !childUUIDs.isEmpty {
            throw SafariBookmarkMutationError.nonEmptyFolder(operation.logicalNodeID)
        }

        let parent = try parentNode(of: nativeIdentifier, index: index)
        let children = try index.children(of: parent)
        guard let position = index.position(for: nativeIdentifier),
              position < children.count else {
            throw SafariBookmarkMutationError.invalidDocument
        }
        children.removeObject(at: position)

        let result = try finalizedDocument(root: root, preserving: document)
        return SafariBookmarkMutationResult(
            document: result,
            nativeIdentityChanges: [
                .remove(
                    logicalNodeID: operation.logicalNodeID,
                    sourceID: sourceID
                ),
            ]
        )
    }

    private func rename(
        _ operation: RenameNodeOperation,
        root: NSMutableDictionary,
        index: SafariBookmarkIndex,
        document: SafariBookmarkDocument
    ) throws -> SafariBookmarkMutationResult {
        let node = try index.node(for: resolve(operation.logicalNodeID))
        switch node["WebBookmarkType"] as? String {
        case "WebBookmarkTypeList":
            node["Title"] = operation.title
        case "WebBookmarkTypeLeaf":
            let uriValue = node["URIDictionary"]
            let uriDictionary: NSMutableDictionary
            if let mutableDictionary = uriValue as? NSMutableDictionary {
                uriDictionary = mutableDictionary
            } else if uriValue == nil {
                uriDictionary = NSMutableDictionary()
                node["URIDictionary"] = uriDictionary
            } else {
                throw SafariBookmarkMutationError.invalidDocument
            }
            uriDictionary["title"] = operation.title
        default:
            throw SafariBookmarkMutationError.invalidDocument
        }
        return try resultWithoutIdentityChanges(root: root, preserving: document)
    }

    private func updateURL(
        _ operation: UpdateURLOperation,
        root: NSMutableDictionary,
        index: SafariBookmarkIndex,
        document: SafariBookmarkDocument
    ) throws -> SafariBookmarkMutationResult {
        let node = try index.node(for: resolve(operation.logicalNodeID))
        guard node["WebBookmarkType"] as? String == "WebBookmarkTypeLeaf" else {
            throw SafariBookmarkMutationError.URLUpdateRequiresBookmark(
                operation.logicalNodeID
            )
        }
        node["URLString"] = operation.url.absoluteString
        return try resultWithoutIdentityChanges(root: root, preserving: document)
    }

    private func move(
        _ operation: MoveNodeOperation,
        root: NSMutableDictionary,
        index: SafariBookmarkIndex,
        document: SafariBookmarkDocument
    ) throws -> SafariBookmarkMutationResult {
        let nativeIdentifier = try resolve(operation.logicalNodeID)
        let node = try index.node(for: nativeIdentifier)
        guard nativeIdentifier.rawValue != index.rootUUID else {
            throw SafariBookmarkMutationError.cannotMutateRoot(operation.logicalNodeID)
        }
        let newParent = try resolveParent(operation.parentID, root: root, index: index)
        let newParentIdentifier = NativeNodeIdentifier(
            newParent["WebBookmarkUUID"] as? String ?? ""
        )
        try validateNoCycle(
            moving: nativeIdentifier,
            below: newParentIdentifier,
            logicalNodeID: operation.logicalNodeID,
            index: index
        )

        let oldParent = try parentNode(of: nativeIdentifier, index: index)
        let oldChildren = try index.children(of: oldParent)
        let newChildren = try index.children(of: newParent)
        guard let oldPosition = index.position(for: nativeIdentifier),
              oldPosition < oldChildren.count else {
            throw SafariBookmarkMutationError.invalidDocument
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
        index: SafariBookmarkIndex,
        document: SafariBookmarkDocument
    ) throws -> SafariBookmarkMutationResult {
        let nativeIdentifier = try resolve(operation.logicalNodeID)
        let node = try index.node(for: nativeIdentifier)
        guard nativeIdentifier.rawValue != index.rootUUID else {
            throw SafariBookmarkMutationError.cannotMutateRoot(operation.logicalNodeID)
        }
        let parent = try parentNode(of: nativeIdentifier, index: index)
        let children = try index.children(of: parent)
        guard let oldPosition = index.position(for: nativeIdentifier),
              oldPosition < children.count else {
            throw SafariBookmarkMutationError.invalidDocument
        }
        try validateInsertionPosition(operation.position, childCount: children.count - 1)

        children.removeObject(at: oldPosition)
        children.insert(node, at: operation.position)
        return try resultWithoutIdentityChanges(root: root, preserving: document)
    }

    private func makeNode(
        _ operation: CreateNodeOperation,
        nativeIdentifier: NativeNodeIdentifier
    ) -> NSMutableDictionary {
        switch operation.kind {
        case .folder:
            return NSMutableDictionary(dictionary: [
                "WebBookmarkType": "WebBookmarkTypeList",
                "WebBookmarkUUID": nativeIdentifier.rawValue,
                "Title": operation.title,
                "Children": NSMutableArray(),
            ])
        case .bookmark:
            return NSMutableDictionary(dictionary: [
                "WebBookmarkType": "WebBookmarkTypeLeaf",
                "WebBookmarkUUID": nativeIdentifier.rawValue,
                "URLString": operation.url?.absoluteString ?? "",
                "URIDictionary": NSMutableDictionary(dictionary: [
                    "title": operation.title,
                ]),
            ])
        }
    }

    private func resolve(_ logicalNodeID: LogicalNodeID) throws -> NativeNodeIdentifier {
        guard let nativeIdentifier = nativeIdentityRepository.nativeIdentifier(
            for: logicalNodeID,
            sourceID: sourceID
        ) else {
            throw SafariBookmarkMutationError.nativeIdentityMissing(logicalNodeID)
        }
        return nativeIdentifier
    }

    private func resolveParent(
        _ logicalNodeID: LogicalNodeID?,
        root: NSMutableDictionary,
        index: SafariBookmarkIndex
    ) throws -> NSMutableDictionary {
        guard let logicalNodeID else { return root }
        guard let nativeIdentifier = nativeIdentityRepository.nativeIdentifier(
            for: logicalNodeID,
            sourceID: sourceID
        ) else {
            throw SafariBookmarkMutationError.parentNotFound(logicalNodeID)
        }
        do {
            return try index.node(for: nativeIdentifier)
        } catch SafariBookmarkMutationError.nativeNodeNotFound(_) {
            throw SafariBookmarkMutationError.parentNotFound(logicalNodeID)
        }
    }

    private func parentNode(
        of nativeIdentifier: NativeNodeIdentifier,
        index: SafariBookmarkIndex
    ) throws -> NSMutableDictionary {
        guard let parentUUID = index.parentUUID(for: nativeIdentifier) else {
            throw SafariBookmarkMutationError.invalidDocument
        }
        return try index.node(for: NativeNodeIdentifier(parentUUID))
    }

    private func validateNoCycle(
        moving nativeIdentifier: NativeNodeIdentifier,
        below newParentIdentifier: NativeNodeIdentifier,
        logicalNodeID: LogicalNodeID,
        index: SafariBookmarkIndex
    ) throws {
        var currentUUID: String? = newParentIdentifier.rawValue
        while let uuid = currentUUID {
            guard uuid != nativeIdentifier.rawValue else {
                throw SafariBookmarkMutationError.cycleDetected(logicalNodeID)
            }
            currentUUID = index.parentUUID(for: NativeNodeIdentifier(uuid))
        }
    }

    private func validateInsertionPosition(_ position: Int, childCount: Int) throws {
        guard position >= 0, position <= childCount else {
            throw SafariBookmarkMutationError.invalidPosition(position)
        }
    }

    private func mutableRoot(from document: SafariBookmarkDocument) throws -> NSMutableDictionary {
        let propertyList: Any
        do {
            propertyList = try PropertyListSerialization.propertyList(
                from: document.data,
                options: [.mutableContainersAndLeaves],
                format: nil
            )
        } catch {
            throw SafariBookmarkMutationError.invalidDocument
        }
        guard let root = propertyList as? NSMutableDictionary else {
            throw SafariBookmarkMutationError.invalidDocument
        }
        return root
    }

    private func finalizedDocument(
        root: NSMutableDictionary,
        preserving document: SafariBookmarkDocument
    ) throws -> SafariBookmarkDocument {
        _ = try SafariBookmarkIndex(root: root)
        let data: Data
        do {
            data = try PropertyListSerialization.data(
                fromPropertyList: root,
                format: propertyListFormat(document.format),
                options: 0
            )
        } catch {
            throw SafariBookmarkMutationError.serializationFailed
        }
        do {
            return try SafariBookmarkDocument(
                data: data,
                sourceFingerprint: document.sourceFingerprint
            )
        } catch {
            throw SafariBookmarkMutationError.serializationFailed
        }
    }

    private func resultWithoutIdentityChanges(
        root: NSMutableDictionary,
        preserving document: SafariBookmarkDocument
    ) throws -> SafariBookmarkMutationResult {
        SafariBookmarkMutationResult(
            document: try finalizedDocument(root: root, preserving: document),
            nativeIdentityChanges: []
        )
    }

    private func propertyListFormat(
        _ format: SafariPropertyListFormat
    ) -> PropertyListSerialization.PropertyListFormat {
        switch format {
        case .binary: .binary
        case .xml: .xml
        case .openStep: .openStep
        }
    }
}
