//
//  SafariImportTests.swift
//  BookmarkBridgeTests
//

import CryptoKit
import Foundation
import Testing

@testable import BookmarkBridge

@Suite("Safari supported import package")
struct SafariImportTests {
    @Test("HTML export preserves hierarchy, order, Unicode, and escaping")
    func exportsHierarchyAndEscapesValues() throws {
        let tree = try bookmarkTree()

        let export = SafariBookmarkHTMLExporter().export(tree)
        let html = try #require(String(data: export.data, encoding: .utf8))

        #expect(export.folderCount == 2)
        #expect(export.bookmarkCount == 3)
        #expect(export.skippedBookmarks.map(\.title) == ["Chrome interne"])
        #expect(html.contains("<H3>Dossier &amp; outils</H3>"))
        #expect(html.contains("Café &lt;essai&gt; &amp; météo"))
        #expect(html.contains("HREF=\"https://example.com/?a=1&amp;b=%22deux%22\""))

        let first = try #require(html.range(of: "A – Premier"))
        let nestedFolder = try #require(html.range(of: "B – Sous-dossier"))
        let nestedBookmark = try #require(html.range(of: "B1 – Élément"))
        let last = try #require(html.range(of: "C – Dernier"))
        #expect(first.lowerBound < nestedFolder.lowerBound)
        #expect(nestedFolder.lowerBound < nestedBookmark.lowerBound)
        #expect(nestedBookmark.lowerBound < last.lowerBound)
        #expect(!html.contains("chrome://password-manager"))
    }

    @Test("Export is deterministic for the same immutable tree")
    func exportsDeterministically() throws {
        let tree = try bookmarkTree()
        let exporter = SafariBookmarkHTMLExporter()

        let first = exporter.export(tree)
        let second = exporter.export(tree)

        #expect(first == second)
        #expect(
            Data(SHA256.hash(data: first.data))
                == Data(SHA256.hash(data: second.data))
        )
    }

    @Test("Compatibility analyzer accepts only importer-safe operations")
    func classifiesPlanOperations() throws {
        let parentID = logicalID(100)
        let bookmarkID = logicalID(101)
        let safeURL = try #require(URL(string: "https://example.com"))
        let internalURL = try #require(URL(string: "chrome://settings"))
        let operations: [SynchronizationOperation] = [
            .create(CreateNodeOperation(
                logicalNodeID: parentID,
                kind: .folder,
                title: "Folder",
                url: nil,
                parentID: nil,
                position: 0
            )),
            .create(CreateNodeOperation(
                logicalNodeID: bookmarkID,
                kind: .bookmark,
                title: "Bookmark",
                url: safeURL,
                parentID: parentID,
                position: 0
            )),
            .updateURL(UpdateURLOperation(
                logicalNodeID: bookmarkID,
                url: safeURL
            )),
            .rename(RenameNodeOperation(
                logicalNodeID: bookmarkID,
                title: "Renamed"
            )),
            .move(MoveNodeOperation(
                logicalNodeID: bookmarkID,
                parentID: nil,
                position: 0
            )),
            .reorder(ReorderNodeOperation(
                logicalNodeID: bookmarkID,
                position: 1
            )),
            .delete(DeleteNodeOperation(logicalNodeID: bookmarkID)),
            .archive(ArchiveNodeOperation(
                logicalNodeID: bookmarkID,
                state: .archived
            )),
            .updateURL(UpdateURLOperation(
                logicalNodeID: bookmarkID,
                url: internalURL
            )),
        ]

        let report = SafariImportCompatibilityAnalyzer().analyze(
            plan(operations)
        )

        #expect(report.supportedOperationCount == 2)
        #expect(report.incompatibilities.map(\.reason) == [
            .urlUpdate,
            .rename,
            .move,
            .reorder,
            .deletion,
            .archive,
            .unsupportedURLScheme,
        ])
        #expect(!report.isCompatible)
    }

    @Test("Package builder writes only the requested HTML artifact")
    func buildsTraceablePackage() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "BookmarkBridge-SafariImportTests-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let safePlan = plan([
            .create(CreateNodeOperation(
                logicalNodeID: logicalID(200),
                kind: .folder,
                title: "Imported",
                url: nil,
                parentID: nil,
                position: 0
            )),
        ])

        let package = try SafariImportPackageBuilder().build(
            tree: try bookmarkTree(),
            plan: safePlan,
            destinationDirectory: directory
        )
        let writtenData = try Data(contentsOf: package.fileURL)
        let directoryContents = try FileManager.default.contentsOfDirectory(
            atPath: directory.path
        )

        #expect(package.fileURL.lastPathComponent == "BookmarkBridge-Safari-Import.html")
        #expect(package.byteCount == writtenData.count)
        #expect(package.sha256 == Data(SHA256.hash(data: writtenData)))
        #expect(package.folderCount == 2)
        #expect(package.bookmarkCount == 3)
        #expect(package.skippedBookmarks.count == 1)
        #expect(package.compatibility.isCompatible)
        #expect(directoryContents == ["BookmarkBridge-Safari-Import.html"])
        #expect(!FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("Bookmarks.plist").path
        ))
    }

    @Test("Package builder honors the exact user-selected file URL")
    func buildsAtSelectedFileURL() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "BookmarkBridge-SafariImportDestination-\(UUID().uuidString)",
                isDirectory: true
            )
        defer { try? FileManager.default.removeItem(at: directory) }
        let selectedFile = directory.appendingPathComponent(
            "BookmarkBridge-Safari-Import.html"
        )
        let safePlan = plan([
            .create(CreateNodeOperation(
                logicalNodeID: logicalID(210),
                kind: .folder,
                title: "Imported",
                url: nil,
                parentID: nil,
                position: 0
            )),
        ])

        let package = try SafariImportPackageBuilder().build(
            tree: try bookmarkTree(),
            plan: safePlan,
            destinationFileURL: selectedFile
        )

        #expect(package.fileURL == selectedFile)
        #expect(FileManager.default.fileExists(atPath: selectedFile.path))
    }

    @Test("Package builder refuses an incompatible plan before file creation")
    func rejectsIncompatiblePlan() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "BookmarkBridge-SafariImportTests-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let incompatiblePlan = plan([
            .delete(DeleteNodeOperation(logicalNodeID: logicalID(300))),
        ])

        #expect(throws: SafariImportPackageError.self) {
            _ = try SafariImportPackageBuilder().build(
                tree: try bookmarkTree(),
                plan: incompatiblePlan,
                destinationDirectory: directory
            )
        }
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test("Workflow exports only planned creations and leaves Safari untouched")
    func workflowPreparesNativeImport() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "BookmarkBridge-SafariImportWorkflow-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let chromeURL = root.appendingPathComponent("Bookmarks")
        let safariURL = root.appendingPathComponent("Bookmarks.plist")
        let destination = root.appendingPathComponent("Import", isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        let safariSentinel = Data("Safari-private-storage".utf8)
        try safariSentinel.write(to: safariURL)
        let folderID = logicalID(400)
        let result = try preview(
            chromeURL: chromeURL,
            safariURL: safariURL,
            operations: [
                .create(CreateNodeOperation(
                    logicalNodeID: folderID,
                    kind: .folder,
                    title: "New folder",
                    url: nil,
                    parentID: nil,
                    position: 0
                )),
                .create(CreateNodeOperation(
                    logicalNodeID: logicalID(401),
                    kind: .bookmark,
                    title: "Only new bookmark",
                    url: URL(string: "https://new.example")!,
                    parentID: folderID,
                    position: 0
                )),
                .delete(DeleteNodeOperation(logicalNodeID: logicalID(402))),
            ]
        )

        let package = try await SafariImportWorkflow(
            destinationDirectory: destination
        ).prepare(preview: result)

        #expect(package.bookmarkCount == 1)
        #expect(package.folderCount == 1)
        #expect(package.compatibility.incompatibilities.count == 1)
        #expect(package.fileURL.deletingLastPathComponent() == destination)
        #expect(try Data(contentsOf: safariURL) == safariSentinel)
        #expect(
            try String(contentsOf: package.fileURL, encoding: .utf8)
                .contains("https://new.example")
        )
    }

    @Test("Delta tree preserves created hierarchy and excludes other operations")
    func deltaTreeContainsOnlyCreations() throws {
        let folderID = logicalID(500)
        let tree = SafariImportDeltaTreeBuilder().build(from: plan([
            .create(CreateNodeOperation(
                logicalNodeID: folderID,
                kind: .folder,
                title: "Created folder",
                url: nil,
                parentID: nil,
                position: 1
            )),
            .create(CreateNodeOperation(
                logicalNodeID: logicalID(501),
                kind: .bookmark,
                title: "Created bookmark",
                url: URL(string: "https://created.example")!,
                parentID: folderID,
                position: 0
            )),
            .rename(RenameNodeOperation(
                logicalNodeID: logicalID(502),
                title: "Existing renamed bookmark"
            )),
            .delete(DeleteNodeOperation(logicalNodeID: logicalID(503))),
        ]))

        #expect(tree.roots.map(\.title) == ["Created folder"])
        #expect(tree.bookmarkCount == 1)
        #expect(tree.allBookmarks.map(\.title) == ["Created bookmark"])
    }

    @Test("Workflow honors the scoped plan without reading browser storage")
    func workflowSupportsScopedSelection() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "BookmarkBridge-SafariImportScoped-\(UUID().uuidString)",
                isDirectory: true
            )
        defer { try? FileManager.default.removeItem(at: directory) }
        let result = try preview(
            chromeURL: URL(fileURLWithPath: "/unread/Bookmarks"),
            safariURL: URL(fileURLWithPath: "/unread/Bookmarks.plist"),
            chromeSelection: .nativeIdentifiers(["2"]),
            operations: [
                .create(CreateNodeOperation(
                    logicalNodeID: logicalID(510),
                    kind: .bookmark,
                    title: "Selected bookmark",
                    url: URL(string: "https://selected.example")!,
                    parentID: nil,
                    position: 0
                )),
            ]
        )

        let package = try await SafariImportWorkflow(
            destinationDirectory: directory
        ).prepare(preview: result)

        #expect(package.bookmarkCount == 1)
        #expect(
            try String(contentsOf: package.fileURL, encoding: .utf8)
                .contains("https://selected.example")
        )
    }

    private func bookmarkTree() throws -> BookmarkTree {
        let firstURL = try #require(URL(
            string: "https://example.com/?a=1&b=%22deux%22"
        ))
        let nestedURL = try #require(URL(string: "https://example.com/nested"))
        let lastURL = try #require(URL(string: "https://example.com/last"))
        let internalURL = try #require(URL(string: "chrome://password-manager"))

        return BookmarkTree(
            browser: .chrome,
            roots: [
                BookmarkFolder(
                    id: BookmarkID("root"),
                    title: "Dossier & outils",
                    children: [
                        .bookmark(Bookmark(
                            id: BookmarkID("first"),
                            title: "A – Premier",
                            url: firstURL
                        )),
                        .folder(BookmarkFolder(
                            id: BookmarkID("nested-folder"),
                            title: "B – Sous-dossier",
                            children: [
                                .bookmark(Bookmark(
                                    id: BookmarkID("nested"),
                                    title: "B1 – Élément",
                                    url: nestedURL
                                )),
                                .bookmark(Bookmark(
                                    id: BookmarkID("internal"),
                                    title: "Chrome interne",
                                    url: internalURL
                                )),
                            ]
                        )),
                        .bookmark(Bookmark(
                            id: BookmarkID("last"),
                            title: "C – Dernier Café <essai> & météo",
                            url: lastURL
                        )),
                    ]
                ),
            ],
            capturedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func plan(
        _ operations: [SynchronizationOperation]
    ) -> SynchronizationPlan {
        let source = BSESourceID(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        let target = BSESourceID(UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
        return SynchronizationPlan(
            phases: [
                .preparation([]),
                .structural([]),
                .content(operations),
                .cleanup([]),
            ],
            report: SynchronizationPlanningReport(
                policy: .allChanges(direction: .oneWay(
                    source: source,
                    target: target
                )),
                inputChangeCount: operations.count,
                plannedOperationCount: operations.count,
                skippedChangeCount: 0,
                preparationOperationCount: 0,
                structuralOperationCount: 0,
                contentOperationCount: operations.count,
                cleanupOperationCount: 0
            )
        )
    }

    private func preview(
        chromeURL: URL,
        safariURL: URL,
        chromeSelection: SynchronizationSelectionScope = .all,
        operations: [SynchronizationOperation]
    ) throws -> SynchronizationPreviewResult {
        let safariSourceID = BSESourceID(
            UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )
        let chromeSourceID = BSESourceID(
            UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        )
        let request = SynchronizationPreviewRequest(
            direction: .chromeToSafari,
            safariSourceID: safariSourceID,
            chromeSourceID: chromeSourceID,
            safariBookmarksURL: safariURL,
            chromeBookmarksURL: chromeURL,
            chromeProfileIdentifier: try ChromeProfileIdentifier("Default"),
            safariSecurityScopeURL: safariURL,
            chromeSecurityScopeURL: chromeURL.deletingLastPathComponent(),
            chromeSelection: chromeSelection
        )
        let emptyTree = try BSETree(nodes: [])
        return try SynchronizationPreviewResult(
            request: request,
            sourceSnapshot: BSESnapshot(
                source: chromeSourceID,
                capturedAt: .distantPast,
                tree: emptyTree
            ),
            targetSnapshot: BSESnapshot(
                source: safariSourceID,
                capturedAt: .distantPast,
                tree: emptyTree
            ),
            logicalDiff: LogicalDiffResult(
                changes: [],
                report: LogicalDiffReport(
                    beforeNodeCount: 0,
                    afterNodeCount: 0,
                    unchangedNodeCount: 0,
                    createdCount: 0,
                    deletedCount: 0,
                    renamedCount: 0,
                    urlChangedCount: 0,
                    movedCount: 0,
                    reorderedCount: 0,
                    lifecycleChangedCount: 0
                )
            ),
            plan: plan(operations)
        )
    }

    private func logicalID(_ value: Int) -> LogicalNodeID {
        LogicalNodeID(UUID(uuid: (
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0,
            UInt8(truncatingIfNeeded: value >> 8),
            UInt8(truncatingIfNeeded: value)
        )))
    }
}
