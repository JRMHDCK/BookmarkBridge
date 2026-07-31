//
//  SafariBookmarkValidatorTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("Safari bookmark persistence validator")
struct SafariBookmarkValidatorTests {
    private let validator = SafariBookmarkValidator()

    @Test("A realistic Safari tree is valid")
    func validTree() throws {
        try validator.validate(document(from: SafariPersistenceFixture.propertyList()))
    }

    @Test("Safari system proxy nodes are valid and remain structurally strict")
    func proxyNode() throws {
        var root = SafariPersistenceFixture.propertyList()
        var children = try #require(root["Children"] as? [[String: Any]])
        children.insert([
            "WebBookmarkType": "WebBookmarkTypeProxy",
            "WebBookmarkUUID": "00000000-0000-0000-0000-000000000002",
            "WebBookmarkIdentifier": "History",
            "Title": "History",
        ], at: 0)
        root["Children"] = children

        try validator.validate(document(from: root))

        children[0].removeValue(forKey: "WebBookmarkIdentifier")
        root["Children"] = children
        #expect(throws: SafariPersistenceError.invalidStructure(
            .invalidNode(path: [0])
        )) {
            try validator.validate(document(from: root))
        }
    }

    @Test("Safari empty list nodes may omit Children")
    func emptyListWithoutChildren() throws {
        var root = SafariPersistenceFixture.propertyList()
        var children = try #require(root["Children"] as? [[String: Any]])
        children.append([
            "WebBookmarkType": "WebBookmarkTypeList",
            "WebBookmarkUUID": "00000000-0000-0000-0000-000000000003",
            "Title": "BookmarksMenu",
        ])
        root["Children"] = children

        try validator.validate(document(from: root))
    }

    @Test("The root must be a recognized list")
    func invalidRoot() throws {
        var root = SafariPersistenceFixture.propertyList()
        root["WebBookmarkType"] = "WebBookmarkTypeLeaf"

        #expect(throws: SafariPersistenceError.invalidStructure(.unrecognizedRoot)) {
            try validator.validate(document(from: root))
        }
    }

    @Test("UUIDs must be unique across the complete tree")
    func duplicateUUID() throws {
        var root = SafariPersistenceFixture.propertyList()
        var children = try #require(root["Children"] as? [[String: Any]])
        var folder = children[0]
        var folderChildren = try #require(folder["Children"] as? [[String: Any]])
        folderChildren.append(folderChildren[0])
        folder["Children"] = folderChildren
        children[0] = folder
        root["Children"] = children

        #expect(throws: SafariPersistenceError.invalidStructure(
            .duplicateUUID(SafariPersistenceFixture.bookmarkUUID)
        )) {
            try validator.validate(document(from: root))
        }
    }

    @Test("Every node must carry a UUID")
    func missingUUID() throws {
        var root = SafariPersistenceFixture.propertyList()
        var children = try #require(root["Children"] as? [[String: Any]])
        var folder = children[0]
        folder.removeValue(forKey: "WebBookmarkUUID")
        children[0] = folder
        root["Children"] = children

        #expect(throws: SafariPersistenceError.invalidStructure(.missingUUID(path: [0]))) {
            try validator.validate(document(from: root))
        }
    }

    @Test("A list must contain an array of child nodes")
    func invalidChildren() throws {
        var root = SafariPersistenceFixture.propertyList()
        root["Children"] = "not an array"

        #expect(throws: SafariPersistenceError.invalidStructure(.invalidChildren(path: []))) {
            try validator.validate(document(from: root))
        }
    }

    private func document(from propertyList: [String: Any]) throws -> SafariBookmarkDocument {
        try SafariBookmarkDocument(
            data: SafariPersistenceFixture.data(from: propertyList),
            sourceFingerprint: SafariPersistenceFixture.placeholderFingerprint
        )
    }
}
