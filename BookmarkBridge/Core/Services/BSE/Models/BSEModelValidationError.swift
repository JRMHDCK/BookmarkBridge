//
//  BSEModelValidationError.swift
//  BookmarkBridge
//

import Foundation

/// Structural validation failures for BSE's universal, browser-independent
/// model. Invalid states are rejected before a tree or event can be observed.
nonisolated enum BSEModelValidationError: Error, Equatable, Sendable {
    case bookmarkRequiresURL(LogicalNodeID)
    case folderMustNotHaveURL(LogicalNodeID)
    case invalidPermanentRoot(LogicalNodeID)
    case negativePosition(nodeID: LogicalNodeID, position: Int)
    case duplicateLogicalNodeID(LogicalNodeID)
    case parentNotFound(nodeID: LogicalNodeID, parentID: LogicalNodeID)
    case cycleDetected(LogicalNodeID)
    case rootHasParent(nodeID: LogicalNodeID, parentID: LogicalNodeID)
    case bookmarkCannotBeRoot(LogicalNodeID)
    case invalidEventState(BSEEventKind)
    case eventNodeIdentifierMismatch(expected: LogicalNodeID, actual: LogicalNodeID)
}
