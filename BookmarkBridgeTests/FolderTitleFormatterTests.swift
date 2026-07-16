//
//  FolderTitleFormatterTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("FolderTitleFormatter")
struct FolderTitleFormatterTests {

    @Test("Maps Safari technical roots to friendly French names")
    func mapsKnownRoots() {
        #expect(FolderTitleFormatter.friendly("BookmarksBar") == "Barre des favoris")
        #expect(FolderTitleFormatter.friendly("BookmarksMenu") == "Autres favoris")
        #expect(FolderTitleFormatter.friendly("com.apple.ReadingList") == "Liste de lecture")
    }

    @Test("Leaves any other title unchanged")
    func passesThroughUnknownTitles() {
        #expect(FolderTitleFormatter.friendly("Dev") == "Dev")
        #expect(FolderTitleFormatter.friendly("") == "")
    }
}
