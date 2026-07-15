//
//  SafariAccessValidationReportTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("SafariAccessValidationReport")
struct SafariAccessValidationReportTests {

    @Test("Counts folders, bookmarks, and total nodes from a decoded tree")
    func countsFromFixture() throws {
        let tree = try SafariBookmarkDecoder().decodeTree(from: SafariBookmarksFixture.data())
        let report = SafariAccessValidationReport.make(from: tree, isReadOnly: true)

        // Roots: BookmarksBar, Personnel, ReadingList (3) + nested Dev + empty folder = 5.
        #expect(report.folderCount == 5)
        #expect(report.bookmarkCount == 7)
        #expect(report.totalNodeCount == 12)
        #expect(report.isReadOnly)
        #expect(report.capturedAt == tree.capturedAt)
    }

    @Test("Reports zero counts for an empty tree")
    func emptyTree() {
        let tree = BookmarkTree(browser: .safari, roots: [], capturedAt: .distantPast)
        let report = SafariAccessValidationReport.make(from: tree, isReadOnly: false)

        #expect(report.folderCount == 0)
        #expect(report.bookmarkCount == 0)
        #expect(report.totalNodeCount == 0)
        #expect(!report.isReadOnly)
    }
}
