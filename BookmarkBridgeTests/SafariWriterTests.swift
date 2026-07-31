//
//  SafariWriterTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Synchronization
import Testing

@testable import BookmarkBridge

@Suite("Safari writer infrastructure")
struct SafariWriterTests {
  @Test("The API delegates every planner mutation without persistence")
  func delegatesPlannerOperations() throws {
    let document = try makeDocument()
    let recorder = SafariWriterRecorder()
    let writer = SafariWriter(
      mutator: RecordingSafariMutator(recorder: recorder)
    )
    let nodeID = logicalID(1)
    let parentID = logicalID(2)
    let folder = CreateNodeOperation(
      logicalNodeID: nodeID,
      kind: .folder,
      title: "Folder",
      url: nil,
      parentID: parentID,
      position: 0
    )
    let bookmark = CreateNodeOperation(
      logicalNodeID: nodeID,
      kind: .bookmark,
      title: "Bookmark",
      url: URL(string: "https://example.com")!,
      parentID: parentID,
      position: 0
    )
    let deletion = DeleteNodeOperation(logicalNodeID: nodeID)
    let rename = RenameNodeOperation(
      logicalNodeID: nodeID,
      title: "Renamed"
    )
    let updateURL = UpdateURLOperation(
      logicalNodeID: nodeID,
      url: URL(string: "https://example.com/updated")!
    )
    let move = MoveNodeOperation(
      logicalNodeID: nodeID,
      parentID: parentID,
      position: 1
    )
    let reorder = ReorderNodeOperation(
      logicalNodeID: nodeID,
      position: 2
    )

    _ = try writer.createFolder(folder, in: document)
    _ = try writer.deleteFolder(deletion, in: document)
    _ = try writer.createBookmark(bookmark, in: document)
    _ = try writer.deleteBookmark(deletion, in: document)
    _ = try writer.rename(rename, in: document)
    _ = try writer.updateURL(updateURL, in: document)
    _ = try writer.move(move, in: document)
    _ = try writer.reorder(reorder, in: document)

    #expect(
      recorder.operations == [
        .create(folder),
        .delete(deletion),
        .create(bookmark),
        .delete(deletion),
        .rename(rename),
        .updateURL(updateURL),
        .move(move),
        .reorder(reorder),
      ])
  }

  @Test("Typed creation methods reject the wrong node kind")
  func validatesCreationKinds() throws {
    let document = try makeDocument()
    let recorder = SafariWriterRecorder()
    let writer = SafariWriter(
      mutator: RecordingSafariMutator(recorder: recorder)
    )
    let nodeID = logicalID(1)
    let bookmark = CreateNodeOperation(
      logicalNodeID: nodeID,
      kind: .bookmark,
      title: "Bookmark",
      url: URL(string: "https://example.com")!,
      parentID: nil,
      position: 0
    )

    #expect(throws: SafariWriterError.expectedFolder(nodeID)) {
      _ = try writer.createFolder(bookmark, in: document)
    }
    #expect(recorder.operations.isEmpty)
  }

  private func makeDocument() throws -> SafariBookmarkDocument {
    let data = try PropertyListSerialization.data(
      fromPropertyList: [
        "WebBookmarkType": "WebBookmarkTypeList",
        "WebBookmarkUUID": "root",
        "Title": "Root",
        "Children": [],
      ],
      format: .binary,
      options: 0
    )
    return try SafariBookmarkDocument(
      data: data,
      sourceFingerprint: SafariDocumentFingerprint(
        contentDigest: SafariDocumentFingerprint.digest(of: data),
        fileSize: UInt64(data.count),
        modificationDate: .distantPast,
        fileSystemNumber: 1,
        fileNumber: 1
      )
    )
  }

  private func logicalID(_ value: UInt8) -> LogicalNodeID {
    LogicalNodeID(
      UUID(
        uuid: (
          0, 0, 0, 0, 0, 0, 0, 0,
          0, 0, 0, 0, 0, 0, 0, value
        )))
  }
}

private final class SafariWriterRecorder: @unchecked Sendable {
  private let storage = Mutex<[SynchronizationOperation]>([])

  var operations: [SynchronizationOperation] {
    storage.withLock { $0 }
  }

  func append(_ operation: SynchronizationOperation) {
    storage.withLock { $0.append(operation) }
  }
}

nonisolated private struct RecordingSafariMutator: SafariBookmarkMutating {
  let recorder: SafariWriterRecorder

  func apply(
    _ operation: SynchronizationOperation,
    to document: SafariBookmarkDocument
  ) throws -> SafariBookmarkMutationResult {
    recorder.append(operation)
    return SafariBookmarkMutationResult(
      document: document,
      nativeIdentityChanges: []
    )
  }
}
