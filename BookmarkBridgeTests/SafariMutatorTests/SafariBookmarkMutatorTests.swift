//
//  SafariBookmarkMutatorTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Safari bookmark mutator")
struct SafariBookmarkMutatorTests {
    @Test("Create folder returns its deferred native identity registration")
    func createFolder() throws {
        let setup = try MutatorTestSupport.setup()
        let createdID = MutatorTestSupport.logicalID(30)
        let nativeID = NativeNodeIdentifier("00000000-0000-0000-0000-000000000030")
        let mutator = setup.mutator(provider: FixedNativeIdentifierProvider(nativeID))

        let result = try mutator.apply(.create(CreateNodeOperation(
            logicalNodeID: createdID,
            kind: .folder,
            title: "Created",
            url: nil,
            parentID: nil,
            position: 1
        )), to: setup.document)

        let root = try MutatorTestSupport.root(of: result.document)
        #expect(try MutatorTestSupport.childUUIDs(of: root) == [
            MutatorTestSupport.folderAUUID,
            nativeID.rawValue,
            MutatorTestSupport.folderBUUID,
        ])
        let created = try #require(MutatorTestSupport.node(nativeID.rawValue, in: root))
        #expect(created["WebBookmarkType"] as? String == "WebBookmarkTypeList")
        #expect(created["Title"] as? String == "Created")
        #expect(try MutatorTestSupport.children(of: created).isEmpty)
        #expect(result.nativeIdentityChanges == [
            .register(
                logicalNodeID: createdID,
                sourceID: MutatorTestSupport.sourceID,
                nativeIdentifier: nativeID
            ),
        ])
        #expect(setup.repository.nativeIdentifier(
            for: createdID,
            sourceID: MutatorTestSupport.sourceID
        ) == nil)
    }

    @Test("Create bookmark uses the injected identifier and exact parent position")
    func createBookmark() throws {
        let setup = try MutatorTestSupport.setup()
        let createdID = MutatorTestSupport.logicalID(31)
        let nativeID = NativeNodeIdentifier("00000000-0000-0000-0000-000000000031")
        let url = try #require(URL(string: "https://created.example/path"))
        let mutator = setup.mutator(provider: FixedNativeIdentifierProvider(nativeID))

        let result = try mutator.apply(.create(CreateNodeOperation(
            logicalNodeID: createdID,
            kind: .bookmark,
            title: "Created bookmark",
            url: url,
            parentID: MutatorTestSupport.folderAID,
            position: 1
        )), to: setup.document)

        let root = try MutatorTestSupport.root(of: result.document)
        let folder = try #require(MutatorTestSupport.node(
            MutatorTestSupport.folderAUUID,
            in: root
        ))
        #expect(try MutatorTestSupport.childUUIDs(of: folder)[1] == nativeID.rawValue)
        let created = try #require(MutatorTestSupport.node(nativeID.rawValue, in: root))
        #expect(created["URLString"] as? String == url.absoluteString)
        #expect((created["URIDictionary"] as? [String: Any])?["title"] as? String
            == "Created bookmark")
        #expect(result.nativeIdentityChanges == [
            .register(
                logicalNodeID: createdID,
                sourceID: MutatorTestSupport.sourceID,
                nativeIdentifier: nativeID
            ),
        ])
        #expect(setup.repository.nativeIdentifier(
            for: createdID,
            sourceID: MutatorTestSupport.sourceID
        ) == nil)
    }

    @Test("Delete returns its deferred native identity removal")
    func deleteBookmark() throws {
        let setup = try MutatorTestSupport.setup()

        let result = try setup.mutator().apply(.delete(DeleteNodeOperation(
            logicalNodeID: MutatorTestSupport.bookmarkAID
        )), to: setup.document)

        let root = try MutatorTestSupport.root(of: result.document)
        #expect(MutatorTestSupport.node(MutatorTestSupport.bookmarkAUUID, in: root) == nil)
        #expect(result.nativeIdentityChanges == [
            .remove(
                logicalNodeID: MutatorTestSupport.bookmarkAID,
                sourceID: MutatorTestSupport.sourceID
            ),
        ])
        #expect(setup.repository.nativeIdentifier(
            for: MutatorTestSupport.bookmarkAID,
            sourceID: MutatorTestSupport.sourceID
        ) == NativeNodeIdentifier(MutatorTestSupport.bookmarkAUUID))
    }

    @Test("Delete accepts an empty folder")
    func deleteEmptyFolder() throws {
        let setup = try MutatorTestSupport.setup()

        let result = try setup.mutator().apply(.delete(DeleteNodeOperation(
            logicalNodeID: MutatorTestSupport.emptyFolderID
        )), to: setup.document)

        #expect(MutatorTestSupport.node(
            MutatorTestSupport.emptyFolderUUID,
            in: try MutatorTestSupport.root(of: result.document)
        ) == nil)
        #expect(result.nativeIdentityChanges == [
            .remove(
                logicalNodeID: MutatorTestSupport.emptyFolderID,
                sourceID: MutatorTestSupport.sourceID
            ),
        ])
    }

    @Test("Delete refuses a non-empty folder without changing its mapping")
    func refuseNonEmptyFolderDeletion() throws {
        let setup = try MutatorTestSupport.setup()

        #expect(throws: SafariBookmarkMutationError.nonEmptyFolder(
            MutatorTestSupport.folderAID
        )) {
            _ = try setup.mutator().apply(.delete(DeleteNodeOperation(
                logicalNodeID: MutatorTestSupport.folderAID
            )), to: setup.document)
        }
        #expect(setup.repository.nativeIdentifier(
            for: MutatorTestSupport.folderAID,
            sourceID: MutatorTestSupport.sourceID
        ) == NativeNodeIdentifier(MutatorTestSupport.folderAUUID))
    }

    @Test("Rename changes only a bookmark title")
    func renameBookmark() throws {
        let setup = try MutatorTestSupport.setup()
        let beforeRoot = try MutatorTestSupport.root(of: setup.document)
        let before = try #require(MutatorTestSupport.node(
            MutatorTestSupport.bookmarkAUUID,
            in: beforeRoot
        ))
        let beforeURL = before["URLString"] as? String
        let beforeMetadata = before["UnknownBookmarkMetadata"] as? [String: AnyHashable]

        let result = try setup.mutator().apply(.rename(RenameNodeOperation(
            logicalNodeID: MutatorTestSupport.bookmarkAID,
            title: "Renamed"
        )), to: setup.document)

        let node = try #require(MutatorTestSupport.node(
            MutatorTestSupport.bookmarkAUUID,
            in: try MutatorTestSupport.root(of: result.document)
        ))
        #expect((node["URIDictionary"] as? [String: Any])?["title"] as? String == "Renamed")
        #expect(node["URLString"] as? String == beforeURL)
        #expect(node["UnknownBookmarkMetadata"] as? [String: AnyHashable] == beforeMetadata)
        #expect(node["WebBookmarkUUID"] as? String == MutatorTestSupport.bookmarkAUUID)
        #expect(result.nativeIdentityChanges.isEmpty)
    }

    @Test("Update URL changes only a bookmark URL")
    func updateURL() throws {
        let setup = try MutatorTestSupport.setup()
        let url = try #require(URL(string: "https://updated.example"))

        let result = try setup.mutator().apply(.updateURL(UpdateURLOperation(
            logicalNodeID: MutatorTestSupport.bookmarkAID,
            url: url
        )), to: setup.document)

        let node = try #require(MutatorTestSupport.node(
            MutatorTestSupport.bookmarkAUUID,
            in: try MutatorTestSupport.root(of: result.document)
        ))
        #expect(node["URLString"] as? String == url.absoluteString)
        #expect((node["URIDictionary"] as? [String: Any])?["title"] as? String == "A")
        #expect(node["UnknownBookmarkMetadata"] != nil)
        #expect(result.nativeIdentityChanges.isEmpty)
    }

    @Test("Update URL refuses a folder")
    func updateURLOnFolder() throws {
        let setup = try MutatorTestSupport.setup()
        let url = try #require(URL(string: "https://invalid.example"))

        #expect(throws: SafariBookmarkMutationError.URLUpdateRequiresBookmark(
            MutatorTestSupport.folderAID
        )) {
            _ = try setup.mutator().apply(.updateURL(UpdateURLOperation(
                logicalNodeID: MutatorTestSupport.folderAID,
                url: url
            )), to: setup.document)
        }
    }

    @Test("Complex move preserves identity and metadata at the exact destination")
    func complexMove() throws {
        let setup = try MutatorTestSupport.setup()

        let result = try setup.mutator().apply(.move(MoveNodeOperation(
            logicalNodeID: MutatorTestSupport.bookmarkAID,
            parentID: MutatorTestSupport.folderBID,
            position: 1
        )), to: setup.document)

        let root = try MutatorTestSupport.root(of: result.document)
        let folderA = try #require(MutatorTestSupport.node(
            MutatorTestSupport.folderAUUID,
            in: root
        ))
        let folderB = try #require(MutatorTestSupport.node(
            MutatorTestSupport.folderBUUID,
            in: root
        ))
        let folderAChildUUIDs = try MutatorTestSupport.childUUIDs(of: folderA)
        #expect(!folderAChildUUIDs.contains(
            MutatorTestSupport.bookmarkAUUID
        ))
        #expect(try MutatorTestSupport.childUUIDs(of: folderB) == [
            MutatorTestSupport.bookmarkCUUID,
            MutatorTestSupport.bookmarkAUUID,
        ])
        let moved = try #require(MutatorTestSupport.node(
            MutatorTestSupport.bookmarkAUUID,
            in: root
        ))
        #expect(moved["WebBookmarkUUID"] as? String == MutatorTestSupport.bookmarkAUUID)
        #expect(moved["UnknownBookmarkMetadata"] != nil)
        #expect(result.nativeIdentityChanges.isEmpty)
    }

    @Test("Move to the plist root applies the supplied position")
    func moveToRoot() throws {
        let setup = try MutatorTestSupport.setup()

        let result = try setup.mutator().apply(.move(MoveNodeOperation(
            logicalNodeID: MutatorTestSupport.bookmarkAID,
            parentID: nil,
            position: 1
        )), to: setup.document)

        #expect(try MutatorTestSupport.childUUIDs(
            of: MutatorTestSupport.root(of: result.document)
        ) == [
            MutatorTestSupport.folderAUUID,
            MutatorTestSupport.bookmarkAUUID,
            MutatorTestSupport.folderBUUID,
        ])
        #expect(result.nativeIdentityChanges.isEmpty)
    }

    @Test("Move refuses to place a folder below its descendant")
    func cycle() throws {
        let setup = try MutatorTestSupport.setup()

        #expect(throws: SafariBookmarkMutationError.cycleDetected(
            MutatorTestSupport.folderAID
        )) {
            _ = try setup.mutator().apply(.move(MoveNodeOperation(
                logicalNodeID: MutatorTestSupport.folderAID,
                parentID: MutatorTestSupport.emptyFolderID,
                position: 0
            )), to: setup.document)
        }
    }

    @Test("Move fails explicitly when its parent mapping is absent")
    func parentAbsent() throws {
        let setup = try MutatorTestSupport.setup()
        let missingParentID = MutatorTestSupport.logicalID(99)

        #expect(throws: SafariBookmarkMutationError.parentNotFound(missingParentID)) {
            _ = try setup.mutator().apply(.move(MoveNodeOperation(
                logicalNodeID: MutatorTestSupport.bookmarkAID,
                parentID: missingParentID,
                position: 0
            )), to: setup.document)
        }
    }

    @Test("Reorder changes only sibling order")
    func reorder() throws {
        let setup = try MutatorTestSupport.setup()

        let result = try setup.mutator().apply(.reorder(ReorderNodeOperation(
            logicalNodeID: MutatorTestSupport.bookmarkBID,
            position: 0
        )), to: setup.document)

        let root = try MutatorTestSupport.root(of: result.document)
        let folder = try #require(MutatorTestSupport.node(
            MutatorTestSupport.folderAUUID,
            in: root
        ))
        #expect(try MutatorTestSupport.childUUIDs(of: folder) == [
            MutatorTestSupport.bookmarkBUUID,
            MutatorTestSupport.bookmarkAUUID,
            MutatorTestSupport.emptyFolderUUID,
        ])
        #expect(MutatorTestSupport.node(MutatorTestSupport.bookmarkAUUID, in: root) != nil)
        #expect(result.nativeIdentityChanges.isEmpty)
    }

    @Test("Invalid positions are rejected without registering a creation")
    func invalidPosition() throws {
        let setup = try MutatorTestSupport.setup()
        let createdID = MutatorTestSupport.logicalID(40)

        #expect(throws: SafariBookmarkMutationError.invalidPosition(20)) {
            _ = try setup.mutator(provider: FixedNativeIdentifierProvider(
                NativeNodeIdentifier("00000000-0000-0000-0000-000000000040")
            )).apply(.create(CreateNodeOperation(
                logicalNodeID: createdID,
                kind: .folder,
                title: "Invalid",
                url: nil,
                parentID: nil,
                position: 20
            )), to: setup.document)
        }
        #expect(setup.repository.nativeIdentifier(
            for: createdID,
            sourceID: MutatorTestSupport.sourceID
        ) == nil)
    }

    @Test("A failure after identifier generation leaves repository and input unchanged")
    func failedCreateAfterIdentifierGeneration() throws {
        let setup = try MutatorTestSupport.setup()
        let createdID = MutatorTestSupport.logicalID(41)
        let originalDocument = setup.document

        #expect(throws: SafariBookmarkMutationError.duplicateUUID(
            MutatorTestSupport.folderAUUID
        )) {
            _ = try setup.mutator(provider: FixedNativeIdentifierProvider(
                NativeNodeIdentifier(MutatorTestSupport.folderAUUID)
            )).apply(.create(CreateNodeOperation(
                logicalNodeID: createdID,
                kind: .folder,
                title: "Must not escape",
                url: nil,
                parentID: nil,
                position: 0
            )), to: setup.document)
        }

        #expect(setup.repository.nativeIdentifier(
            for: createdID,
            sourceID: MutatorTestSupport.sourceID
        ) == nil)
        #expect(setup.repository.nativeIdentifier(
            for: MutatorTestSupport.folderAID,
            sourceID: MutatorTestSupport.sourceID
        ) == NativeNodeIdentifier(MutatorTestSupport.folderAUUID))
        #expect(setup.document == originalDocument)
    }

    @Test("A missing UUID invalidates the document before mutation")
    func UUIDAbsent() throws {
        var propertyList = MutatorTestSupport.propertyList()
        var children = try #require(propertyList["Children"] as? [[String: Any]])
        children[0].removeValue(forKey: "WebBookmarkUUID")
        propertyList["Children"] = children
        let document = try MutatorTestSupport.document(propertyList)
        let setup = try MutatorTestSupport.setup(document: document)

        #expect(throws: SafariBookmarkMutationError.missingUUID) {
            _ = try setup.mutator().apply(.rename(RenameNodeOperation(
                logicalNodeID: MutatorTestSupport.bookmarkAID,
                title: "No mutation"
            )), to: document)
        }
    }

    @Test("A duplicate UUID invalidates the document before mutation")
    func duplicatedUUID() throws {
        var propertyList = MutatorTestSupport.propertyList()
        var children = try #require(propertyList["Children"] as? [[String: Any]])
        children[1]["WebBookmarkUUID"] = MutatorTestSupport.folderAUUID
        propertyList["Children"] = children
        let document = try MutatorTestSupport.document(propertyList)
        let setup = try MutatorTestSupport.setup(document: document)

        #expect(throws: SafariBookmarkMutationError.duplicateUUID(
            MutatorTestSupport.folderAUUID
        )) {
            _ = try setup.mutator().apply(.rename(RenameNodeOperation(
                logicalNodeID: MutatorTestSupport.bookmarkAID,
                title: "No mutation"
            )), to: document)
        }
    }

    @Test("Unknown root keys, metadata, format and fingerprint survive mutation")
    func preservesDocumentEnvelope() throws {
        let document = try MutatorTestSupport.document(
            MutatorTestSupport.propertyList(),
            format: .xml
        )
        let setup = try MutatorTestSupport.setup(document: document)

        let result = try setup.mutator().apply(.rename(RenameNodeOperation(
            logicalNodeID: MutatorTestSupport.bookmarkAID,
            title: "Renamed"
        )), to: document)
        let root = try MutatorTestSupport.root(of: result.document)

        #expect(result.document.format == .xml)
        #expect(result.document.sourceFingerprint == document.sourceFingerprint)
        #expect(root["UnknownRootKey"] as? Data == MutatorTestSupport.rootMetadata)
        #expect(root["WebBookmarkUUID"] as? String == MutatorTestSupport.rootUUID)
        #expect(result.nativeIdentityChanges.isEmpty)
    }

    @Test("A mapping registered for another source is never used")
    func sourceIsolation() throws {
        let otherSource = BSESourceID(MutatorTestSupport.UUID(901))
        let repository = InMemoryNativeIdentityRepository(mappings: [
            NativeIdentityMapping(
                logicalNodeID: MutatorTestSupport.bookmarkAID,
                sourceID: otherSource,
                nativeIdentifier: NativeNodeIdentifier(MutatorTestSupport.bookmarkAUUID)
            ),
        ])
        let document = try MutatorTestSupport.document(MutatorTestSupport.propertyList())
        let mutator = SafariBookmarkMutator(
            sourceID: MutatorTestSupport.sourceID,
            nativeIdentityRepository: repository,
            nativeIdentifierProvider: FixedNativeIdentifierProvider(
                NativeNodeIdentifier("unused")
            )
        )

        #expect(throws: SafariBookmarkMutationError.nativeIdentityMissing(
            MutatorTestSupport.bookmarkAID
        )) {
            _ = try mutator.apply(.rename(RenameNodeOperation(
                logicalNodeID: MutatorTestSupport.bookmarkAID,
                title: "No mutation"
            )), to: document)
        }
    }

    @Test("Archive remains explicitly unsupported by the Safari mutator")
    func archiveUnsupported() throws {
        let setup = try MutatorTestSupport.setup()

        #expect(throws: SafariBookmarkMutationError.unsupportedOperation(
            MutatorTestSupport.bookmarkAID
        )) {
            _ = try setup.mutator().apply(.archive(ArchiveNodeOperation(
                logicalNodeID: MutatorTestSupport.bookmarkAID,
                state: .archived
            )), to: setup.document)
        }
    }

    @Test("Mutator and injected providers satisfy Sendable contracts")
    func strictConcurrency() throws {
        let setup = try MutatorTestSupport.setup()
        let provider = FixedNativeIdentifierProvider(NativeNodeIdentifier("fixed"))
        let result = SafariBookmarkMutationResult(
            document: setup.document,
            nativeIdentityChanges: [
                .remove(
                    logicalNodeID: MutatorTestSupport.bookmarkAID,
                    sourceID: MutatorTestSupport.sourceID
                ),
            ]
        )

        requireSendable(setup.mutator(provider: provider))
        requireSendable(provider as any NativeIdentifierProviding)
        requireSendable(result)
        #expect(Set([result]).contains(result))
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}

private nonisolated struct FixedNativeIdentifierProvider: NativeIdentifierProviding {
    let identifier: NativeNodeIdentifier

    init(_ identifier: NativeNodeIdentifier) {
        self.identifier = identifier
    }

    func makeIdentifier() -> NativeNodeIdentifier { identifier }
}

private nonisolated enum MutatorTestSupport {
    static let sourceID = BSESourceID(UUID(900))
    static let rootUUID = "00000000-0000-0000-0000-000000000001"
    static let folderAUUID = "00000000-0000-0000-0000-000000000010"
    static let bookmarkAUUID = "00000000-0000-0000-0000-000000000011"
    static let bookmarkBUUID = "00000000-0000-0000-0000-000000000012"
    static let emptyFolderUUID = "00000000-0000-0000-0000-000000000013"
    static let folderBUUID = "00000000-0000-0000-0000-000000000020"
    static let bookmarkCUUID = "00000000-0000-0000-0000-000000000021"
    static let rootMetadata = Data([0x01, 0x02, 0x03])

    static let folderAID = logicalID(10)
    static let bookmarkAID = logicalID(11)
    static let bookmarkBID = logicalID(12)
    static let emptyFolderID = logicalID(13)
    static let folderBID = logicalID(20)
    static let bookmarkCID = logicalID(21)

    struct Setup {
        let document: SafariBookmarkDocument
        let repository: InMemoryNativeIdentityRepository

        func mutator(
            provider: any NativeIdentifierProviding = FixedNativeIdentifierProvider(
                NativeNodeIdentifier("unused")
            )
        ) -> SafariBookmarkMutator {
            SafariBookmarkMutator(
                sourceID: sourceID,
                nativeIdentityRepository: repository,
                nativeIdentifierProvider: provider
            )
        }
    }

    static func setup(document: SafariBookmarkDocument? = nil) throws -> Setup {
        Setup(
            document: try document ?? self.document(propertyList()),
            repository: InMemoryNativeIdentityRepository(mappings: mappings)
        )
    }

    static var mappings: [NativeIdentityMapping] {
        [
            mapping(folderAID, folderAUUID),
            mapping(bookmarkAID, bookmarkAUUID),
            mapping(bookmarkBID, bookmarkBUUID),
            mapping(emptyFolderID, emptyFolderUUID),
            mapping(folderBID, folderBUUID),
            mapping(bookmarkCID, bookmarkCUUID),
        ]
    }

    static func mapping(
        _ logicalNodeID: LogicalNodeID,
        _ nativeUUID: String
    ) -> NativeIdentityMapping {
        NativeIdentityMapping(
            logicalNodeID: logicalNodeID,
            sourceID: sourceID,
            nativeIdentifier: NativeNodeIdentifier(nativeUUID)
        )
    }

    static func propertyList() -> [String: Any] {
        [
            "WebBookmarkType": "WebBookmarkTypeList",
            "WebBookmarkUUID": rootUUID,
            "WebBookmarkFileVersion": 1,
            "Title": "",
            "UnknownRootKey": rootMetadata,
            "Children": [
                folder(
                    UUID: folderAUUID,
                    title: "Folder A",
                    metadata: ["UnknownFolderKey": Date(timeIntervalSinceReferenceDate: 42)],
                    children: [
                        bookmark(UUID: bookmarkAUUID, title: "A", URL: "https://a.example"),
                        bookmark(UUID: bookmarkBUUID, title: "B", URL: "https://b.example"),
                        folder(UUID: emptyFolderUUID, title: "Empty", children: []),
                    ]
                ),
                folder(
                    UUID: folderBUUID,
                    title: "Folder B",
                    children: [
                        bookmark(UUID: bookmarkCUUID, title: "C", URL: "https://c.example"),
                    ]
                ),
            ],
        ]
    }

    static func document(
        _ propertyList: [String: Any],
        format: PropertyListSerialization.PropertyListFormat = .binary
    ) throws -> SafariBookmarkDocument {
        let data = try PropertyListSerialization.data(
            fromPropertyList: propertyList,
            format: format,
            options: 0
        )
        return try SafariBookmarkDocument(
            data: data,
            sourceFingerprint: SafariPersistenceFixture.placeholderFingerprint
        )
    }

    static func root(of document: SafariBookmarkDocument) throws -> [String: Any] {
        try #require(PropertyListSerialization.propertyList(
            from: document.data,
            options: [],
            format: nil
        ) as? [String: Any])
    }

    static func node(_ UUID: String, in node: [String: Any]) -> [String: Any]? {
        if node["WebBookmarkUUID"] as? String == UUID { return node }
        guard let children = node["Children"] as? [[String: Any]] else { return nil }
        for child in children {
            if let match = self.node(UUID, in: child) { return match }
        }
        return nil
    }

    static func children(of node: [String: Any]) throws -> [[String: Any]] {
        try #require(node["Children"] as? [[String: Any]])
    }

    static func childUUIDs(of node: [String: Any]) throws -> [String] {
        try children(of: node).map { try #require($0["WebBookmarkUUID"] as? String) }
    }

    static func folder(
        UUID: String,
        title: String,
        metadata: [String: Any] = [:],
        children: [[String: Any]]
    ) -> [String: Any] {
        var node: [String: Any] = [
            "WebBookmarkType": "WebBookmarkTypeList",
            "WebBookmarkUUID": UUID,
            "Title": title,
            "Children": children,
        ]
        metadata.forEach { node[$0.key] = $0.value }
        return node
    }

    static func bookmark(UUID: String, title: String, URL: String) -> [String: Any] {
        [
            "WebBookmarkType": "WebBookmarkTypeLeaf",
            "WebBookmarkUUID": UUID,
            "URLString": URL,
            "URIDictionary": ["title": title, "UnknownURIKey": true],
            "UnknownBookmarkMetadata": ["score": 7, "enabled": true],
        ]
    }

    static func logicalID(_ value: Int) -> LogicalNodeID {
        LogicalNodeID(UUID(value))
    }

    static func UUID(_ value: Int) -> Foundation.UUID {
        Foundation.UUID(uuidString: String(
            format: "00000000-0000-0000-0000-%012d",
            value
        ))!
    }
}
