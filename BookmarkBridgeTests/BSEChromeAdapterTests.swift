//
//  BSEChromeAdapterTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Chrome Adapter")
struct BSEChromeAdapterTests {
    private func sourceID(_ value: Int = 1) throws -> BSESourceID {
        let string = String(format: "86000000-0000-0000-0000-%012d", value)
        return BSESourceID(try #require(UUID(uuidString: string)))
    }

    private func logicalID(_ value: Int) throws -> LogicalNodeID {
        let string = String(format: "87000000-0000-0000-0000-%012d", value)
        return LogicalNodeID(try #require(UUID(uuidString: string)))
    }

    private func profile(_ value: String = "Default") throws -> ChromeProfileIdentifier {
        try ChromeProfileIdentifier(value)
    }

    private func path(
        _ root: ChromeRootKind = .bookmarksBar,
        _ positions: Int...
    ) -> ChromeRecordPath {
        ChromeRecordPath(root: root, positions: positions)
    }

    private func bookmark(
        id: String? = "bookmark-1",
        title: String? = "Bookmark",
        url: String? = "https://example.com",
        position: Int = 0,
        path: ChromeRecordPath = ChromeRecordPath(
            root: .bookmarksBar,
            positions: [0]
        )
    ) -> ChromeRecord {
        .bookmark(ChromeBookmarkRecord(
            chromeID: nil,
            chromeGUID: id,
            title: title,
            urlString: url,
            position: position,
            path: path
        ))
    }

    private func folder(
        id: String? = "root-bar",
        title: String? = "Bookmarks Bar",
        position: Int = 0,
        path: ChromeRecordPath = ChromeRecordPath(root: .bookmarksBar),
        children: [ChromeRecord] = []
    ) -> ChromeRecord {
        .folder(ChromeFolderRecord(
            chromeID: nil,
            chromeGUID: id,
            title: title,
            position: position,
            path: path,
            children: children
        ))
    }

    private func extraction(
        records: [ChromeRecord],
        profileIdentifier: ChromeProfileIdentifier? = nil,
        issues: [ChromeReadIssue] = [],
        chromeVersion: String? = "126.0",
        storageVersion: String? = "1"
    ) throws -> ChromeExtraction {
        ChromeExtraction(
            records: records,
            capturedAt: Date(timeIntervalSince1970: 1_760_000_000),
            chromeVersion: chromeVersion,
            storageVersion: storageVersion,
            profileIdentifier: try profileIdentifier ?? profile(),
            issues: issues
        )
    }

    private func adapter(
        extraction: ChromeExtraction,
        adapterSourceID: BSESourceID? = nil,
        adapterProfile: ChromeProfileIdentifier? = nil,
        dataSourceProfile: ChromeProfileIdentifier? = nil,
        error: ChromeReadError? = nil,
        permission: BSEAdapterPermissionStatus = BSEAdapterPermissionStatus(state: .granted),
        compatibility: BSEAdapterCompatibility = BSEAdapterCompatibility(state: .supported),
        monotonicTime: @escaping @Sendable () -> TimeInterval = { 10 }
    ) throws -> (ChromeAdapter, TestChromeDataSource) {
        let selectedProfile = try adapterProfile ?? profile()
        let dataSource = TestChromeDataSource(
            profileIdentifier: dataSourceProfile ?? selectedProfile,
            extraction: extraction,
            error: error,
            permission: permission,
            compatibility: compatibility
        )
        return (
            ChromeAdapter(
                sourceID: try adapterSourceID ?? sourceID(),
                profileIdentifier: selectedProfile,
                dataSource: dataSource,
                monotonicTime: monotonicTime
            ),
            dataSource
        )
    }

    private func simpleExtraction(
        profileIdentifier: ChromeProfileIdentifier? = nil
    ) throws -> ChromeExtraction {
        try extraction(
            records: [folder(children: [bookmark()])],
            profileIdentifier: profileIdentifier
        )
    }

    // MARK: - Profiles and hierarchy

    @Test("An empty Chrome profile produces an empty snapshot")
    func emptyProfile() async throws {
        let (adapter, _) = try adapter(extraction: extraction(records: []))

        let snapshot = try await adapter.readSnapshot()

        #expect(snapshot.tree.isEmpty)
        #expect(snapshot.source == adapter.sourceID)
    }

    @Test("Reads the Default profile explicitly")
    func defaultProfile() async throws {
        let defaultProfile = try profile("Default")
        let source = try simpleExtraction(profileIdentifier: defaultProfile)
        let (adapter, _) = try adapter(
            extraction: source,
            adapterProfile: defaultProfile
        )

        let result = try await adapter.read()

        #expect(adapter.profileIdentifier == defaultProfile)
        #expect(result.report.profileIdentifier == defaultProfile)
        #expect(result.snapshot.tree.count == 2)
    }

    @Test("Reads Profile 1 explicitly")
    func numberedProfile() async throws {
        let profileOne = try profile("Profile 1")
        let source = try simpleExtraction(profileIdentifier: profileOne)
        let (adapter, _) = try adapter(
            extraction: source,
            adapterProfile: profileOne
        )

        let result = try await adapter.read()

        #expect(adapter.profileIdentifier.rawValue == "Profile 1")
        #expect(result.report.profileIdentifier == profileOne)
    }

    @Test(
        "One coherent Chrome read carries ordered native observations for every profile",
        arguments: ["Default", "Profile 1"]
    )
    func nativeIdentityObservations(profileName: String) async throws {
        let selectedProfile = try profile(profileName)
        let expectedSourceID = try sourceID(profileName == "Default" ? 1 : 2)
        let source = try simpleExtraction(profileIdentifier: selectedProfile)
        let (adapter, dataSource) = try adapter(
            extraction: source,
            adapterSourceID: expectedSourceID,
            adapterProfile: selectedProfile
        )

        let result = try await adapter.read()

        #expect(await dataSource.extractionCount() == 1)
        #expect(result.nativeIdentityObservations.count == result.snapshot.tree.count)
        #expect(result.nativeIdentityObservations.map(\.provisionalLogicalNodeID)
            == result.snapshot.tree.nodes.map(\.logicalID))
        #expect(result.nativeIdentityObservations.map(\.nativeIdentifier) == [
            NativeNodeIdentifier("guid:root-bar"),
            NativeNodeIdentifier("guid:bookmark-1"),
        ])
        #expect(result.nativeIdentityObservations.allSatisfy {
            $0.sourceID == expectedSourceID
        })
    }

    @Test("Chrome roots preserve canonical observation order and empty profiles stay empty")
    func nativeIdentityObservationRootOrder() async throws {
        let source = try extraction(records: [
            folder(
                id: "mobile",
                title: "Mobile Bookmarks",
                position: 2,
                path: path(.mobileBookmarks)
            ),
            folder(
                id: "bar",
                title: "Bookmarks Bar",
                position: 0,
                path: path(.bookmarksBar)
            ),
            folder(
                id: "other",
                title: "Other Bookmarks",
                position: 1,
                path: path(.otherBookmarks)
            ),
        ])
        let populated = try adapter(extraction: source).0
        let empty = try adapter(extraction: extraction(records: [])).0

        let populatedResult = try await populated.read()
        let emptyResult = try await empty.read()

        #expect(populatedResult.snapshot.tree.roots.map(\.node.title) == [
            "Bookmarks Bar", "Other Bookmarks", "Mobile Bookmarks",
        ])
        #expect(populatedResult.nativeIdentityObservations.map(\.nativeIdentifier) == [
            NativeNodeIdentifier("guid:bar"),
            NativeNodeIdentifier("guid:other"),
            NativeNodeIdentifier("guid:mobile"),
        ])
        #expect(emptyResult.snapshot.tree.isEmpty)
        #expect(emptyResult.nativeIdentityObservations.isEmpty)
    }

    @Test("Repeated Chrome transformations preserve snapshots and observations")
    func nativeIdentityObservationDeterminism() async throws {
        let first = try adapter(extraction: simpleExtraction()).0
        let second = try adapter(extraction: simpleExtraction()).0

        let firstResult = try await first.read()
        let secondResult = try await second.read()

        #expect(firstResult.snapshot == secondResult.snapshot)
        #expect(firstResult.nativeIdentityObservations
            == secondResult.nativeIdentityObservations)
    }

    @Test("Chrome id fallback is preserved consistently in the snapshot observation")
    func nativeIdentityObservationIDFallback() async throws {
        let record = ChromeRecord.folder(ChromeFolderRecord(
            chromeID: "42",
            chromeGUID: nil,
            title: "Fallback root",
            position: 0,
            path: path(.bookmarksBar),
            children: []
        ))
        let reader = try adapter(extraction: extraction(records: [record])).0

        let result = try await reader.read()
        let observation = try #require(result.nativeIdentityObservations.first)

        #expect(result.snapshot.tree.count == 1)
        #expect(observation.nativeIdentifier == NativeNodeIdentifier("id:42"))
        #expect(observation.nativeIdentityKind == .chromeIDFallback)
        #expect(observation.continuityIdentifier == nil)
        #expect(observation.continuityIdentityKind == nil)
    }

    @Test("A preferred GUID observation carries the id fallback continuity proof")
    func nativeIdentityObservationGUIDWithContinuity() async throws {
        let record = ChromeRecord.folder(ChromeFolderRecord(
            chromeID: "42",
            chromeGUID: "abc",
            title: "Migrated root",
            position: 0,
            path: path(.bookmarksBar),
            children: []
        ))
        let reader = try adapter(extraction: extraction(records: [record])).0

        let result = try await reader.read()
        let observation = try #require(result.nativeIdentityObservations.first)

        #expect(observation.nativeIdentifier == NativeNodeIdentifier("guid:abc"))
        #expect(observation.nativeIdentityKind == .chromeGUID)
        #expect(observation.continuityIdentifier == NativeNodeIdentifier("id:42"))
        #expect(observation.continuityIdentityKind == .chromeIDFallback)
    }

    @Test("A node without any valid Chrome identity is reported and omitted coherently")
    func invalidNativeIdentity() async throws {
        let nodePath = path(.bookmarksBar)
        let record = ChromeRecord.folder(ChromeFolderRecord(
            chromeID: "invalid",
            chromeGUID: " ",
            title: "Invalid root",
            position: 0,
            path: nodePath,
            children: []
        ))
        let reader = try adapter(extraction: extraction(records: [record])).0

        let result = try await reader.read()

        #expect(result.snapshot.tree.isEmpty)
        #expect(result.nativeIdentityObservations.isEmpty)
        #expect(result.issues.contains(.invalidNativeIdentifier(
            path: nodePath,
            reason: .noValidIdentifier(
                chromeID: "invalid",
                chromeGUID: " "
            )
        )))
    }

    @Test("Separate profile adapters never merge their trees")
    func multipleProfilesRemainIndependent() async throws {
        let defaultProfile = try profile("Default")
        let profileOne = try profile("Profile 1")
        let defaultSource = try extraction(
            records: [folder(children: [bookmark(title: "Default Bookmark")])],
            profileIdentifier: defaultProfile
        )
        let profileOneSource = try extraction(
            records: [folder(children: [bookmark(title: "Profile 1 Bookmark")])],
            profileIdentifier: profileOne
        )
        let (defaultAdapter, _) = try adapter(
            extraction: defaultSource,
            adapterSourceID: sourceID(1),
            adapterProfile: defaultProfile
        )
        let (profileOneAdapter, _) = try adapter(
            extraction: profileOneSource,
            adapterSourceID: sourceID(2),
            adapterProfile: profileOne
        )

        let defaultSnapshot = try await defaultAdapter.readSnapshot()
        let profileOneSnapshot = try await profileOneAdapter.readSnapshot()

        #expect(defaultSnapshot.tree.nodes.map(\.title).contains("Default Bookmark"))
        #expect(!defaultSnapshot.tree.nodes.map(\.title).contains("Profile 1 Bookmark"))
        #expect(profileOneSnapshot.tree.nodes.map(\.title).contains("Profile 1 Bookmark"))
        #expect(defaultSnapshot.source != profileOneSnapshot.source)
    }

    @Test("All three special Chrome roots remain separate BSE folders")
    func specialRoots() async throws {
        let records: [ChromeRecord] = [
            folder(
                id: "bar",
                title: "Bookmarks Bar",
                position: 0,
                path: path(.bookmarksBar)
            ),
            folder(
                id: "other",
                title: "Other Bookmarks",
                position: 1,
                path: path(.otherBookmarks)
            ),
            folder(
                id: "mobile",
                title: "Mobile Bookmarks",
                position: 2,
                path: path(.mobileBookmarks)
            ),
        ]
        let (adapter, _) = try adapter(extraction: extraction(records: records))

        let snapshot = try await adapter.readSnapshot()

        #expect(snapshot.tree.roots.map(\.node.title) == [
            "Bookmarks Bar", "Other Bookmarks", "Mobile Bookmarks",
        ])
        #expect(snapshot.tree.roots.map(\.node.permanentRootRole) == [
            .primaryBookmarks, .secondaryBookmarks, .mobileBookmarks,
        ])
        #expect(snapshot.tree.roots.map(\.node.position) == [0, 1, 2])
    }

    @Test("Preserves nested folders and sibling order")
    func nestedFoldersAndOrder() async throws {
        let nested = folder(
            id: "nested",
            title: "Nested",
            position: 1,
            path: path(.bookmarksBar, 1),
            children: [bookmark(
                id: "deep",
                title: "Deep",
                position: 0,
                path: path(.bookmarksBar, 1, 0)
            )]
        )
        let root = folder(children: [
            bookmark(id: "first", title: "First", position: 0, path: path(.bookmarksBar, 0)),
            nested,
            bookmark(id: "last", title: "Last", position: 2, path: path(.bookmarksBar, 2)),
        ])
        let (adapter, _) = try adapter(extraction: extraction(records: [root]))

        let snapshot = try await adapter.readSnapshot()
        let rootNode = try #require(snapshot.tree.roots.first?.node)
        let children = snapshot.tree.children(of: rootNode.logicalID)
        let nestedNode = try #require(children.first { $0.title == "Nested" })

        #expect(children.map(\.title) == ["First", "Nested", "Last"])
        #expect(snapshot.tree.children(of: nestedNode.logicalID).map(\.title) == ["Deep"])
    }

    @Test("Preserves Unicode and emoji titles verbatim")
    func unicodeAndEmoji() async throws {
        let root = folder(title: "Favoris 📚", children: [
            bookmark(title: "Café 東京 🚀"),
        ])
        let (adapter, _) = try adapter(extraction: extraction(records: [root]))

        let snapshot = try await adapter.readSnapshot()

        #expect(snapshot.tree.nodes.map(\.title) == ["Favoris 📚", "Café 東京 🚀"])
    }

    // MARK: - Local issues

    @Test("Preserves an empty title and reports it")
    func emptyTitle() async throws {
        let root = folder(children: [bookmark(title: "")])
        let (adapter, _) = try adapter(extraction: extraction(records: [root]))

        let result = try await adapter.read()

        #expect(result.snapshot.tree.nodes.first { $0.kind == .bookmark }?.title == "")
        #expect(result.issues == [.missingTitle(path: path(.bookmarksBar, 0))])
    }

    @Test("Reports an empty URL and continues with valid siblings")
    func emptyURL() async throws {
        let root = folder(children: [
            bookmark(id: "empty", url: "", position: 0, path: path(.bookmarksBar, 0)),
            bookmark(id: "valid", title: "Valid", position: 1, path: path(.bookmarksBar, 1)),
        ])
        let (adapter, _) = try adapter(extraction: extraction(records: [root]))

        let result = try await adapter.read()

        #expect(result.snapshot.tree.nodes.filter { $0.kind == .bookmark }.map(\.title) == ["Valid"])
        #expect(result.snapshot.tree.nodes.first { $0.title == "Valid" }?.position == 0)
        #expect(result.issues == [.missingURL(path: path(.bookmarksBar, 0))])
    }

    @Test("Reports an invalid URL without inventing a correction")
    func invalidURL() async throws {
        let root = folder(children: [bookmark(url: "not a URL")])
        let (adapter, _) = try adapter(extraction: extraction(records: [root]))

        let result = try await adapter.read()

        #expect(result.snapshot.tree.nodes.filter { $0.kind == .bookmark }.isEmpty)
        #expect(result.issues == [.invalidURL(path: path(.bookmarksBar, 0))])
    }

    @Test("Retains extraction issues beside transformation issues")
    func localIssuesAccumulate() async throws {
        let sourceIssue = ChromeReadIssue.unknownNodeType(path: path(.bookmarksBar, 0))
        let root = folder(children: [bookmark(id: "missing-title", title: nil)])
        let source = try extraction(records: [root], issues: [sourceIssue])
        let (adapter, _) = try adapter(extraction: source)

        let result = try await adapter.read()

        #expect(result.issues == [
            sourceIssue,
            .missingTitle(path: path(.bookmarksBar, 0)),
        ])
        #expect(result.report.issuesCount == 2)
    }

    // MARK: - Determinism and identity scope

    @Test("Identical Chrome reads produce identical snapshots and provisional IDs")
    func deterministicSnapshot() async throws {
        let source = try simpleExtraction()
        let (firstAdapter, _) = try adapter(extraction: source)
        let (secondAdapter, _) = try adapter(extraction: source)

        let first = try await firstAdapter.readSnapshot()
        let second = try await secondAdapter.readSnapshot()

        #expect(first == second)
        #expect(first.tree.nodes.map(\.logicalID) == second.tree.nodes.map(\.logicalID))
    }

    @Test("Provisional IDs are source-scoped and never inter-browser identity")
    func provisionalIdentifiersAreNotGlobalIdentity() async throws {
        let source = try simpleExtraction()
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

        // Equal Chrome content under distinct sources cannot establish global or
        // Safari/Chrome identity. Only the future persisted BSE identity may do so.
        #expect(first.tree.nodes.map(\.title) == second.tree.nodes.map(\.title))
        #expect(first.tree.nodes.map(\.logicalID) != second.tree.nodes.map(\.logicalID))
    }

    @Test("Native Chrome identifiers never appear in the BSE snapshot")
    func nativeIdentifiersStayPrivate() async throws {
        let rootID = "private-chrome-root-id"
        let bookmarkID = "private-chrome-bookmark-id"
        let source = try extraction(records: [folder(
            id: rootID,
            children: [bookmark(id: bookmarkID)]
        )])
        let (adapter, _) = try adapter(extraction: source)

        let data = try JSONEncoder().encode(await adapter.readSnapshot())
        let json = String(decoding: data, as: UTF8.self)

        #expect(!json.contains(rootID))
        #expect(!json.contains(bookmarkID))
    }

    @Test("Reading never mutates the injected profile source")
    func sourceIsNotMutated() async throws {
        let source = try simpleExtraction()
        let (adapter, dataSource) = try adapter(extraction: source)
        let before = await dataSource.currentExtraction()

        _ = try await adapter.readSnapshot()

        #expect(await dataSource.currentExtraction() == before)
        #expect(await dataSource.extractionCount() == 1)
    }

    @Test("A global source error fails explicitly")
    func globalError() async throws {
        let (adapter, _) = try adapter(
            extraction: simpleExtraction(),
            error: .storageCorrupted
        )

        await #expect(throws: ChromeReadError.storageCorrupted) {
            _ = try await adapter.readSnapshot()
        }
    }

    @Test("Adapter rejects a data source for another profile")
    func profileMismatch() async throws {
        let (adapter, dataSource) = try adapter(
            extraction: simpleExtraction(),
            adapterProfile: profile("Default"),
            dataSourceProfile: profile("Profile 1")
        )

        await #expect(throws: ChromeReadError.profileMismatch) {
            _ = try await adapter.readSnapshot()
        }
        #expect(await dataSource.extractionCount() == 0)
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

    @Test("read and readSnapshot expose the same snapshot contract")
    func readAPIs() async throws {
        let source = try simpleExtraction()
        let (readAdapter, _) = try adapter(extraction: source)
        let (snapshotAdapter, _) = try adapter(extraction: source)

        let result = try await readAdapter.read()
        let snapshot = try await snapshotAdapter.readSnapshot()

        #expect(result.snapshot == snapshot)
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

    @Test("Execute is rejected before any source access")
    func executeIsUnsupported() async throws {
        let (adapter, dataSource) = try adapter(extraction: simpleExtraction())

        await #expect(throws: BSEAdapterError.unsupportedCapability(.write)) {
            _ = try await adapter.execute(executionStep())
        }
        #expect(await dataSource.extractionCount() == 0)
    }

    @Test("Verification is unsupported and performs no source access")
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
                try #require(UUID(uuidString: "88000000-0000-0000-0000-000000000001"))
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

    @Test("Read report remains separate from the snapshot")
    func readReport() async throws {
        let clock = ChromeTestMonotonicTime(values: [20, 20.5])
        let (adapter, _) = try adapter(
            extraction: simpleExtraction(),
            monotonicTime: { clock.next() }
        )

        let result = try await adapter.read()

        #expect(result.report.foldersRead == 1)
        #expect(result.report.bookmarksRead == 1)
        #expect(result.report.issuesCount == 0)
        #expect(result.report.duration == 0.5)
        #expect(result.report.chromeVersion == "126.0")
        #expect(result.report.storageVersion == "1")
        #expect(result.report.profileIdentifier.rawValue == "Default")
        #expect(result.snapshot.tree.count == 2)
    }

    // MARK: - Profile identifier

    @Test("Profile identifier is typed and Codable")
    func profileIdentifierCodable() throws {
        let original = try profile("Profile 1")
        let data = try JSONEncoder().encode(original)

        #expect(try JSONDecoder().decode(ChromeProfileIdentifier.self, from: data) == original)
        #expect(throws: ChromeProfileIdentifierError.empty) {
            _ = try ChromeProfileIdentifier("")
        }
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                ChromeProfileIdentifier.self,
                from: Data("\"../Default\"".utf8)
            )
        }
    }

    // MARK: - Default extraction

    @Test("Default source extracts roots in canonical order, not JSON order")
    func defaultExtractionAndRootOrder() async throws {
        let data = try jsonData(roots: [
            "synced": folderJSON(id: "mobile", name: "Mobile Bookmarks"),
            "other": folderJSON(id: "other", name: "Other Bookmarks"),
            "bookmark_bar": folderJSON(
                id: "bar",
                name: "Bookmarks Bar",
                children: [bookmarkJSON(id: "bookmark")]
            ),
        ])
        let dataSource = try defaultDataSource(data: data)

        let extracted = try await dataSource.extract()
        let transformed = try ChromeSnapshotTransformer().transform(
            extracted,
            sourceID: sourceID()
        )

        #expect(extracted.records.count == 3)
        #expect(transformed.snapshot.tree.roots.map(\.node.title) == [
            "Bookmarks Bar", "Other Bookmarks", "Mobile Bookmarks",
        ])
        #expect(transformed.snapshot.tree.roots.map(\.node.permanentRootRole) == [
            .primaryBookmarks, .secondaryBookmarks, .mobileBookmarks,
        ])
        #expect(extracted.profileIdentifier.rawValue == "Default")
    }

    @Test("Default extraction preserves id fallback through transformation")
    func defaultExtractionIDFallback() async throws {
        let data = try jsonData(roots: [
            "bookmark_bar": [
                "type": "folder",
                "id": "1",
                "name": "Bookmarks Bar",
                "children": [[
                    "type": "url",
                    "id": "2",
                    "name": "Fallback bookmark",
                    "url": "https://fallback.example",
                ]],
            ],
        ])
        let extraction = try await defaultDataSource(data: data).extract()

        let transformed = try ChromeSnapshotTransformer().transform(
            extraction,
            sourceID: sourceID()
        )

        #expect(transformed.nativeIdentityObservations.map(\.nativeIdentifier) == [
            NativeNodeIdentifier("id:1"),
            NativeNodeIdentifier("id:2"),
        ])
        #expect(transformed.nativeIdentityObservations.allSatisfy {
            $0.nativeIdentityKind == .chromeIDFallback
                && $0.continuityIdentifier == nil
        })
    }

    @Test("Missing special roots are tolerated without invention")
    func missingRoots() async throws {
        let data = try jsonData(roots: [
            "other": folderJSON(id: "other", name: "Other Bookmarks"),
        ])
        let dataSource = try defaultDataSource(data: data)

        let extraction = try await dataSource.extract()
        let transformed = try ChromeSnapshotTransformer().transform(
            extraction,
            sourceID: sourceID()
        )

        #expect(transformed.snapshot.tree.roots.map(\.node.title) == ["Other Bookmarks"])
        #expect(transformed.snapshot.tree.roots.first?.node.position == 1)
    }

    @Test("Unknown native node types become local issues")
    func unknownNodeType() async throws {
        let data = try jsonData(roots: [
            "bookmark_bar": folderJSON(
                id: "bar",
                name: "Bookmarks Bar",
                children: [
                    ["type": "future", "guid": "future"],
                    bookmarkJSON(
                        id: "accepted",
                        name: "Accepted",
                        url: "https://accepted.test"
                    ),
                ]
            ),
        ])
        let dataSource = try defaultDataSource(data: data)

        let extracted = try await dataSource.extract()

        #expect(extracted.issues == [
            .unknownNodeType(path: path(.bookmarksBar, 0)),
        ])
        #expect(extracted.records.count == 1)
        let transformed = try ChromeSnapshotTransformer().transform(
            extracted,
            sourceID: sourceID()
        )
        let accepted = try #require(
            transformed.snapshot.tree.nodes.first {
                $0.kind == .bookmark
            }
        )
        #expect(accepted.position == 0)
    }

    @Test("Unknown storage versions remain readable but untested")
    func untestedStorageVersion() async throws {
        let data = try jsonData(version: 42, roots: [:])
        let dataSource = try defaultDataSource(data: data)

        let extraction = try await dataSource.extract()

        #expect(extraction.storageVersion == "42")
        #expect(await dataSource.checkCompatibility().state == .untested)
    }

    @Test("Detects a profile changing during read")
    func coherentReadIsRequired() async throws {
        let data = try jsonData(roots: [:])
        let fingerprints = ChromeTestFingerprintSequence(values: [
            ChromeStorageFingerprint(
                modificationDate: Date(timeIntervalSince1970: 1),
                fileSize: data.count
            ),
            ChromeStorageFingerprint(
                modificationDate: Date(timeIntervalSince1970: 2),
                fileSize: data.count + 1
            ),
        ])
        let dataSource = try defaultDataSource(
            data: data,
            fingerprint: { try await fingerprints.next() }
        )

        await #expect(throws: ChromeReadError.snapshotInconsistent) {
            _ = try await dataSource.extract()
        }
    }

    @Test("Reads through the authorized Chrome directory security scope")
    func usesAuthorizedDirectoryScope() async throws {
        let selectedProfile = try profile()
        let data = try jsonData(roots: [:])
        let controller = SpySecurityScopedFileController()
        let chromeDirectory = officialSourceURL(
            profileIdentifier: selectedProfile
        )
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        let stableFingerprint = ChromeStorageFingerprint(
            modificationDate: Date(timeIntervalSince1970: 1_760_000_000),
            fileSize: data.count
        )
        let dataSource = DefaultChromeDataSource(
            bookmarksFileURL: officialSourceURL(
                profileIdentifier: selectedProfile
            ),
            profileIdentifier: selectedProfile,
            securityScopeURL: chromeDirectory,
            fileExists: { _ in true },
            isReadable: { _ in true },
            readData: { _ in data },
            fingerprint: { _ in stableFingerprint },
            chromeVersion: { "126.0-test" },
            startAccessing: { controller.startAccessing($0) },
            stopAccessing: { controller.stopAccessing($0) }
        )

        _ = try await dataSource.extract()

        #expect(controller.startedURLs == [chromeDirectory])
        #expect(controller.stoppedURLs == [chromeDirectory])
    }

    @Test("Corrupted JSON is a global error")
    func corruptedStorage() async throws {
        let data = Data("not json".utf8)
        let dataSource = try defaultDataSource(data: data)

        await #expect(throws: ChromeReadError.storageCorrupted) {
            _ = try await dataSource.extract()
        }
    }

    @Test("Only the official local Chrome profile path is accepted")
    func officialLocalSourceOnly() async throws {
        let selectedProfile = try profile()
        let dataSource = DefaultChromeDataSource(
            bookmarksFileURL: URL(fileURLWithPath: "/tmp/export.html"),
            profileIdentifier: selectedProfile,
            fileExists: { _ in true },
            isReadable: { _ in true },
            readData: { _ in Data() },
            fingerprint: { _ in
                ChromeStorageFingerprint(
                    modificationDate: Date(timeIntervalSince1970: 1),
                    fileSize: 0
                )
            },
            chromeVersion: { nil },
            startAccessing: { _ in false },
            stopAccessing: { _ in }
        )

        await #expect(throws: ChromeReadError.storageUnavailable) {
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

    private func officialSourceURL(
        profileIdentifier: ChromeProfileIdentifier
    ) -> URL {
        URL(fileURLWithPath: "/tmp/BookmarkBridgeTests/Library/Application Support/Google/Chrome")
            .appending(path: profileIdentifier.rawValue)
            .appending(path: "Bookmarks")
    }

    private func defaultDataSource(
        data: Data,
        profileIdentifier: ChromeProfileIdentifier? = nil,
        fingerprint: (@Sendable () async throws -> ChromeStorageFingerprint)? = nil
    ) throws -> DefaultChromeDataSource {
        let selectedProfile = try profileIdentifier ?? profile()
        let stableFingerprint = ChromeStorageFingerprint(
            modificationDate: Date(timeIntervalSince1970: 1_760_000_000),
            fileSize: data.count
        )
        return DefaultChromeDataSource(
            bookmarksFileURL: officialSourceURL(profileIdentifier: selectedProfile),
            profileIdentifier: selectedProfile,
            fileExists: { _ in true },
            isReadable: { _ in true },
            readData: { _ in data },
            fingerprint: { _ in
                if let fingerprint {
                    return try await fingerprint()
                }
                return stableFingerprint
            },
            chromeVersion: { "126.0-test" },
            startAccessing: { _ in false },
            stopAccessing: { _ in }
        )
    }

    private func jsonData(
        version: Int = 1,
        roots: [String: Any]
    ) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "version": version,
            "checksum": "ignored-read-only-metadata",
            "roots": roots,
        ])
    }

    private func folderJSON(
        id: String,
        name: String,
        children: [[String: Any]] = []
    ) -> [String: Any] {
        [
            "type": "folder",
            "guid": id,
            "name": name,
            "children": children,
        ]
    }

    private func bookmarkJSON(
        id: String,
        name: String = "Bookmark",
        url: String = "https://example.com"
    ) -> [String: Any] {
        [
            "type": "url",
            "guid": id,
            "name": name,
            "url": url,
        ]
    }
}

private actor TestChromeDataSource: ChromeDataSource {
    nonisolated let profileIdentifier: ChromeProfileIdentifier
    private let extraction: ChromeExtraction
    private let error: ChromeReadError?
    private let permission: BSEAdapterPermissionStatus
    private let compatibility: BSEAdapterCompatibility
    private var storedExtractionCount = 0

    init(
        profileIdentifier: ChromeProfileIdentifier,
        extraction: ChromeExtraction,
        error: ChromeReadError?,
        permission: BSEAdapterPermissionStatus,
        compatibility: BSEAdapterCompatibility
    ) {
        self.profileIdentifier = profileIdentifier
        self.extraction = extraction
        self.error = error
        self.permission = permission
        self.compatibility = compatibility
    }

    func checkPermissions() async -> BSEAdapterPermissionStatus { permission }
    func checkCompatibility() async -> BSEAdapterCompatibility { compatibility }

    func extract() async throws -> ChromeExtraction {
        storedExtractionCount += 1
        if let error { throw error }
        return extraction
    }

    func currentExtraction() -> ChromeExtraction { extraction }
    func extractionCount() -> Int { storedExtractionCount }
}

private final class ChromeTestMonotonicTime: @unchecked Sendable {
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

private actor ChromeTestFingerprintSequence {
    private var values: [ChromeStorageFingerprint]

    init(values: [ChromeStorageFingerprint]) {
        self.values = values
    }

    func next() throws -> ChromeStorageFingerprint {
        guard !values.isEmpty else {
            throw ChromeReadError.snapshotInconsistent
        }
        return values.removeFirst()
    }
}
