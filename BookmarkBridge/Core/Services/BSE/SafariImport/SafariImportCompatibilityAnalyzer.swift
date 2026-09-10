//
//  SafariImportCompatibilityAnalyzer.swift
//  BookmarkBridge
//

import Foundation

nonisolated enum SafariImportIncompatibilityReason: String, Hashable, Sendable {
    case deletion
    case rename
    case move
    case reorder
    case archive
    case urlUpdate
    case missingBookmarkURL
    case unsupportedURLScheme
}

nonisolated struct SafariImportIncompatibility: Hashable, Sendable {
    let logicalNodeID: LogicalNodeID
    let reason: SafariImportIncompatibilityReason
}

nonisolated struct SafariImportCompatibilityReport: Hashable, Sendable {
    let supportedOperationCount: Int
    let incompatibilities: [SafariImportIncompatibility]

    var isCompatible: Bool { incompatibilities.isEmpty }
}

/// Classifies synchronization operations against behavior verified through
/// Safari's supported HTML importer. The importer is additive: it can create
/// folders and bookmarks but cannot safely express updates, deletions, moves,
/// renames, or reorder operations.
nonisolated struct SafariImportCompatibilityAnalyzer: Sendable {
    func analyze(_ plan: SynchronizationPlan) -> SafariImportCompatibilityReport {
        var supportedOperationCount = 0
        var incompatibilities: [SafariImportIncompatibility] = []

        for operation in plan.operations {
            if let reason = incompatibilityReason(for: operation) {
                incompatibilities.append(SafariImportIncompatibility(
                    logicalNodeID: operation.logicalNodeID,
                    reason: reason
                ))
            } else {
                supportedOperationCount += 1
            }
        }

        return SafariImportCompatibilityReport(
            supportedOperationCount: supportedOperationCount,
            incompatibilities: incompatibilities
        )
    }

    func supports(_ operation: SynchronizationOperation) -> Bool {
        incompatibilityReason(for: operation) == nil
    }

    func supports(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), !scheme.isEmpty else {
            return false
        }
        return scheme != "chrome"
            && scheme != "chrome-extension"
            && scheme != "about"
    }

    private func incompatibilityReason(
        for operation: SynchronizationOperation
    ) -> SafariImportIncompatibilityReason? {
        switch operation {
        case .create(let creation):
            guard creation.kind == .bookmark else { return nil }
            guard let url = creation.url else { return .missingBookmarkURL }
            return supports(url) ? nil : .unsupportedURLScheme
        case .updateURL(let update):
            return supports(update.url) ? .urlUpdate : .unsupportedURLScheme
        case .delete:
            return .deletion
        case .rename:
            return .rename
        case .move:
            return .move
        case .reorder:
            return .reorder
        case .archive:
            return .archive
        }
    }
}
