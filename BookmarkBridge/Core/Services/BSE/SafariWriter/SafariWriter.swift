//
//  SafariWriter.swift
//  BookmarkBridge
//

import Foundation

/// Browser-specific mutation surface required by synchronization plans.
/// This boundary is deliberately in-memory only and owns no persistence.
nonisolated protocol SafariWriting: Sendable {
  func createFolder(_ operation: CreateNodeOperation, in document: SafariBookmarkDocument) throws
    -> SafariBookmarkMutationResult
  func deleteFolder(_ operation: DeleteNodeOperation, in document: SafariBookmarkDocument) throws
    -> SafariBookmarkMutationResult
  func createBookmark(_ operation: CreateNodeOperation, in document: SafariBookmarkDocument) throws
    -> SafariBookmarkMutationResult
  func deleteBookmark(_ operation: DeleteNodeOperation, in document: SafariBookmarkDocument) throws
    -> SafariBookmarkMutationResult
  func rename(_ operation: RenameNodeOperation, in document: SafariBookmarkDocument) throws
    -> SafariBookmarkMutationResult
  func updateURL(_ operation: UpdateURLOperation, in document: SafariBookmarkDocument) throws
    -> SafariBookmarkMutationResult
  func move(_ operation: MoveNodeOperation, in document: SafariBookmarkDocument) throws
    -> SafariBookmarkMutationResult
  func reorder(_ operation: ReorderNodeOperation, in document: SafariBookmarkDocument) throws
    -> SafariBookmarkMutationResult
}

nonisolated enum SafariWriterError: Error, Hashable, Sendable {
  case expectedFolder(LogicalNodeID)
  case expectedBookmark(LogicalNodeID)
}

/// Typed facade over the existing pure Safari mutator. It exposes planner
/// operations without creating a path to a store or production transaction.
nonisolated struct SafariWriter: SafariWriting, SafariBookmarkMutating {
  private let mutator: any SafariBookmarkMutating

  init(mutator: SafariBookmarkMutator) {
    self.init(mutator: mutator as any SafariBookmarkMutating)
  }

  init(mutator: any SafariBookmarkMutating) {
    self.mutator = mutator
  }

  func createFolder(_ operation: CreateNodeOperation, in document: SafariBookmarkDocument) throws
    -> SafariBookmarkMutationResult
  {
    guard operation.kind == .folder else {
      throw SafariWriterError.expectedFolder(operation.logicalNodeID)
    }
    return try mutator.apply(.create(operation), to: document)
  }

  func deleteFolder(_ operation: DeleteNodeOperation, in document: SafariBookmarkDocument) throws
    -> SafariBookmarkMutationResult
  {
    try mutator.apply(.delete(operation), to: document)
  }

  func createBookmark(_ operation: CreateNodeOperation, in document: SafariBookmarkDocument) throws
    -> SafariBookmarkMutationResult
  {
    guard operation.kind == .bookmark else {
      throw SafariWriterError.expectedBookmark(operation.logicalNodeID)
    }
    return try mutator.apply(.create(operation), to: document)
  }

  func deleteBookmark(_ operation: DeleteNodeOperation, in document: SafariBookmarkDocument) throws
    -> SafariBookmarkMutationResult
  {
    try mutator.apply(.delete(operation), to: document)
  }

  func rename(_ operation: RenameNodeOperation, in document: SafariBookmarkDocument) throws
    -> SafariBookmarkMutationResult
  {
    try mutator.apply(.rename(operation), to: document)
  }

  func updateURL(_ operation: UpdateURLOperation, in document: SafariBookmarkDocument) throws
    -> SafariBookmarkMutationResult
  {
    try mutator.apply(.updateURL(operation), to: document)
  }

  func move(_ operation: MoveNodeOperation, in document: SafariBookmarkDocument) throws
    -> SafariBookmarkMutationResult
  {
    try mutator.apply(.move(operation), to: document)
  }

  func reorder(_ operation: ReorderNodeOperation, in document: SafariBookmarkDocument) throws
    -> SafariBookmarkMutationResult
  {
    try mutator.apply(.reorder(operation), to: document)
  }

  func apply(
    _ operation: SynchronizationOperation,
    to document: SafariBookmarkDocument
  ) throws -> SafariBookmarkMutationResult {
    switch operation {
    case .create(let operation) where operation.kind == .folder:
      try createFolder(operation, in: document)
    case .create(let operation):
      try createBookmark(operation, in: document)
    case .delete(let operation):
      try deleteBookmark(operation, in: document)
    case .rename(let operation):
      try rename(operation, in: document)
    case .updateURL(let operation):
      try updateURL(operation, in: document)
    case .move(let operation):
      try move(operation, in: document)
    case .reorder(let operation):
      try reorder(operation, in: document)
    case .archive(let operation):
      throw SafariBookmarkMutationError.unsupportedOperation(
        operation.logicalNodeID
      )
    }
  }
}
