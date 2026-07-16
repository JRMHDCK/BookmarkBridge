//
//  ExplorerStepTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("ExplorerStep")
struct ExplorerStepTests {

    private let safari = BookmarkSource.singleProfile(.safari)
    private let chrome = BookmarkSource(browser: .chrome, profile: "Default", displayName: "Chrome — Perso")
    private let tree = BookmarkTree(browser: .safari, roots: [], capturedAt: .distantPast)

    private func folder(_ id: String) -> BookmarkFolder {
        BookmarkFolder(id: BookmarkID(id), title: id)
    }

    @Test("Equal source steps are equal; different sources differ")
    func sourceEquality() {
        #expect(ExplorerStep.source(safari, tree) == .source(safari, tree))
        #expect(ExplorerStep.source(safari, tree) != .source(chrome, tree))
    }

    @Test("Equal folder steps are equal; different folders differ")
    func folderEquality() {
        #expect(ExplorerStep.folder(folder("a")) == .folder(folder("a")))
        #expect(ExplorerStep.folder(folder("a")) != .folder(folder("b")))
    }

    @Test("A source step never equals a folder step")
    func sourceNeverEqualsFolder() {
        #expect(ExplorerStep.source(safari, tree) != .folder(folder("a")))
    }

    @Test("Distinct steps hash into a set as distinct elements")
    func hashableInSet() {
        let steps: Set<ExplorerStep> = [
            .source(safari, tree),
            .source(chrome, tree),
            .folder(folder("a")),
            .folder(folder("a")),   // duplicate
        ]
        #expect(steps.count == 3)
    }
}
