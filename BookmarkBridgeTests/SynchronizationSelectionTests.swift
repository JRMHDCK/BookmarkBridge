import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Synchronization selection")
struct SynchronizationSelectionTests {
    @Test("First launch selects every item and starts with folders collapsed")
    @MainActor
    func firstLaunchUsesSafeDefaults() {
        let chrome = Self.source(
            .chrome,
            profile: "Default",
            name: "Chrome",
            seed: "first"
        )
        let root = chrome.tree.roots[0]
        let model = SynchronizationSelectionViewModel(
            preferencesStore: InMemorySynchronizationPreferencesStore()
        )

        model.configure(sources: [chrome])

        #expect(model.sourceIsSelected(chrome))
        #expect(!model.isExpanded(root.id, in: chrome.source.id))
    }

    @Test("Checked items and expanded folders are saved and restored")
    @MainActor
    func savesAndRestoresCompleteTreeState() {
        let chrome = Self.source(
            .chrome,
            profile: "Default",
            name: "Chrome",
            seed: "saved"
        )
        let root = chrome.tree.roots[0]
        let unchecked = root.children[1]
        let store = InMemorySynchronizationPreferencesStore()
        let first = SynchronizationSelectionViewModel(
            preferencesStore: store
        )
        first.configure(sources: [chrome])

        first.toggle(unchecked, in: chrome)
        first.setExpanded(
            true,
            folderID: root.id,
            in: chrome.source.id
        )

        let restored = SynchronizationSelectionViewModel(
            preferencesStore: store
        )
        restored.configure(sources: [chrome])

        #expect(!restored.isSelected(unchecked, in: chrome.source.id))
        #expect(restored.isSelected(root.children[0], in: chrome.source.id))
        #expect(restored.isExpanded(root.id, in: chrome.source.id))
    }

    @Test("Missing folders and bookmarks are ignored during partial restoration")
    @MainActor
    func missingTreeItemsAreIgnored() {
        let chrome = Self.source(
            .chrome,
            profile: "Default",
            name: "Chrome",
            seed: "partial"
        )
        let root = chrome.tree.roots[0]
        let retained = root.children[0]
        var preferences = SynchronizationPreferences()
        preferences.sourceStates["chrome:Default"] = .init(
            selectedNodeIDs: [
                root.id.rawValue,
                retained.id.rawValue,
                "chrome:missing-bookmark",
            ],
            knownNodeIDs: Set(
                ([root.id] + root.children.map(\.id)).map(\.rawValue)
            ).union(["chrome:missing-bookmark"]),
            expandedFolderIDs: [
                root.id.rawValue,
                "chrome:missing-folder",
            ]
        )
        let model = SynchronizationSelectionViewModel(
            preferencesStore: InMemorySynchronizationPreferencesStore(
                preferences: preferences
            )
        )

        model.configure(sources: [chrome])

        #expect(model.isSelected(retained, in: chrome.source.id))
        #expect(!model.isSelected(root.children[1], in: chrome.source.id))
        #expect(model.isExpanded(root.id, in: chrome.source.id))
    }

    @Test("A deleted folder is discarded from restored expansion state")
    @MainActor
    func deletedFolderIsIgnored() {
        let original = Self.source(
            .chrome,
            profile: "Default",
            name: "Chrome",
            seed: "deleted-folder"
        )
        let rootID = original.tree.roots[0].id
        let store = InMemorySynchronizationPreferencesStore()
        let first = SynchronizationSelectionViewModel(
            preferencesStore: store
        )
        first.configure(sources: [original])
        first.setExpanded(true, folderID: rootID, in: original.source.id)

        let withoutFolder = SearchableSource(
            source: original.source,
            tree: BookmarkTree(
                browser: .chrome,
                roots: [],
                capturedAt: .distantPast
            )
        )
        let restored = SynchronizationSelectionViewModel(
            preferencesStore: store
        )

        restored.configure(sources: [withoutFolder])

        #expect(!restored.isExpanded(rootID, in: withoutFolder.source.id))
        #expect(!restored.hasSelection(for: withoutFolder.source.id))
    }

    @Test("Selection remains compatible when synchronization changes the tree")
    @MainActor
    func restoresAfterSynchronizationChangesIdentifiers() {
        let original = Self.source(
            .chrome,
            profile: "Default",
            name: "Chrome",
            seed: "sync"
        )
        let originalRoot = original.tree.roots[0]
        let removed = originalRoot.children[1]
        let store = InMemorySynchronizationPreferencesStore()
        let first = SynchronizationSelectionViewModel(
            preferencesStore: store
        )
        first.configure(sources: [original])
        first.toggle(removed, in: original)
        first.setExpanded(
            true,
            folderID: originalRoot.id,
            in: original.source.id
        )

        let created = BookmarkNode.bookmark(Bookmark(
            id: BookmarkID("chrome:created-by-sync"),
            title: "Created",
            url: URL(string: "https://created-by-sync.example")!
        ))
        let updatedRoot = BookmarkFolder(
            id: originalRoot.id,
            title: originalRoot.title,
            children: [originalRoot.children[0], created]
        )
        let updated = SearchableSource(
            source: original.source,
            tree: BookmarkTree(
                browser: .chrome,
                roots: [updatedRoot],
                capturedAt: .distantPast
            )
        )
        let restored = SynchronizationSelectionViewModel(
            preferencesStore: store
        )

        restored.configure(sources: [updated])

        #expect(restored.isSelected(created, in: updated.source.id))
        #expect(restored.isExpanded(updatedRoot.id, in: updated.source.id))
        #expect(restored.scope(for: updated.source.id) == .all)
    }

    @Test("All profiles and descendants start selected and profile toggles are independent")
    @MainActor
    func profileSelectionAndSessionPersistence() {
        let safari = Self.source(.safari, profile: nil, name: "Safari", seed: "s")
        let chromeDefault = Self.source(.chrome, profile: "Default", name: "Chrome — Default", seed: "c1")
        let chromeWork = Self.source(.chrome, profile: "Profile 1", name: "Chrome — Travail", seed: "c2")
        let model = SynchronizationSelectionViewModel()

        model.configure(sources: [safari, chromeDefault, chromeWork])
        #expect(model.sourceIsSelected(safari))
        #expect(model.sourceIsSelected(chromeDefault))
        #expect(model.sourceIsSelected(chromeWork))

        model.toggleSource(chromeDefault)
        #expect(!model.sourceIsSelected(chromeDefault))
        #expect(model.sourceIsSelected(chromeWork))

        model.configure(sources: [safari, chromeDefault, chromeWork])
        #expect(!model.sourceIsSelected(chromeDefault))
        #expect(model.sourceIsSelected(chromeWork))
    }

    @Test("Folder toggle cascades and an individual bookmark remains selectable")
    @MainActor
    func hierarchicalSelection() {
        let chrome = Self.source(.chrome, profile: "Default", name: "Chrome", seed: "c")
        let model = SynchronizationSelectionViewModel()
        model.configure(sources: [chrome])
        let root = BookmarkNode.folder(chrome.tree.roots[0])
        let bookmark = chrome.tree.roots[0].children[0]

        model.toggle(root, in: chrome)
        #expect(!model.isSelected(root, in: chrome.source.id))
        #expect(!model.isSelected(bookmark, in: chrome.source.id))

        model.toggle(bookmark, in: chrome)
        #expect(model.isSelected(bookmark, in: chrome.source.id))
        #expect(model.isSelected(root, in: chrome.source.id))
        #expect(model.isPartiallySelected(root, in: chrome.source.id))
        #expect(model.scope(for: chrome.source.id) != .all)
    }

    @Test("Reader removes unchecked nodes before BSE and retains their ancestors")
    func readerFiltersBeforePipeline() async throws {
        let sourceID = BSESourceID(UUID(uuidString: "10000000-0000-0000-0000-000000000001")!)
        let rootID = logicalID(1)
        let folderID = logicalID(2)
        let keptID = logicalID(3)
        let ignoredID = logicalID(4)
        let nodes = [
            try BSENode(logicalID: rootID, kind: .folder, permanentRootRole: .primaryBookmarks, title: "Root", position: 0),
            try BSENode(logicalID: folderID, kind: .folder, title: "Folder", parentID: rootID, position: 0),
            try BSENode(logicalID: keptID, kind: .bookmark, title: "Keep", parentID: folderID, position: 1, url: URL(string: "https://keep.example")!),
            try BSENode(logicalID: ignoredID, kind: .bookmark, title: "Ignore", parentID: folderID, position: 3, url: URL(string: "https://ignore.example")!),
        ]
        let observations = [
            observation(sourceID, rootID, "root"),
            observation(sourceID, folderID, "folder"),
            observation(sourceID, keptID, "keep"),
            observation(sourceID, ignoredID, "ignore"),
        ]
        let reader = SelectionScopedSynchronizationReader(
            reader: SelectionReader(
                result: EndToEndSynchronizationReadResult(
                    snapshot: BSESnapshot(source: sourceID, capturedAt: .distantPast, tree: try BSETree(nodes: nodes)),
                    nativeIdentityObservations: observations
                )
            ),
            selection: .nativeIdentifiers(
                ["keep", "ignore"],
                includingSemanticKeys: [],
                excludingSemanticKeys: ["bookmark:https://ignore.example"]
            )
        )

        let result = try await reader.readForSynchronization()

        #expect(result.snapshot.tree.nodes.map(\.logicalID) == [rootID, folderID, keptID])
        #expect(result.snapshot.tree.node(for: keptID)?.position == 0)
        #expect(result.nativeIdentityObservations.map(\.nativeIdentifier.rawValue) == ["root", "folder", "keep"])
    }

    @Test("Reader retains a selected node after its native identifier changes")
    func readerRetainsNewTargetIdentifierAfterWrite() async throws {
        let sourceID = BSESourceID(
            UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
        )
        let rootID = logicalID(10)
        let createdID = logicalID(11)
        let nodes = [
            try BSENode(
                logicalID: rootID,
                kind: .folder,
                permanentRootRole: .primaryBookmarks,
                title: "Root",
                position: 0
            ),
            try BSENode(
                logicalID: createdID,
                kind: .bookmark,
                title: "Created",
                parentID: rootID,
                position: 0,
                url: URL(string: "https://created.example")!
            ),
        ]
        let reader = SelectionScopedSynchronizationReader(
            reader: SelectionReader(result: EndToEndSynchronizationReadResult(
                snapshot: BSESnapshot(
                    source: sourceID,
                    capturedAt: .distantPast,
                    tree: try BSETree(nodes: nodes)
                ),
                nativeIdentityObservations: [
                    observation(sourceID, rootID, "root"),
                    observation(sourceID, createdID, "generated-after-write"),
                ]
            )),
            selection: .nativeIdentifiers(
                ["root"],
                includingSemanticKeys: [
                    "bookmark:https://created.example",
                ],
                excludingSemanticKeys: []
            )
        )

        let result = try await reader.readForSynchronization()

        #expect(result.snapshot.tree.nodes.map(\.logicalID) == [rootID, createdID])
        #expect(
            result.nativeIdentityObservations.map(\.nativeIdentifier.rawValue)
                == ["root", "generated-after-write"]
        )
    }

    @Test("An exclusion wins over identifiers and semantic inclusion")
    func excludedNodeNeverEntersThePipeline() async throws {
        let sourceID = BSESourceID(
            UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
        )
        let rootID = logicalID(20)
        let excludedID = logicalID(21)
        let nodes = [
            try BSENode(
                logicalID: rootID,
                kind: .folder,
                permanentRootRole: .primaryBookmarks,
                title: "Root",
                position: 0
            ),
            try BSENode(
                logicalID: excludedID,
                kind: .bookmark,
                title: "Unchecked",
                parentID: rootID,
                position: 0,
                url: URL(string: "https://unchecked.example")!
            ),
        ]
        let key = "bookmark:https://unchecked.example"
        let reader = SelectionScopedSynchronizationReader(
            reader: SelectionReader(result: EndToEndSynchronizationReadResult(
                snapshot: BSESnapshot(
                    source: sourceID,
                    capturedAt: .distantPast,
                    tree: try BSETree(nodes: nodes)
                ),
                nativeIdentityObservations: [
                    observation(sourceID, rootID, "root"),
                    observation(sourceID, excludedID, "unchecked"),
                ]
            )),
            selection: .nativeIdentifiers(
                ["root", "unchecked"],
                includingSemanticKeys: [key],
                excludingSemanticKeys: [key]
            )
        )

        let result = try await reader.readForSynchronization()

        #expect(result.snapshot.tree.nodes.map(\.logicalID) == [rootID])
        #expect(
            result.nativeIdentityObservations.map(\.nativeIdentifier.rawValue)
                == ["root"]
        )
    }

    private static func source(
        _ browser: Browser,
        profile: String?,
        name: String,
        seed: String
    ) -> SearchableSource {
        let bookmark = Bookmark(
            id: BookmarkID("\(browser == .chrome ? "chrome:" : "")\(seed)-bookmark"),
            title: "Example",
            url: URL(string: "https://\(seed).example")!
        )
        let otherBookmark = Bookmark(
            id: BookmarkID("\(browser == .chrome ? "chrome:" : "")\(seed)-other"),
            title: "Other",
            url: URL(string: "https://other-\(seed).example")!
        )
        let root = BookmarkFolder(
            id: BookmarkID("\(browser == .chrome ? "chrome:" : "")\(seed)-root"),
            title: "Root",
            children: [.bookmark(bookmark), .bookmark(otherBookmark)]
        )
        return SearchableSource(
            source: BookmarkSource(browser: browser, profile: profile, displayName: name),
            tree: BookmarkTree(browser: browser, roots: [root], capturedAt: .distantPast)
        )
    }

    private func logicalID(_ value: Int) -> LogicalNodeID {
        LogicalNodeID(UUID(uuidString: String(format: "20000000-0000-0000-0000-%012d", value))!)
    }

    private func observation(
        _ sourceID: BSESourceID,
        _ logicalID: LogicalNodeID,
        _ nativeID: String
    ) -> NativeIdentityObservation {
        NativeIdentityObservation(
            sourceID: sourceID,
            provisionalLogicalNodeID: logicalID,
            nativeIdentifier: NativeNodeIdentifier(nativeID)
        )
    }
}

private struct SelectionReader: EndToEndSynchronizationReading {
    let result: EndToEndSynchronizationReadResult
    var sourceID: BSESourceID { result.snapshot.source }

    func readForSynchronization() async throws -> EndToEndSynchronizationReadResult {
        result
    }
}
