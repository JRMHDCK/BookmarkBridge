//
//  BSESafariAdapterTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Safari Adapter")
struct BSESafariAdapterTests {
    private func sourceID(_ value: Int = 1) throws -> BSESourceID {
        let string = String(format: "83000000-0000-0000-0000-%012d", value)
        return BSESourceID(try #require(UUID(uuidString: string)))
    }

    private func logicalID(_ value: Int) throws -> LogicalNodeID {
        let string = String(format: "84000000-0000-0000-0000-%012d", value)
        return LogicalNodeID(try #require(UUID(uuidString: string)))
    }

    private func path(_ positions: Int...) -> SafariRecordPath {
        SafariRecordPath(positions)
    }

    private func bookmark(
        id: String? = "bookmark-1",
        title: String? = "Bookmark",
        url: String? = "https://example.com",
        position: Int = 0,
        path: SafariRecordPath = SafariRecordPath([0, 0])
    ) -> SafariRecord {
        .bookmark(SafariBookmarkRecord(
            nativeIdentifier: id,
            title: title,
            urlString: url,
            position: position,
            path: path
        ))
    }

    private func folder(
        id: String? = "folder-1",
        permanentRootRole: PermanentRootRole? = nil,
        title: String? = "Folder",
        position: Int = 0,
        path: SafariRecordPath = SafariRecordPath([0]),
        children: [SafariRecord] = []
    ) -> SafariRecord {
        .folder(SafariFolderRecord(
            nativeIdentifier: id,
            permanentRootRole: permanentRootRole,
            title: title,
            position: position,
            path: path,
            children: children
        ))
    }

    private func extraction(
        records: [SafariRecord],
        issues: [SafariReadIssue] = [],
        safariVersion: String? = "18.5",
        storageVersion: String? = "1"
    ) -> SafariExtraction {
        SafariExtraction(
            records: records,
            capturedAt: Date(timeIntervalSince1970: 1_760_000_000),
            safariVersion: safariVersion,
            storageVersion: storageVersion,
            issues: issues
        )
    }

    private func adapter(
        extraction: SafariExtraction,
        adapterSourceID: BSESourceID? = nil,
        error: SafariReadError? = nil,
        permission: BSEAdapterPermissionStatus = BSEAdapterPermissionStatus(state: .granted),
        compatibility: BSEAdapterCompatibility = BSEAdapterCompatibility(state: .supported),
        monotonicTime: @escaping @Sendable () -> TimeInterval = { 10 }
    ) throws -> (SafariAdapter, TestSafariDataSource) {
        let dataSource = TestSafariDataSource(
            extraction: extraction,
            error: error,
            permission: permission,
            compatibility: compatibility
        )
        return (
            SafariAdapter(
                sourceID: try adapterSourceID ?? sourceID(),
                dataSource: dataSource,
                monotonicTime: monotonicTime
            ),
            dataSource
        )
    }

    private func simpleExtraction() -> SafariExtraction {
        extraction(records: [
            folder(children: [bookmark()]),
        ])
    }

    // MARK: - Pure hierarchy transformation

    @Test("Reads a simple folder and bookmark tree")
    func simpleTree() async throws {
        let (adapter, _) = try adapter(extraction: simpleExtraction())

        let snapshot = try await adapter.readSnapshot()

        let root = try #require(snapshot.tree.roots.first?.node)
        #expect(root.kind == .folder)
        #expect(root.title == "Folder")
        let child = try #require(snapshot.tree.children(of: root.logicalID).first)
        #expect(child.kind == .bookmark)
        #expect(child.title == "Bookmark")
        #expect(child.url == URL(string: "https://example.com"))
    }

    @Test("Safari transformation preserves only explicitly declared permanent-root roles")
    func permanentRootRoles() async throws {
        let source = extraction(records: [
            folder(
                id: "bar",
                permanentRootRole: .primaryBookmarks,
                title: "Favorites",
                position: 0,
                path: path(0)
            ),
            folder(
                id: "menu",
                permanentRootRole: .secondaryBookmarks,
                title: "Bookmarks Menu",
                position: 1,
                path: path(1)
            ),
            folder(
                id: "reading",
                permanentRootRole: .readingList,
                title: "Reading List",
                position: 2,
                path: path(2)
            ),
            folder(
                id: "ordinary",
                title: "User Folder",
                position: 3,
                path: path(3)
            ),
        ])

        let snapshot = try await adapter(extraction: source).0.readSnapshot()

        #expect(snapshot.tree.roots.map(\.node.permanentRootRole) == [
            .primaryBookmarks, .secondaryBookmarks, .readingList, nil,
        ])
    }

    @Test("One coherent Safari read carries one ordered native observation per node")
    func nativeIdentityObservations() async throws {
        let expectedSourceID = try sourceID()
        let (adapter, dataSource) = try adapter(
            extraction: simpleExtraction(),
            adapterSourceID: expectedSourceID
        )

        let result = try await adapter.read()

        #expect(await dataSource.extractionCount() == 1)
        #expect(result.nativeIdentityObservations.count == result.snapshot.tree.count)
        #expect(result.nativeIdentityObservations.map(\.provisionalLogicalNodeID)
            == result.snapshot.tree.nodes.map(\.logicalID))
        #expect(result.nativeIdentityObservations.map(\.nativeIdentifier) == [
            NativeNodeIdentifier("folder-1"),
            NativeNodeIdentifier("bookmark-1"),
        ])
        #expect(result.nativeIdentityObservations.allSatisfy {
            $0.sourceID == expectedSourceID
        })
    }

    @Test("Empty and repeated Safari transformations preserve snapshot behavior")
    func nativeIdentityObservationDeterminism() async throws {
        let empty = try adapter(extraction: extraction(records: [])).0
        let first = try adapter(extraction: simpleExtraction()).0
        let second = try adapter(extraction: simpleExtraction()).0

        let emptyResult = try await empty.read()
        let firstResult = try await first.read()
        let secondResult = try await second.read()

        #expect(emptyResult.snapshot.tree.isEmpty)
        #expect(emptyResult.nativeIdentityObservations.isEmpty)
        #expect(firstResult.snapshot == secondResult.snapshot)
        #expect(firstResult.nativeIdentityObservations
            == secondResult.nativeIdentityObservations)
    }

    @Test("Preserves multiple folders and their source order")
    func multipleFolders() async throws {
        let source = extraction(records: [
            folder(id: "first", title: "First", position: 0, path: path(0)),
            folder(id: "second", title: "Second", position: 1, path: path(1)),
            folder(id: "third", title: "Third", position: 2, path: path(2)),
        ])
        let (adapter, _) = try adapter(extraction: source)

        let snapshot = try await adapter.readSnapshot()

        #expect(snapshot.tree.roots.map(\.node.title) == ["First", "Second", "Third"])
        #expect(snapshot.tree.roots.map(\.node.position) == [0, 1, 2])
    }

    @Test("Preserves nested folders and bookmark parent relationships")
    func nestedFolders() async throws {
        let nestedBookmark = bookmark(
            id: "deep-bookmark",
            title: "Deep",
            position: 0,
            path: path(0, 0, 0)
        )
        let nestedFolder = folder(
            id: "nested-folder",
            title: "Nested",
            position: 0,
            path: path(0, 0),
            children: [nestedBookmark]
        )
        let rootFolder = folder(children: [nestedFolder])
        let (adapter, _) = try adapter(extraction: extraction(records: [rootFolder]))

        let snapshot = try await adapter.readSnapshot()

        let root = try #require(snapshot.tree.roots.first?.node)
        let nested = try #require(snapshot.tree.children(of: root.logicalID).first)
        let deep = try #require(snapshot.tree.children(of: nested.logicalID).first)
        #expect(nested.title == "Nested")
        #expect(deep.title == "Deep")
        #expect(deep.parentID == nested.logicalID)
    }

    @Test("Preserves exact mixed sibling order")
    func siblingOrder() async throws {
        let children: [SafariRecord] = [
            bookmark(id: "a", title: "A", position: 0, path: path(0, 0)),
            folder(id: "empty", title: "Empty", position: 1, path: path(0, 1)),
            bookmark(id: "b", title: "B", position: 2, path: path(0, 2)),
        ]
        let (adapter, _) = try adapter(extraction: extraction(records: [
            folder(children: children),
        ]))

        let snapshot = try await adapter.readSnapshot()
        let root = try #require(snapshot.tree.roots.first?.node)

        #expect(snapshot.tree.children(of: root.logicalID).map(\.title) == ["A", "Empty", "B"])
        #expect(snapshot.tree.children(of: root.logicalID).map(\.position) == [0, 1, 2])
    }

    @Test("Preserves an empty folder")
    func emptyFolder() async throws {
        let (adapter, _) = try adapter(extraction: extraction(records: [folder()]))

        let snapshot = try await adapter.readSnapshot()
        let root = try #require(snapshot.tree.roots.first?.node)

        #expect(snapshot.tree.children(of: root.logicalID).isEmpty)
        #expect(snapshot.tree.count == 1)
    }

    // MARK: - Local issues

    @Test("Preserves an empty title and reports it")
    func emptyTitle() async throws {
        let emptyTitle = bookmark(title: "")
        let (adapter, _) = try adapter(extraction: extraction(records: [
            folder(children: [emptyTitle]),
        ]))

        let result = try await adapter.read()

        let bookmarkNode = try #require(result.snapshot.tree.nodes.first { $0.kind == .bookmark })
        #expect(bookmarkNode.title == "")
        #expect(result.issues == [.missingTitle(path: path(0, 0))])
    }

    @Test("Reports and omits an empty URL without losing valid siblings")
    func emptyURL() async throws {
        let children = [
            bookmark(id: "broken", title: "Broken", url: "", position: 0, path: path(0, 0)),
            bookmark(id: "valid", title: "Valid", position: 1, path: path(0, 1)),
        ]
        let (adapter, _) = try adapter(extraction: extraction(records: [folder(children: children)]))

        let result = try await adapter.read()

        #expect(result.snapshot.tree.nodes.filter { $0.kind == .bookmark }.map(\.title) == ["Valid"])
        #expect(result.snapshot.tree.nodes.first { $0.title == "Valid" }?.position == 0)
        #expect(result.issues == [.missingURL(path: path(0, 0))])
    }

    @Test("Reports and omits an invalid URL without inventing a correction")
    func invalidURL() async throws {
        let invalid = bookmark(url: "not a URL")
        let (adapter, _) = try adapter(extraction: extraction(records: [
            folder(children: [invalid]),
        ]))

        let result = try await adapter.read()

        #expect(result.snapshot.tree.nodes.filter { $0.kind == .bookmark }.isEmpty)
        #expect(result.issues == [.invalidURL(path: path(0, 0))])
    }

    @Test("Retains extraction issues beside transformation issues")
    func localIssuesAccumulateDeterministically() async throws {
        let sourceIssue = SafariReadIssue.unknownNodeType(path: path(0, 0))
        let missingTitle = bookmark(id: "missing-title", title: nil)
        let (adapter, _) = try adapter(extraction: extraction(
            records: [folder(children: [missingTitle])],
            issues: [sourceIssue]
        ))

        let result = try await adapter.read()

        #expect(result.issues == [sourceIssue, .missingTitle(path: path(0, 0))])
        #expect(result.report.issuesCount == 2)
    }

    @Test("Reports a duplicate native identifier instead of corrupting the tree")
    func duplicateNativeIdentifier() async throws {
        let children = [
            bookmark(id: "duplicate", title: "First", position: 0, path: path(0, 0)),
            bookmark(id: "duplicate", title: "Second", position: 1, path: path(0, 1)),
        ]
        let (adapter, _) = try adapter(extraction: extraction(records: [folder(children: children)]))

        let result = try await adapter.read()

        #expect(result.snapshot.tree.nodes.filter { $0.kind == .bookmark }.map(\.title) == ["First"])
        #expect(result.issues == [.duplicateNativeIdentifier(path: path(0, 1))])
    }

    // MARK: - Determinism and isolation

    @Test("Provisional snapshot identifiers repeat for identical Safari reads")
    func provisionalIdentifiersAreStableForIdenticalReads() async throws {
        let source = simpleExtraction()
        let (firstAdapter, _) = try adapter(extraction: source)
        let (secondAdapter, _) = try adapter(extraction: source)

        let first = try await firstAdapter.readSnapshot()
        let second = try await secondAdapter.readSnapshot()

        // Repetition makes Safari reads deterministic. It does not promote these
        // snapshot-local keys to persisted or cross-browser BSE identity.
        #expect(first == second)
        #expect(first.tree.nodes.map(\.logicalID) == second.tree.nodes.map(\.logicalID))
    }

    @Test("Provisional identifiers are source-scoped, not global BSE identity")
    func provisionalIdentifiersAreNotGlobalIdentity() async throws {
        let source = simpleExtraction()
        let (firstAdapter, _) = try adapter(
            extraction: source,
            adapterSourceID: sourceID(1)
        )
        let (secondAdapter, _) = try adapter(
            extraction: source,
            adapterSourceID: sourceID(2)
        )

        let first = try await firstAdapter.readSnapshot()
        let second = try await secondAdapter.readSnapshot()

        // The same native records under another source yield different keys.
        // Matching Safari with Chrome must therefore use the future persisted
        // BSE identity layer, never equality of these provisional identifiers.
        #expect(first.tree.nodes.map(\.title) == second.tree.nodes.map(\.title))
        #expect(first.tree.nodes.map(\.logicalID) != second.tree.nodes.map(\.logicalID))
    }

    @Test("Reading never mutates the injected source")
    func sourceIsNotMutated() async throws {
        let source = simpleExtraction()
        let (adapter, dataSource) = try adapter(extraction: source)
        let before = await dataSource.currentExtraction()

        _ = try await adapter.readSnapshot()

        #expect(await dataSource.currentExtraction() == before)
        #expect(await dataSource.extractionCount() == 1)
    }

    @Test("Native Safari identifiers never appear in the BSE snapshot")
    func nativeIdentifiersStayPrivate() async throws {
        let nativeIdentifier = "private-safari-native-identifier"
        let source = extraction(records: [folder(
            id: nativeIdentifier,
            children: [bookmark(id: "private-bookmark-identifier")]
        )])
        let (adapter, _) = try adapter(extraction: source)

        let snapshot = try await adapter.readSnapshot()
        let encoded = try JSONEncoder().encode(snapshot)
        let json = String(decoding: encoded, as: UTF8.self)

        #expect(!json.contains(nativeIdentifier))
        #expect(!json.contains("private-bookmark-identifier"))
    }

    @Test("A global source error fails readSnapshot explicitly")
    func globalError() async throws {
        let (adapter, _) = try adapter(
            extraction: simpleExtraction(),
            error: .storageCorrupted
        )

        await #expect(throws: SafariReadError.storageCorrupted) {
            _ = try await adapter.readSnapshot()
        }
    }

    // MARK: - Universal adapter contract

    @Test("Capabilities are strictly read-only")
    func capabilities() async throws {
        let (adapter, _) = try adapter(extraction: simpleExtraction())

        #expect(adapter.capabilities.canRead)
        #expect(!adapter.capabilities.canWrite)
        #expect(!adapter.capabilities.canCreate)
        #expect(!adapter.capabilities.canDelete)
        #expect(!adapter.capabilities.canMove)
        #expect(!adapter.capabilities.canRename)
        #expect(!adapter.capabilities.canVerify)
        #expect(!adapter.capabilities.canCreateRestorePoint)
        #expect(!adapter.capabilities.canRestore)
    }

    @Test("Permission and compatibility observations are delegated")
    func sourceObservations() async throws {
        let denied = BSEAdapterPermissionStatus(state: .denied)
        let untested = BSEAdapterCompatibility(state: .untested)
        let (adapter, _) = try adapter(
            extraction: simpleExtraction(),
            permission: denied,
            compatibility: untested
        )

        #expect(await adapter.checkPermissions() == denied)
        #expect(await adapter.checkCompatibility() == untested)
    }

    @Test("Execute is always rejected before writing")
    func executeIsUnsupported() async throws {
        let (adapter, dataSource) = try adapter(extraction: simpleExtraction())

        await #expect(throws: BSEAdapterError.unsupportedCapability(.write)) {
            _ = try await adapter.execute(executionStep())
        }
        #expect(await dataSource.extractionCount() == 0)
    }

    @Test("Verification is unsupported and performs no source read")
    func verificationIsUnsupported() async throws {
        let (adapter, dataSource) = try adapter(extraction: simpleExtraction())

        #expect(try await adapter.verify(executionStep()) == .unsupported)
        #expect(await dataSource.extractionCount() == 0)
    }

    @Test("Restore-point creation and restoration are unsupported")
    func restorationIsUnsupported() async throws {
        let (adapter, dataSource) = try adapter(extraction: simpleExtraction())
        let restorePoint = BSEAdapterRestorePoint(
            restorePointID: BSEAdapterRestorePointID(
                try #require(UUID(uuidString: "85000000-0000-0000-0000-000000000001"))
            ),
            sourceID: adapter.sourceID
        )

        await #expect(throws: BSEAdapterError.unsupportedCapability(.createRestorePoint)) {
            _ = try await adapter.createRestorePoint()
        }
        await #expect(throws: BSEAdapterError.unsupportedCapability(.restore)) {
            try await adapter.restore(from: restorePoint)
        }
        #expect(await dataSource.extractionCount() == 0)
    }

    @Test("Read report is separate and contains deterministic diagnostics")
    func readReport() async throws {
        let clock = TestMonotonicTime(values: [20, 20.25])
        let (adapter, _) = try adapter(
            extraction: simpleExtraction(),
            monotonicTime: { clock.next() }
        )

        let result = try await adapter.read()

        #expect(result.report.foldersRead == 1)
        #expect(result.report.bookmarksRead == 1)
        #expect(result.report.issuesCount == 0)
        #expect(result.report.duration == 0.25)
        #expect(result.report.safariVersion == "18.5")
        #expect(result.report.storageVersion == "1")
        #expect(result.snapshot.tree.count == 2)
    }

    // MARK: - Default extraction

    @Test("Default data source extracts native records without BSE conversion")
    func defaultExtractionIsSeparatedFromTransformation() async throws {
        let data = try propertyListData(children: [
            ["WebBookmarkType": "FutureNode"],
            folderDictionary(
                id: "native-folder",
                title: "Folder",
                nativeRoleIdentifier: "BookmarksBar",
                children: [bookmarkDictionary(id: "native-bookmark")]
            ),
        ])
        let fingerprint = SafariStorageFingerprint(
            modificationDate: Date(timeIntervalSince1970: 1_760_000_000),
            fileSize: data.count
        )
        let dataSource = defaultDataSource(
            data: data,
            fingerprint: { fingerprint }
        )

        let extracted = try await dataSource.extract()

        #expect(extracted.records.count == 1)
        #expect(extracted.issues == [.unknownNodeType(path: path(0))])
        #expect(extracted.safariVersion == "18.5-test")
        #expect(extracted.storageVersion == "1")

        let transformed = try SafariSnapshotTransformer().transform(
            extracted,
            sourceID: sourceID()
        )
        #expect(transformed.snapshot.tree.count == 2)
        #expect(transformed.snapshot.tree.roots.first?.node.permanentRootRole
            == .primaryBookmarks)
        #expect(transformed.snapshot.tree.roots.first?.node.position == 0)
    }

    @Test("Current Safari root titles identify permanent roots without legacy identifiers")
    func permanentRootTitleFallback() async throws {
        let data = try propertyListData(children: [
            folderDictionary(
                id: "bar",
                title: "BookmarksBar",
                children: []
            ),
            folderDictionary(
                id: "menu",
                title: "BookmarksMenu",
                children: []
            ),
            folderDictionary(
                id: "reading",
                title: "com.apple.ReadingList",
                children: []
            ),
        ])
        let fingerprint = SafariStorageFingerprint(
            modificationDate: Date(timeIntervalSince1970: 1_760_000_000),
            fileSize: data.count
        )

        let extraction = try await defaultDataSource(
            data: data,
            fingerprint: { fingerprint }
        ).extract()
        let transformed = try SafariSnapshotTransformer().transform(
            extraction,
            sourceID: sourceID()
        )

        #expect(transformed.snapshot.tree.roots.map(\.node.permanentRootRole) == [
            .primaryBookmarks,
            .secondaryBookmarks,
            .readingList,
        ])
    }

    @Test("Default data source detects a source changing during read")
    func coherentReadIsRequired() async throws {
        let data = try propertyListData(children: [])
        let fingerprints = TestFingerprintSequence(values: [
            SafariStorageFingerprint(
                modificationDate: Date(timeIntervalSince1970: 1),
                fileSize: data.count
            ),
            SafariStorageFingerprint(
                modificationDate: Date(timeIntervalSince1970: 2),
                fileSize: data.count + 1
            ),
        ])
        let dataSource = defaultDataSource(
            data: data,
            fingerprint: { try await fingerprints.next() }
        )

        await #expect(throws: SafariReadError.snapshotInconsistent) {
            _ = try await dataSource.extract()
        }
    }

    @Test("Default data source rejects corrupted storage globally")
    func corruptedStorage() async throws {
        let data = Data("not a property list".utf8)
        let fingerprint = SafariStorageFingerprint(
            modificationDate: Date(timeIntervalSince1970: 1),
            fileSize: data.count
        )
        let dataSource = defaultDataSource(
            data: data,
            fingerprint: { fingerprint }
        )

        await #expect(throws: SafariReadError.storageCorrupted) {
            _ = try await dataSource.extract()
        }
    }

    @Test("Default data source rejects an unsupported storage version")
    func unsupportedStorageVersion() async throws {
        let data = try propertyListData(storageVersion: 99, children: [])
        let fingerprint = SafariStorageFingerprint(
            modificationDate: Date(timeIntervalSince1970: 1),
            fileSize: data.count
        )
        let dataSource = defaultDataSource(
            data: data,
            fingerprint: { fingerprint }
        )

        await #expect(throws: SafariReadError.unsupportedStorageVersion("99")) {
            _ = try await dataSource.extract()
        }
        #expect(await dataSource.checkCompatibility().state == .unsupported)
    }

    @Test("Default data source accepts only the official local path shape")
    func officialLocalSourceOnly() async throws {
        let dataSource = DefaultSafariDataSource(
            bookmarksFileURL: URL(fileURLWithPath: "/tmp/export.html"),
            fileExists: { _ in true },
            isReadable: { _ in true },
            readData: { _ in Data() },
            fingerprint: { _ in
                SafariStorageFingerprint(
                    modificationDate: Date(timeIntervalSince1970: 1),
                    fileSize: 0
                )
            },
            safariVersion: { nil },
            startAccessing: { _ in false },
            stopAccessing: { _ in }
        )

        await #expect(throws: SafariReadError.storageUnavailable) {
            _ = try await dataSource.extract()
        }
        #expect(await dataSource.checkPermissions().state == .unavailable)
    }

    private func executionStep() throws -> ExecutionStep {
        let id = try logicalID(1)
        let node = try BSENode(
            logicalID: id,
            kind: .folder,
            title: "Folder",
            position: 0
        )
        let entry = DiffEntry(
            event: try BSEEvent(
                kind: .createNode,
                logicalID: id,
                before: nil,
                after: node
            ),
            reason: .createdInAfterSnapshot
        )
        let resolution = ConflictResolution(
            logicalID: id,
            kind: .applyLeft,
            reason: .changedOnlyInLeft,
            leftEntries: [entry],
            rightEntries: []
        )
        return ExecutionStep(
            kind: .create,
            logicalID: id,
            entry: entry,
            resolution: resolution
        )
    }

    private func officialSourceURL() -> URL {
        URL(fileURLWithPath: "/tmp/BookmarkBridgeTests/Library/Safari/Bookmarks.plist")
    }

    private func defaultDataSource(
        data: Data,
        fingerprint: @escaping @Sendable () async throws -> SafariStorageFingerprint
    ) -> DefaultSafariDataSource {
        DefaultSafariDataSource(
            bookmarksFileURL: officialSourceURL(),
            fileExists: { _ in true },
            isReadable: { _ in true },
            readData: { _ in data },
            fingerprint: { _ in try await fingerprint() },
            safariVersion: { "18.5-test" },
            startAccessing: { _ in false },
            stopAccessing: { _ in }
        )
    }

    private func propertyListData(
        storageVersion: Int = 1,
        children: [[String: Any]]
    ) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: [
                "WebBookmarkType": "WebBookmarkTypeList",
                "WebBookmarkFileVersion": storageVersion,
                "Children": children,
            ],
            format: .binary,
            options: 0
        )
    }

    private func folderDictionary(
        id: String,
        title: String,
        nativeRoleIdentifier: String? = nil,
        children: [[String: Any]]
    ) -> [String: Any] {
        var dictionary: [String: Any] = [
            "WebBookmarkType": "WebBookmarkTypeList",
            "WebBookmarkUUID": id,
            "Title": title,
            "Children": children,
        ]
        dictionary["WebBookmarkIdentifier"] = nativeRoleIdentifier
        return dictionary
    }

    private func bookmarkDictionary(
        id: String,
        title: String = "Bookmark",
        url: String = "https://example.com"
    ) -> [String: Any] {
        [
            "WebBookmarkType": "WebBookmarkTypeLeaf",
            "WebBookmarkUUID": id,
            "URIDictionary": ["title": title],
            "URLString": url,
        ]
    }
}

private actor TestSafariDataSource: SafariDataSource {
    private let extraction: SafariExtraction
    private let error: SafariReadError?
    private let permission: BSEAdapterPermissionStatus
    private let compatibility: BSEAdapterCompatibility
    private var storedExtractionCount = 0

    init(
        extraction: SafariExtraction,
        error: SafariReadError?,
        permission: BSEAdapterPermissionStatus,
        compatibility: BSEAdapterCompatibility
    ) {
        self.extraction = extraction
        self.error = error
        self.permission = permission
        self.compatibility = compatibility
    }

    func checkPermissions() async -> BSEAdapterPermissionStatus {
        permission
    }

    func checkCompatibility() async -> BSEAdapterCompatibility {
        compatibility
    }

    func extract() async throws -> SafariExtraction {
        storedExtractionCount += 1
        if let error { throw error }
        return extraction
    }

    func currentExtraction() -> SafariExtraction { extraction }
    func extractionCount() -> Int { storedExtractionCount }
}

private final class TestMonotonicTime: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [TimeInterval]

    init(values: [TimeInterval]) {
        self.values = values
    }

    func next() -> TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        guard !values.isEmpty else { return 0 }
        return values.removeFirst()
    }
}

private actor TestFingerprintSequence {
    private var values: [SafariStorageFingerprint]

    init(values: [SafariStorageFingerprint]) {
        self.values = values
    }

    func next() throws -> SafariStorageFingerprint {
        guard !values.isEmpty else {
            throw SafariReadError.snapshotInconsistent
        }
        return values.removeFirst()
    }
}
