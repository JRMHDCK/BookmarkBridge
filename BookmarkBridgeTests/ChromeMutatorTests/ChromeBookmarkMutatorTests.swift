//
//  ChromeBookmarkMutatorTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Synchronization
import Testing
@testable import BookmarkBridge

@Suite("BSE Chrome bookmark mutator")
struct ChromeBookmarkMutatorTests {
    @Test("Create returns a deferred registration and does not mutate the repository")
    func create() throws {
        let setup = try ChromeMutatorTestSupport.setup()
        let createdID = ChromeMutatorTestSupport.logicalID(30)
        let nativeID = NativeNodeIdentifier("created-native-30")
        let provider = RecordingNativeIdentifierProvider(identifier: nativeID)
        let url = try #require(URL(string: "https://created.example/path"))

        let result = try setup.mutator(provider: provider).apply(.create(
            CreateNodeOperation(
                logicalNodeID: createdID,
                kind: .bookmark,
                title: "Created",
                url: url,
                parentID: ChromeMutatorTestSupport.barID,
                position: 1
            )
        ), to: setup.document)

        let created = try #require(ChromeMutatorTestSupport.node(
            nativeID.rawValue,
            in: result.document
        ))
        #expect(created["id"] as? String == "23")
        #expect(created["type"] as? String == "url")
        #expect(created["name"] as? String == "Created")
        #expect(created["url"] as? String == url.absoluteString)
        #expect(created["guid"] as? String == nativeID.rawValue)
        #expect(result.nativeIdentityChanges == [
            .register(
                logicalNodeID: createdID,
                sourceID: ChromeMutatorTestSupport.sourceID,
                nativeIdentifier: NativeNodeIdentifier(
                    "guid:\(nativeID.rawValue)"
                )
            ),
        ])
        #expect(provider.callCount == 1)
        #expect(setup.repository.nativeIdentifier(
            for: createdID,
            sourceID: ChromeMutatorTestSupport.sourceID
        ) == nil)
        #expect(setup.repository.writeCount == 0)
    }

    @Test("Create folder preserves all roots and creates an empty children array")
    func createFolder() throws {
        let setup = try ChromeMutatorTestSupport.setup()
        let createdID = ChromeMutatorTestSupport.logicalID(31)
        let nativeID = NativeNodeIdentifier("created-native-31")

        let result = try setup.mutator(provider: RecordingNativeIdentifierProvider(
            identifier: nativeID
        )).apply(.create(CreateNodeOperation(
            logicalNodeID: createdID,
            kind: .folder,
            title: "Created folder",
            url: nil,
            parentID: ChromeMutatorTestSupport.otherID,
            position: 1
        )), to: setup.document)

        let node = try #require(ChromeMutatorTestSupport.node(nativeID.rawValue, in: result.document))
        #expect(node["type"] as? String == "folder")
        #expect(node["id"] as? String == "23")
        #expect(node["guid"] as? String == nativeID.rawValue)
        #expect((node["children"] as? [Any])?.isEmpty == true)
        #expect(Set(try ChromeMutatorTestSupport.roots(in: result.document).keys) == [
            "bookmark_bar", "other", "synced",
        ])
    }

    @Test("A dependency-ordered plan creates a three-level Chrome tree")
    func dependencyOrderedNestedCreationPlan() throws {
        let setup = try ChromeMutatorTestSupport.setup()
        let parent = try ChromeMutatorTestSupport.logicalFolder(
            id: 90,
            parent: ChromeMutatorTestSupport.barID,
            position: 0
        )
        let child = try ChromeMutatorTestSupport.logicalFolder(
            id: 80,
            parent: parent.logicalNodeID
        )
        let grandchild = try ChromeMutatorTestSupport.logicalFolder(
            id: 70,
            parent: child.logicalNodeID
        )
        let bookmark = try ChromeMutatorTestSupport.logicalBookmark(
            id: 60,
            parent: grandchild.logicalNodeID
        )
        let before = [try ChromeMutatorTestSupport.logicalFolder(
            id: 1,
            parent: nil,
            position: 0
        )]
        let plan = try ChromeMutatorTestSupport.plan(
            before: before,
            after: before + [parent, child, grandchild, bookmark]
        )
        let nativeIDs = [
            NativeNodeIdentifier("nested-guid-90"),
            NativeNodeIdentifier("nested-guid-80"),
            NativeNodeIdentifier("nested-guid-70"),
            NativeNodeIdentifier("nested-guid-60"),
        ]
        let provider = SequenceChromeNativeIdentifierProvider(nativeIDs)
        let mutator = ChromeBookmarkMutator(
            sourceID: ChromeMutatorTestSupport.sourceID,
            nativeIdentityRepository: setup.repository,
            nativeIdentifierProvider: provider
        )
        var document = setup.document

        for operation in plan.phases[0].operations {
            let result = try mutator.apply(operation, to: document)
            document = result.document
            ChromeMutatorTestSupport.apply(
                result.nativeIdentityChanges,
                to: setup.repository
            )
        }

        #expect(plan.phases[0].operations.map(\.logicalNodeID) == [
            parent.logicalNodeID,
            child.logicalNodeID,
            grandchild.logicalNodeID,
            bookmark.logicalNodeID,
        ])
        #expect(try ChromeMutatorTestSupport.childIdentifiers(
            of: nativeIDs[0].rawValue,
            in: document
        ) == [nativeIDs[1].rawValue])
        #expect(try ChromeMutatorTestSupport.childIdentifiers(
            of: nativeIDs[1].rawValue,
            in: document
        ) == [nativeIDs[2].rawValue])
        #expect(try ChromeMutatorTestSupport.childIdentifiers(
            of: nativeIDs[2].rawValue,
            in: document
        ) == [nativeIDs[3].rawValue])
    }

    @Test("A position-dependent Chrome plan moves before creating")
    func positionDependentMoveThenCreatePlan() throws {
        let setup = try ChromeMutatorTestSupport.setup()
        let other = try ChromeMutatorTestSupport.logicalFolder(
            id: 2,
            parent: nil
        )
        let origin = try ChromeMutatorTestSupport.logicalFolder(
            id: 20,
            parent: other.logicalNodeID
        )
        let destination = try ChromeMutatorTestSupport.logicalFolder(
            id: 21,
            parent: origin.logicalNodeID,
            position: 1
        )
        let movedBefore = try ChromeMutatorTestSupport.logicalBookmark(
            id: 22,
            parent: origin.logicalNodeID
        )
        let movedAfter = try ChromeMutatorTestSupport.logicalBookmark(
            id: 22,
            parent: destination.logicalNodeID
        )
        let created = try ChromeMutatorTestSupport.logicalBookmark(
            id: 30,
            parent: destination.logicalNodeID,
            position: 1
        )
        let before = [other, origin, destination, movedBefore]
        let plan = try ChromeMutatorTestSupport.plan(
            before: before,
            after: [other, origin, destination, movedAfter, created]
        )
        let createdNativeID = NativeNodeIdentifier("position-guid-30")
        let mutator = setup.mutator(
            provider: RecordingNativeIdentifierProvider(
                identifier: createdNativeID
            )
        )
        var document = setup.document

        for operation in plan.operations {
            let result = try mutator.apply(operation, to: document)
            document = result.document
            ChromeMutatorTestSupport.apply(
                result.nativeIdentityChanges,
                to: setup.repository
            )
        }

        #expect(plan.operations.map(\.logicalNodeID) == [
            created.logicalNodeID,
            movedBefore.logicalNodeID,
        ])
        #expect(try ChromeMutatorTestSupport.childIdentifiers(
            of: ChromeMutatorTestSupport.deepFolderGUID,
            in: document
        ) == [
            ChromeMutatorTestSupport.bookmarkCGUID,
            createdNativeID.rawValue,
        ])
    }

    @Test("Create keeps a GUID-less Chrome document GUID-less")
    func createInGUIDlessDocument() throws {
        let setup = try ChromeMutatorTestSupport.guidlessSetup()
        let createdID = ChromeMutatorTestSupport.logicalID(32)
        let provider = RecordingNativeIdentifierProvider(
            identifier: NativeNodeIdentifier("must-not-be-written")
        )

        let result = try setup.mutator(provider: provider).apply(.create(
            CreateNodeOperation(
                logicalNodeID: createdID,
                kind: .folder,
                title: "GUID-less folder",
                url: nil,
                parentID: ChromeMutatorTestSupport.barID,
                position: 0
            )
        ), to: setup.document)

        let node = try #require(ChromeMutatorTestSupport.nodeByChromeID(
            "23",
            in: result.document
        ))
        #expect(node["guid"] == nil)
        #expect(provider.callCount == 0)
        #expect(result.nativeIdentityChanges == [
            .register(
                logicalNodeID: createdID,
                sourceID: ChromeMutatorTestSupport.sourceID,
                nativeIdentifier: NativeNodeIdentifier("id:23")
            ),
        ])
    }

    @Test("Delete returns a deferred removal and leaves the repository unchanged")
    func delete() throws {
        let setup = try ChromeMutatorTestSupport.setup()

        let result = try setup.mutator().apply(.delete(DeleteNodeOperation(
            logicalNodeID: ChromeMutatorTestSupport.bookmarkAID
        )), to: setup.document)

        #expect(ChromeMutatorTestSupport.node(
            ChromeMutatorTestSupport.bookmarkAGUID,
            in: result.document
        ) == nil)
        #expect(result.nativeIdentityChanges == [
            .remove(
                logicalNodeID: ChromeMutatorTestSupport.bookmarkAID,
                sourceID: ChromeMutatorTestSupport.sourceID
            ),
        ])
        #expect(setup.repository.nativeIdentifier(
            for: ChromeMutatorTestSupport.bookmarkAID,
            sourceID: ChromeMutatorTestSupport.sourceID
        ) == NativeNodeIdentifier(
            "guid:\(ChromeMutatorTestSupport.bookmarkAGUID)"
        ))
        #expect(setup.repository.writeCount == 0)
    }

    @Test("Delete accepts an empty folder without recursive behavior")
    func deleteEmptyFolder() throws {
        let setup = try ChromeMutatorTestSupport.setup()

        let result = try setup.mutator().apply(.delete(DeleteNodeOperation(
            logicalNodeID: ChromeMutatorTestSupport.deepFolderID
        )), to: setup.document)

        #expect(ChromeMutatorTestSupport.node(
            ChromeMutatorTestSupport.deepFolderGUID,
            in: result.document
        ) == nil)
        #expect(result.nativeIdentityChanges == [
            .remove(
                logicalNodeID: ChromeMutatorTestSupport.deepFolderID,
                sourceID: ChromeMutatorTestSupport.sourceID
            ),
        ])
        #expect(setup.repository.writeCount == 0)
    }

    @Test("Rename changes only the name and preserves guid and metadata")
    func rename() throws {
        let setup = try ChromeMutatorTestSupport.setup()
        let before = try #require(ChromeMutatorTestSupport.node(
            ChromeMutatorTestSupport.bookmarkAGUID,
            in: setup.document
        ))

        let result = try setup.mutator().apply(.rename(RenameNodeOperation(
            logicalNodeID: ChromeMutatorTestSupport.bookmarkAID,
            title: "Renamed"
        )), to: setup.document)

        let after = try #require(ChromeMutatorTestSupport.node(
            ChromeMutatorTestSupport.bookmarkAGUID,
            in: result.document
        ))
        #expect(after["name"] as? String == "Renamed")
        #expect(after["guid"] as? String == before["guid"] as? String)
        #expect(after["url"] as? String == before["url"] as? String)
        #expect(after["date_added"] as? String == before["date_added"] as? String)
        #expect(after["meta_info"] as? [String: String] == before["meta_info"] as? [String: String])
        #expect(after["unknown_numeric_key"] as? Int == 42)
        #expect(result.nativeIdentityChanges.isEmpty)
    }

    @Test("Move applies the exact destination and preserves the complete node")
    func move() throws {
        let setup = try ChromeMutatorTestSupport.setup()

        let result = try setup.mutator().apply(.move(MoveNodeOperation(
            logicalNodeID: ChromeMutatorTestSupport.bookmarkAID,
            parentID: ChromeMutatorTestSupport.nestedFolderID,
            position: 1
        )), to: setup.document)

        #expect(try ChromeMutatorTestSupport.childIdentifiers(
            of: ChromeMutatorTestSupport.barGUID,
            in: result.document
        ) == [ChromeMutatorTestSupport.bookmarkBGUID])
        #expect(try ChromeMutatorTestSupport.childIdentifiers(
            of: ChromeMutatorTestSupport.nestedFolderGUID,
            in: result.document
        ) == [
            ChromeMutatorTestSupport.bookmarkCGUID,
            ChromeMutatorTestSupport.bookmarkAGUID,
            ChromeMutatorTestSupport.deepFolderGUID,
        ])
        let moved = try #require(ChromeMutatorTestSupport.node(
            ChromeMutatorTestSupport.bookmarkAGUID,
            in: result.document
        ))
        #expect(moved["guid"] as? String == ChromeMutatorTestSupport.bookmarkAGUID)
        #expect(moved["unknown_numeric_key"] as? Int == 42)
        #expect(result.nativeIdentityChanges.isEmpty)
    }

    @Test("Move followed by reorder rebuilds the index from the mutated document")
    func moveAndReorder() throws {
        let setup = try ChromeMutatorTestSupport.setup()
        let mutator = setup.mutator()
        let moved = try mutator.apply(.move(MoveNodeOperation(
            logicalNodeID: ChromeMutatorTestSupport.bookmarkAID,
            parentID: ChromeMutatorTestSupport.nestedFolderID,
            position: 1
        )), to: setup.document)

        let reordered = try mutator.apply(.reorder(ReorderNodeOperation(
            logicalNodeID: ChromeMutatorTestSupport.bookmarkAID,
            position: 0
        )), to: moved.document)

        #expect(try ChromeMutatorTestSupport.childIdentifiers(
            of: ChromeMutatorTestSupport.nestedFolderGUID,
            in: reordered.document
        ) == [
            ChromeMutatorTestSupport.bookmarkAGUID,
            ChromeMutatorTestSupport.bookmarkCGUID,
            ChromeMutatorTestSupport.deepFolderGUID,
        ])
        #expect(reordered.nativeIdentityChanges.isEmpty)
    }

    @Test("Reorder changes only sibling order")
    func reorder() throws {
        let setup = try ChromeMutatorTestSupport.setup()

        let result = try setup.mutator().apply(.reorder(ReorderNodeOperation(
            logicalNodeID: ChromeMutatorTestSupport.bookmarkAID,
            position: 1
        )), to: setup.document)

        #expect(try ChromeMutatorTestSupport.childIdentifiers(
            of: ChromeMutatorTestSupport.barGUID,
            in: result.document
        ) == [
            ChromeMutatorTestSupport.bookmarkBGUID,
            ChromeMutatorTestSupport.bookmarkAGUID,
        ])
        #expect(result.nativeIdentityChanges.isEmpty)
    }

    @Test("Update URL changes only the URL")
    func updateURL() throws {
        let setup = try ChromeMutatorTestSupport.setup()
        let updatedURL = try #require(URL(string: "https://updated.example"))

        let result = try setup.mutator().apply(.updateURL(UpdateURLOperation(
            logicalNodeID: ChromeMutatorTestSupport.bookmarkAID,
            url: updatedURL
        )), to: setup.document)

        let node = try #require(ChromeMutatorTestSupport.node(
            ChromeMutatorTestSupport.bookmarkAGUID,
            in: result.document
        ))
        #expect(node["url"] as? String == updatedURL.absoluteString)
        #expect(node["name"] as? String == "A")
        #expect(node["guid"] as? String == ChromeMutatorTestSupport.bookmarkAGUID)
        #expect(node["meta_info"] != nil)
        #expect(result.nativeIdentityChanges.isEmpty)
    }

    @Test("Archive remains explicitly unsupported")
    func archive() throws {
        let setup = try ChromeMutatorTestSupport.setup()

        #expect(throws: ChromeBookmarkMutationError.unsupportedOperation(
            ChromeMutatorTestSupport.bookmarkAID
        )) {
            _ = try setup.mutator().apply(.archive(ArchiveNodeOperation(
                logicalNodeID: ChromeMutatorTestSupport.bookmarkAID,
                state: .archived
            )), to: setup.document)
        }
    }

    @Test("Checksum is recalculated from the mutated roots")
    func checksum() throws {
        let setup = try ChromeMutatorTestSupport.setup()
        let original = try ChromeMutatorTestSupport.object(from: setup.document)
        let originalChecksum = original["checksum"] as? String

        let result = try setup.mutator().apply(.rename(RenameNodeOperation(
            logicalNodeID: ChromeMutatorTestSupport.bookmarkAID,
            title: "Checksum changed"
        )), to: setup.document)

        let object = try ChromeMutatorTestSupport.object(from: result.document)
        let roots = try #require(object["roots"] as? [String: Any])
        #expect(object["checksum"] as? String == ChromeChecksum.compute(roots: roots))
        #expect(object["checksum"] as? String != originalChecksum)
    }

    @Test("An absent checksum remains absent")
    func absentChecksum() throws {
        let setup = try ChromeMutatorTestSupport.setup(checksum: false)

        let result = try setup.mutator().apply(.rename(RenameNodeOperation(
            logicalNodeID: ChromeMutatorTestSupport.bookmarkAID,
            title: "Renamed"
        )), to: setup.document)

        #expect(try ChromeMutatorTestSupport.object(from: result.document)["checksum"] == nil)
    }

    @Test("Unknown top-level, root and node data retain their JSON values")
    func preservesJSON() throws {
        let setup = try ChromeMutatorTestSupport.setup()

        let result = try setup.mutator().apply(.rename(RenameNodeOperation(
            logicalNodeID: ChromeMutatorTestSupport.bookmarkAID,
            title: "Renamed"
        )), to: setup.document)

        let object = try ChromeMutatorTestSupport.object(from: result.document)
        #expect((object["unknown_root_metadata"] as? [String: Any])?["enabled"] as? Bool == true)
        #expect((object["unknown_root_metadata"] as? [String: Any])?["ratio"] as? Double == 1.5)
        let bar = try #require(try ChromeMutatorTestSupport.roots(in: result.document)["bookmark_bar"] as? [String: Any])
        #expect(bar["unknown_folder_key"] != nil)
        #expect(object["version"] as? Int == 1)
    }

    @Test("Invalid targets and structures fail explicitly", arguments: [
        ChromeMutatorFailure.missingIdentity,
        .missingParent,
        .invalidPosition,
        .movePermanentRoot,
        .rootDestination,
        .cycle,
        .nonEmptyFolder,
        .parentNotFolder,
        .invalidCreate,
        .URLOnFolder,
    ])
    func failures(failure: ChromeMutatorFailure) throws {
        let setup = try ChromeMutatorTestSupport.setup()
        let missingID = ChromeMutatorTestSupport.logicalID(99)

        switch failure {
        case .missingIdentity:
            #expect(throws: ChromeBookmarkMutationError.nativeIdentityMissing(missingID)) {
                _ = try setup.mutator().apply(.delete(DeleteNodeOperation(
                    logicalNodeID: missingID
                )), to: setup.document)
            }
        case .missingParent:
            #expect(throws: ChromeBookmarkMutationError.parentNotFound(missingID)) {
                _ = try setup.mutator().apply(.move(MoveNodeOperation(
                    logicalNodeID: ChromeMutatorTestSupport.bookmarkAID,
                    parentID: missingID,
                    position: 0
                )), to: setup.document)
            }
        case .invalidPosition:
            #expect(throws: ChromeBookmarkMutationError.invalidPosition(99)) {
                _ = try setup.mutator().apply(.reorder(ReorderNodeOperation(
                    logicalNodeID: ChromeMutatorTestSupport.bookmarkAID,
                    position: 99
                )), to: setup.document)
            }
        case .movePermanentRoot:
            #expect(throws: ChromeBookmarkMutationError.cannotMutatePermanentRoot(
                ChromeMutatorTestSupport.barID
            )) {
                _ = try setup.mutator().apply(.move(MoveNodeOperation(
                    logicalNodeID: ChromeMutatorTestSupport.barID,
                    parentID: ChromeMutatorTestSupport.otherID,
                    position: 0
                )), to: setup.document)
            }
        case .rootDestination:
            #expect(throws: ChromeBookmarkMutationError.rootDestinationUnsupported) {
                _ = try setup.mutator().apply(.move(MoveNodeOperation(
                    logicalNodeID: ChromeMutatorTestSupport.bookmarkAID,
                    parentID: nil,
                    position: 0
                )), to: setup.document)
            }
        case .cycle:
            #expect(throws: ChromeBookmarkMutationError.cycleDetected(
                ChromeMutatorTestSupport.nestedFolderID
            )) {
                _ = try setup.mutator().apply(.move(MoveNodeOperation(
                    logicalNodeID: ChromeMutatorTestSupport.nestedFolderID,
                    parentID: ChromeMutatorTestSupport.deepFolderID,
                    position: 0
                )), to: setup.document)
            }
        case .nonEmptyFolder:
            #expect(throws: ChromeBookmarkMutationError.nonEmptyFolder(
                ChromeMutatorTestSupport.nestedFolderID
            )) {
                _ = try setup.mutator().apply(.delete(DeleteNodeOperation(
                    logicalNodeID: ChromeMutatorTestSupport.nestedFolderID
                )), to: setup.document)
            }
        case .parentNotFolder:
            #expect(throws: ChromeBookmarkMutationError.parentIsNotFolder(
                NativeNodeIdentifier(
                    "guid:\(ChromeMutatorTestSupport.bookmarkBGUID)"
                )
            )) {
                _ = try setup.mutator().apply(.move(MoveNodeOperation(
                    logicalNodeID: ChromeMutatorTestSupport.bookmarkAID,
                    parentID: ChromeMutatorTestSupport.bookmarkBID,
                    position: 0
                )), to: setup.document)
            }
        case .invalidCreate:
            let invalidURL = try #require(URL(string: "https://invalid.example"))
            #expect(throws: ChromeBookmarkMutationError.invalidCreateOperation(missingID)) {
                _ = try setup.mutator().apply(.create(CreateNodeOperation(
                    logicalNodeID: missingID,
                    kind: .folder,
                    title: "Invalid",
                    url: invalidURL,
                    parentID: ChromeMutatorTestSupport.barID,
                    position: 0
                )), to: setup.document)
            }
        case .URLOnFolder:
            let invalidURL = try #require(URL(string: "https://invalid.example"))
            #expect(throws: ChromeBookmarkMutationError.URLUpdateRequiresBookmark(
                ChromeMutatorTestSupport.nestedFolderID
            )) {
                _ = try setup.mutator().apply(.updateURL(UpdateURLOperation(
                    logicalNodeID: ChromeMutatorTestSupport.nestedFolderID,
                    url: invalidURL
                )), to: setup.document)
            }
        }
        #expect(setup.repository.writeCount == 0)
    }

    @Test("The identifier provider is never consulted outside Create")
    func providerOnlyForCreate() throws {
        let setup = try ChromeMutatorTestSupport.setup()
        let provider = RecordingNativeIdentifierProvider(identifier: NativeNodeIdentifier("unused"))
        let mutator = setup.mutator(provider: provider)

        _ = try mutator.apply(.rename(RenameNodeOperation(
            logicalNodeID: ChromeMutatorTestSupport.bookmarkAID,
            title: "Renamed"
        )), to: setup.document)
        _ = try mutator.apply(.reorder(ReorderNodeOperation(
            logicalNodeID: ChromeMutatorTestSupport.bookmarkAID,
            position: 1
        )), to: setup.document)

        #expect(provider.callCount == 0)
        #expect(setup.repository.writeCount == 0)
    }

    @Test("Same document, operation and deterministic dependencies produce the same result")
    func deterministic() throws {
        let first = try ChromeMutatorTestSupport.setup()
        let second = try ChromeMutatorTestSupport.setup()
        let createdID = ChromeMutatorTestSupport.logicalID(40)
        let operation = SynchronizationOperation.create(CreateNodeOperation(
            logicalNodeID: createdID,
            kind: .folder,
            title: "Deterministic",
            url: nil,
            parentID: ChromeMutatorTestSupport.barID,
            position: 1
        ))
        let nativeIdentifier = NativeNodeIdentifier("deterministic-guid")

        let firstResult = try first.mutator(provider: RecordingNativeIdentifierProvider(
            identifier: nativeIdentifier
        )).apply(operation, to: first.document)
        let secondResult = try second.mutator(provider: RecordingNativeIdentifierProvider(
            identifier: nativeIdentifier
        )).apply(operation, to: second.document)

        #expect(firstResult == secondResult)
        requireSendable(firstResult)
    }

    @Test(
        "Existing id-fallback nodes support every non-creating mutation without gaining a GUID",
        arguments: ChromeIDFallbackMutation.allCases
    )
    func IDFallbackMutations(mutation: ChromeIDFallbackMutation) throws {
        let setup = try ChromeMutatorTestSupport.idFallbackSetup()
        let operation: SynchronizationOperation
        switch mutation {
        case .rename:
            operation = .rename(RenameNodeOperation(
                logicalNodeID: ChromeMutatorTestSupport.bookmarkAID,
                title: "Fallback renamed"
            ))
        case .move:
            operation = .move(MoveNodeOperation(
                logicalNodeID: ChromeMutatorTestSupport.bookmarkAID,
                parentID: ChromeMutatorTestSupport.otherID,
                position: 1
            ))
        case .delete:
            operation = .delete(DeleteNodeOperation(
                logicalNodeID: ChromeMutatorTestSupport.bookmarkAID
            ))
        case .updateURL:
            operation = .updateURL(UpdateURLOperation(
                logicalNodeID: ChromeMutatorTestSupport.bookmarkAID,
                url: try #require(URL(string: "https://fallback.example"))
            ))
        }

        let result = try setup.mutator().apply(operation, to: setup.document)
        let node = ChromeMutatorTestSupport.nodeByChromeID("10", in: result.document)

        if mutation == .delete {
            #expect(node == nil)
            #expect(result.nativeIdentityChanges == [
                .remove(
                    logicalNodeID: ChromeMutatorTestSupport.bookmarkAID,
                    sourceID: ChromeMutatorTestSupport.sourceID
                ),
            ])
        } else {
            let node = try #require(node)
            #expect(node["guid"] == nil)
            #expect(node["id"] as? String == "10")
            #expect(result.nativeIdentityChanges.isEmpty)
        }
        #expect(setup.repository.writeCount == 0)
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }
}

nonisolated enum ChromeIDFallbackMutation: CaseIterable, Hashable, Sendable {
    case rename
    case move
    case delete
    case updateURL
}

nonisolated enum ChromeMutatorFailure: CaseIterable, Sendable {
    case missingIdentity
    case missingParent
    case invalidPosition
    case movePermanentRoot
    case rootDestination
    case cycle
    case nonEmptyFolder
    case parentNotFolder
    case invalidCreate
    case URLOnFolder
}

nonisolated private final class RecordingNativeIdentityRepository: NativeIdentityRepository {
    private struct State {
        var mappings: [MappingKey: NativeNodeIdentifier]
        var registerCalls = 0
        var removeCalls = 0
    }

    private let state: Mutex<State>

    init(mappings: [NativeIdentityMapping]) {
        state = Mutex(State(mappings: Dictionary(
            uniqueKeysWithValues: mappings.map {
                (MappingKey(logicalNodeID: $0.logicalNodeID, sourceID: $0.sourceID), $0.nativeIdentifier)
            }
        )))
    }

    var writeCount: Int {
        state.withLock { $0.registerCalls + $0.removeCalls }
    }

    func nativeIdentifier(
        for logicalNodeID: LogicalNodeID,
        sourceID: BSESourceID
    ) -> NativeNodeIdentifier? {
        state.withLock { $0.mappings[MappingKey(logicalNodeID: logicalNodeID, sourceID: sourceID)] }
    }

    func logicalNodeID(
        for nativeIdentifier: NativeNodeIdentifier,
        sourceID: BSESourceID
    ) -> LogicalNodeID? {
        state.withLock { state in
            state.mappings.first { key, value in
                key.sourceID == sourceID && value == nativeIdentifier
            }?.key.logicalNodeID
        }
    }

    func register(_ mapping: NativeIdentityMapping) {
        state.withLock {
            $0.registerCalls += 1
            $0.mappings[MappingKey(logicalNodeID: mapping.logicalNodeID, sourceID: mapping.sourceID)] = mapping.nativeIdentifier
        }
    }

    func remove(logicalNodeID: LogicalNodeID, sourceID: BSESourceID) {
        state.withLock {
            $0.removeCalls += 1
            $0.mappings.removeValue(forKey: MappingKey(logicalNodeID: logicalNodeID, sourceID: sourceID))
        }
    }
}

nonisolated private struct MappingKey: Hashable, Sendable {
    let logicalNodeID: LogicalNodeID
    let sourceID: BSESourceID
}

nonisolated private final class RecordingNativeIdentifierProvider: NativeIdentifierProviding {
    private let identifier: NativeNodeIdentifier
    private let calls = Mutex(0)

    init(identifier: NativeNodeIdentifier) {
        self.identifier = identifier
    }

    var callCount: Int { calls.withLock { $0 } }

    func makeIdentifier() throws -> NativeNodeIdentifier {
        calls.withLock { $0 += 1 }
        return identifier
    }
}

nonisolated private final class SequenceChromeNativeIdentifierProvider:
    NativeIdentifierProviding {
    private let identifiers: Mutex<[NativeNodeIdentifier]>

    init(_ identifiers: [NativeNodeIdentifier]) {
        self.identifiers = Mutex(identifiers)
    }

    func makeIdentifier() throws -> NativeNodeIdentifier {
        try identifiers.withLock { identifiers in
            guard !identifiers.isEmpty else {
                throw SequenceChromeNativeIdentifierProviderError.exhausted
            }
            return identifiers.removeFirst()
        }
    }
}

nonisolated private enum SequenceChromeNativeIdentifierProviderError: Error {
    case exhausted
}

nonisolated private enum ChromeMutatorTestSupport {
    static let sourceID = BSESourceID(UUID(uuidString: "00000000-0000-0000-0000-000000000750")!)
    static let barID = logicalID(1)
    static let otherID = logicalID(2)
    static let syncedID = logicalID(3)
    static let bookmarkAID = logicalID(10)
    static let bookmarkBID = logicalID(11)
    static let nestedFolderID = logicalID(20)
    static let deepFolderID = logicalID(21)
    static let bookmarkCID = logicalID(22)

    static let barGUID = "root-guid-1"
    static let otherGUID = "root-guid-2"
    static let syncedGUID = "root-guid-3"
    static let bookmarkAGUID = "bookmark-guid-10"
    static let bookmarkBGUID = "bookmark-guid-11"
    static let nestedFolderGUID = "folder-guid-20"
    static let deepFolderGUID = "folder-guid-21"
    static let bookmarkCGUID = "bookmark-guid-22"

    struct Setup {
        let document: ChromeBookmarkDocument
        let repository: RecordingNativeIdentityRepository

        func mutator(
            provider: RecordingNativeIdentifierProvider = RecordingNativeIdentifierProvider(
                identifier: NativeNodeIdentifier("unused-native")
            )
        ) -> ChromeBookmarkMutator {
            ChromeBookmarkMutator(
                sourceID: sourceID,
                nativeIdentityRepository: repository,
                nativeIdentifierProvider: provider
            )
        }
    }

    static func setup(checksum: Bool = true) throws -> Setup {
        let fixtureObject = makeObject(checksum: checksum)
        let data = try JSONSerialization.data(
            withJSONObject: fixtureObject,
            options: [.sortedKeys]
        )
        let document = try ChromeBookmarkDocument(
            data: data,
            sourceFingerprint: ChromeDocumentFingerprint(
                contentDigest: ChromeDocumentFingerprint.digest(of: data),
                fileSize: UInt64(data.count),
                modificationDate: Date(timeIntervalSinceReferenceDate: 0),
                fileSystemNumber: 1,
                fileNumber: 1
            )
        )
        let mappings = [
            mapping(barID, barGUID), mapping(otherID, otherGUID), mapping(syncedID, syncedGUID),
            mapping(bookmarkAID, bookmarkAGUID), mapping(bookmarkBID, bookmarkBGUID),
            mapping(nestedFolderID, nestedFolderGUID), mapping(deepFolderID, deepFolderGUID),
            mapping(bookmarkCID, bookmarkCGUID),
        ]
        return Setup(
            document: document,
            repository: RecordingNativeIdentityRepository(mappings: mappings)
        )
    }

    static func logicalFolder(
        id: Int,
        parent: LogicalNodeID?,
        position: Int = 0
    ) throws -> LogicalNodeState {
        try LogicalNodeState(
            logicalNodeID: logicalID(id),
            kind: .folder,
            title: "Folder \(id)",
            url: nil,
            parentID: parent,
            position: position,
            lifecycle: .unregistered,
            observations: []
        )
    }

    static func logicalBookmark(
        id: Int,
        parent: LogicalNodeID,
        position: Int = 0
    ) throws -> LogicalNodeState {
        try LogicalNodeState(
            logicalNodeID: logicalID(id),
            kind: .bookmark,
            title: "Bookmark \(id)",
            url: URL(string: "https://nested.example/\(id)"),
            parentID: parent,
            position: position,
            lifecycle: .unregistered,
            observations: []
        )
    }

    static func plan(
        before: [LogicalNodeState],
        after: [LogicalNodeState]
    ) throws -> SynchronizationPlan {
        let report = LogicalStateBuildingReport(
            baselineIdentityCount: 0,
            snapshotCount: 0,
            snapshotNodeCount: 0,
            logicalNodeCount: 0,
            structurallyAvailableNodeCount: 0,
            baselineOnlyNodeCount: 0,
            unregisteredNodeCount: 0,
            observationCount: 0
        )
        let beforeGraph = try LogicalStateGraph(nodes: before, report: report)
        let afterGraph = try LogicalStateGraph(nodes: after, report: report)
        let diff = try LogicalDiffEngine().diff(request: LogicalDiffRequest(
            before: beforeGraph,
            after: afterGraph
        ))
        return try SynchronizationPlanner().plan(
            request: SynchronizationPlanningRequest(
                before: beforeGraph,
                logicalDiff: diff,
                policy: .allChanges(direction: .oneWay(
                    source: BSESourceID(
                        UUID(uuidString: "00000000-0000-0000-0000-000000000751")!
                    ),
                    target: sourceID
                ))
            )
        )
    }

    static func apply(
        _ changes: [NativeIdentityChange],
        to repository: RecordingNativeIdentityRepository
    ) {
        for change in changes {
            switch change {
            case .register(let logicalNodeID, let sourceID, let nativeIdentifier):
                repository.register(NativeIdentityMapping(
                    logicalNodeID: logicalNodeID,
                    sourceID: sourceID,
                    nativeIdentifier: nativeIdentifier
                ))
            case .remove(let logicalNodeID, let sourceID):
                repository.remove(
                    logicalNodeID: logicalNodeID,
                    sourceID: sourceID
                )
            }
        }
    }

    static func idFallbackSetup() throws -> Setup {
        var object = makeObject(checksum: true)
        var roots = object["roots"] as? [String: Any] ?? [:]
        var bar = roots["bookmark_bar"] as? [String: Any] ?? [:]
        var children = bar["children"] as? [[String: Any]] ?? []
        var bookmark = children[0]
        bookmark.removeValue(forKey: "guid")
        children[0] = bookmark
        bar["children"] = children
        roots["bookmark_bar"] = bar
        object["roots"] = roots

        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        let document = try ChromeBookmarkDocument(
            data: data,
            sourceFingerprint: ChromeDocumentFingerprint(
                contentDigest: ChromeDocumentFingerprint.digest(of: data),
                fileSize: UInt64(data.count),
                modificationDate: Date(timeIntervalSinceReferenceDate: 0),
                fileSystemNumber: 1,
                fileNumber: 1
            )
        )
        let mappings = [
            mapping(barID, barGUID), mapping(otherID, otherGUID),
            mapping(syncedID, syncedGUID),
            NativeIdentityMapping(
                logicalNodeID: bookmarkAID,
                sourceID: sourceID,
                nativeIdentifier: NativeNodeIdentifier("id:10")
            ),
            mapping(bookmarkBID, bookmarkBGUID),
            mapping(nestedFolderID, nestedFolderGUID),
            mapping(deepFolderID, deepFolderGUID),
            mapping(bookmarkCID, bookmarkCGUID),
        ]
        return Setup(
            document: document,
            repository: RecordingNativeIdentityRepository(mappings: mappings)
        )
    }

    static func guidlessSetup() throws -> Setup {
        var object = makeObject(checksum: true)
        let roots = object["roots"] as? [String: Any] ?? [:]
        object["roots"] = roots.mapValues {
            removingGUIDs($0 as? [String: Any] ?? [:])
        }

        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
        let document = try ChromeBookmarkDocument(
            data: data,
            sourceFingerprint: ChromeDocumentFingerprint(
                contentDigest: ChromeDocumentFingerprint.digest(of: data),
                fileSize: UInt64(data.count),
                modificationDate: Date(timeIntervalSinceReferenceDate: 0),
                fileSystemNumber: 1,
                fileNumber: 1
            )
        )
        let mappings = [
            idMapping(barID, "1"), idMapping(otherID, "2"),
            idMapping(syncedID, "3"), idMapping(bookmarkAID, "10"),
            idMapping(bookmarkBID, "11"), idMapping(nestedFolderID, "20"),
            idMapping(deepFolderID, "21"), idMapping(bookmarkCID, "22"),
        ]
        return Setup(
            document: document,
            repository: RecordingNativeIdentityRepository(mappings: mappings)
        )
    }

    static func logicalID(_ value: Int) -> LogicalNodeID {
        LogicalNodeID(UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!)
    }

    static func object(from document: ChromeBookmarkDocument) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: document.data) as? [String: Any] ?? [:]
    }

    static func roots(in document: ChromeBookmarkDocument) throws -> [String: Any] {
        (try object(from: document))["roots"] as? [String: Any] ?? [:]
    }

    static func node(_ identifier: String, in document: ChromeBookmarkDocument) -> [String: Any]? {
        guard let roots = try? roots(in: document) else { return nil }
        for value in roots.values {
            if let root = value as? [String: Any], let found = find(identifier, in: root) {
                return found
            }
        }
        return nil
    }

    static func nodeByChromeID(
        _ chromeID: String,
        in document: ChromeBookmarkDocument
    ) -> [String: Any]? {
        guard let roots = try? roots(in: document) else { return nil }
        for value in roots.values {
            if let root = value as? [String: Any],
               let found = findChromeID(chromeID, in: root) {
                return found
            }
        }
        return nil
    }

    static func childIdentifiers(
        of identifier: String,
        in document: ChromeBookmarkDocument
    ) throws -> [String] {
        let targetNode = try #require(Self.node(identifier, in: document))
        let children = try #require(targetNode["children"] as? [[String: Any]])
        return children.map { ($0["guid"] as? String) ?? ($0["id"] as? String) ?? "" }
    }

    private static func makeObject(checksum: Bool) -> [String: Any] {
        let roots: [String: Any] = [
            "bookmark_bar": folder(
                id: "1", GUID: barGUID, name: "Bookmarks Bar",
                children: [bookmark(id: "10", GUID: bookmarkAGUID, name: "A", URL: "https://a.example"),
                           bookmark(id: "11", GUID: bookmarkBGUID, name: "B", URL: "https://b.example")]
            ),
            "other": folder(
                id: "2", GUID: otherGUID, name: "Other Bookmarks",
                children: [folder(
                    id: "20", GUID: nestedFolderGUID, name: "Nested",
                    children: [bookmark(id: "22", GUID: bookmarkCGUID, name: "C", URL: "https://c.example"),
                               folder(id: "21", GUID: deepFolderGUID, name: "Deep", children: [])]
                )]
            ),
            "synced": folder(id: "3", GUID: syncedGUID, name: "Mobile Bookmarks", children: []),
        ]
        var object: [String: Any] = [
            "version": 1,
            "roots": roots,
            "unknown_root_metadata": ["enabled": true, "ratio": 1.5],
        ]
        if checksum { object["checksum"] = ChromeChecksum.compute(roots: roots) }
        return object
    }

    private static func folder(
        id: String,
        GUID: String,
        name: String,
        children: [[String: Any]]
    ) -> [String: Any] {
        [
            "type": "folder", "id": id, "guid": GUID, "name": name,
            "children": children, "date_added": "13200000000000000",
            "date_modified": "13200000000000001",
            "unknown_folder_key": ["nested": true],
        ]
    }

    private static func bookmark(
        id: String,
        GUID: String,
        name: String,
        URL: String
    ) -> [String: Any] {
        [
            "type": "url", "id": id, "guid": GUID, "name": name, "url": URL,
            "date_added": "13200000000000002",
            "meta_info": ["power_bookmark_meta": "opaque"],
            "unknown_numeric_key": 42,
        ]
    }

    private static func mapping(
        _ logicalNodeID: LogicalNodeID,
        _ nativeIdentifier: String
    ) -> NativeIdentityMapping {
        NativeIdentityMapping(
            logicalNodeID: logicalNodeID,
            sourceID: sourceID,
            nativeIdentifier: NativeNodeIdentifier("guid:\(nativeIdentifier)")
        )
    }

    private static func idMapping(
        _ logicalNodeID: LogicalNodeID,
        _ chromeID: String
    ) -> NativeIdentityMapping {
        NativeIdentityMapping(
            logicalNodeID: logicalNodeID,
            sourceID: sourceID,
            nativeIdentifier: NativeNodeIdentifier("id:\(chromeID)")
        )
    }

    private static func removingGUIDs(
        _ node: [String: Any]
    ) -> [String: Any] {
        var result = node
        result.removeValue(forKey: "guid")
        if let children = node["children"] as? [[String: Any]] {
            result["children"] = children.map(removingGUIDs)
        }
        return result
    }

    private static func find(_ identifier: String, in node: [String: Any]) -> [String: Any]? {
        if (node["guid"] as? String) == identifier || (node["id"] as? String) == identifier {
            return node
        }
        for child in (node["children"] as? [[String: Any]]) ?? [] {
            if let found = find(identifier, in: child) { return found }
        }
        return nil
    }

    private static func findChromeID(
        _ chromeID: String,
        in node: [String: Any]
    ) -> [String: Any]? {
        if node["id"] as? String == chromeID { return node }
        for child in (node["children"] as? [[String: Any]]) ?? [] {
            if let found = findChromeID(chromeID, in: child) { return found }
        }
        return nil
    }
}
