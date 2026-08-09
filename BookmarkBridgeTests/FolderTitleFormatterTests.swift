//
//  FolderTitleFormatterTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("FolderTitleFormatter")
@MainActor
struct FolderTitleFormatterTests {

    @Test("Maps Safari technical roots to localized names")
    func mapsKnownRoots() {
        #expect(
            FolderTitleFormatter.friendly("BookmarksBar")
                == DocumentationText.value("folder.bookmarksBar")
        )
        #expect(
            FolderTitleFormatter.friendly("BookmarksMenu")
                == DocumentationText.value("folder.bookmarksMenu")
        )
        #expect(
            FolderTitleFormatter.friendly("com.apple.ReadingList")
                == DocumentationText.value("folder.readingList")
        )
    }

    @Test("Leaves any other title unchanged")
    func passesThroughUnknownTitles() {
        #expect(FolderTitleFormatter.friendly("Dev") == "Dev")
        #expect(FolderTitleFormatter.friendly("") == "")
    }
}
