//
//  IdentityMatchingGroupBuilderTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Identity Matching Group Builder")
struct IdentityMatchingGroupBuilderTests {
    @Test("Ordinary folders match by their exact path below homologous roots")
    func matchesFoldersByExactRootedPath() throws {
        let sourceID = matchingGroupSourceID(1)
        let targetID = matchingGroupSourceID(2)
        let sourceFolderID = matchingGroupNodeID(2)
        let targetFolderID = matchingGroupNodeID(12)
        let snapshots = try [
            matchingGroupSnapshot(
                sourceID: sourceID,
                rootID: matchingGroupNodeID(1),
                folderID: sourceFolderID,
                bookmarks: []
            ),
            matchingGroupSnapshot(
                sourceID: targetID,
                rootID: matchingGroupNodeID(11),
                folderID: targetFolderID,
                bookmarks: []
            ),
        ]

        let groups = try DefaultIdentityMatchingGroupBuilder().build(
            baseline: try Baseline.empty(
                baselineID: BaselineID(matchingGroupUUID(899))
            ),
            snapshots: snapshots,
            matchingEngine: MatchingEngine()
        )
        let group = try #require(groups.first {
            $0.members.contains(IdentityNodeReference(
                sourceID: sourceID,
                provisionalLogicalID: sourceFolderID
            ))
        })

        #expect(group.matchingResult == .match(
            candidateID: targetFolderID,
            reason: .sameFolderPath
        ))
        #expect(group.members.contains(IdentityNodeReference(
            sourceID: targetID,
            provisionalLogicalID: targetFolderID
        )))
    }

    @Test("A unique title and ancestor path disambiguate duplicate URLs")
    func disambiguatesDuplicateURLsByExactStructure() throws {
        let sourceID = matchingGroupSourceID(1)
        let targetID = matchingGroupSourceID(2)
        let sourceBookmarkID = matchingGroupNodeID(3)
        let matchingTargetID = matchingGroupNodeID(13)
        let otherTargetID = matchingGroupNodeID(14)
        let snapshots = try [
            matchingGroupSnapshot(
                sourceID: sourceID,
                rootID: matchingGroupNodeID(1),
                rootTitle: "Safari Bookmarks",
                folderID: matchingGroupNodeID(2),
                bookmarks: [
                    (sourceBookmarkID, "Guide", "https://example.test"),
                ]
            ),
            matchingGroupSnapshot(
                sourceID: targetID,
                rootID: matchingGroupNodeID(11),
                rootTitle: "Chrome Bookmarks Bar",
                folderID: matchingGroupNodeID(12),
                bookmarks: [
                    (matchingTargetID, "Guide", "https://example.test"),
                    (otherTargetID, "Archive", "https://example.test"),
                ]
            ),
        ]

        let groups = try DefaultIdentityMatchingGroupBuilder().build(
            baseline: try Baseline.empty(
                baselineID: BaselineID(matchingGroupUUID(900))
            ),
            snapshots: snapshots,
            matchingEngine: MatchingEngine()
        )
        let group = try #require(groups.first {
            $0.members.contains(IdentityNodeReference(
                sourceID: sourceID,
                provisionalLogicalID: sourceBookmarkID
            ))
        })

        #expect(group.matchingResult == .match(
            candidateID: matchingTargetID,
            reason: .sameBookmarkURLAndStructure
        ))
        #expect(group.members.contains(IdentityNodeReference(
            sourceID: targetID,
            provisionalLogicalID: matchingTargetID
        )))
        #expect(groups.contains {
            $0.members == [IdentityNodeReference(
                sourceID: targetID,
                provisionalLogicalID: otherTargetID
            )]
        })
    }

    @Test("Indistinguishable duplicate URLs remain ambiguous")
    func preservesTrueStructuralAmbiguity() throws {
        let sourceID = matchingGroupSourceID(1)
        let targetID = matchingGroupSourceID(2)
        let sourceBookmarkID = matchingGroupNodeID(3)
        let firstTargetID = matchingGroupNodeID(13)
        let secondTargetID = matchingGroupNodeID(14)
        let snapshots = try [
            matchingGroupSnapshot(
                sourceID: sourceID,
                rootID: matchingGroupNodeID(1),
                folderID: matchingGroupNodeID(2),
                bookmarks: [
                    (sourceBookmarkID, "Guide", "https://example.test"),
                ]
            ),
            matchingGroupSnapshot(
                sourceID: targetID,
                rootID: matchingGroupNodeID(11),
                folderID: matchingGroupNodeID(12),
                bookmarks: [
                    (firstTargetID, "Guide", "https://example.test"),
                    (secondTargetID, "Guide", "https://example.test"),
                ]
            ),
        ]

        let groups = try DefaultIdentityMatchingGroupBuilder().build(
            baseline: try Baseline.empty(
                baselineID: BaselineID(matchingGroupUUID(901))
            ),
            snapshots: snapshots,
            matchingEngine: MatchingEngine()
        )
        let group = try #require(groups.first {
            $0.members.contains(IdentityNodeReference(
                sourceID: sourceID,
                provisionalLogicalID: sourceBookmarkID
            ))
        })

        #expect(group.matchingResult == .ambiguous(
            candidateIDs: [firstTargetID, secondTargetID].sorted(),
            reason: .ambiguousCandidates(count: 2)
        ))
    }
}

private func matchingGroupSnapshot(
    sourceID: BSESourceID,
    rootID: LogicalNodeID,
    rootTitle: String = "Bookmarks",
    folderID: LogicalNodeID,
    bookmarks: [(LogicalNodeID, String, String)]
) throws -> BSESnapshot {
    let root = try BSENode(
        logicalID: rootID,
        kind: .folder,
        permanentRootRole: .primaryBookmarks,
        title: rootTitle,
        position: 0
    )
    let folder = try BSENode(
        logicalID: folderID,
        kind: .folder,
        title: "Work",
        parentID: rootID,
        position: 0
    )
    let bookmarkNodes = try bookmarks.enumerated().map {
        index, bookmark in
        try BSENode(
            logicalID: bookmark.0,
            kind: .bookmark,
            title: bookmark.1,
            parentID: folderID,
            position: index,
            url: URL(string: bookmark.2)
        )
    }
    return BSESnapshot(
        source: sourceID,
        capturedAt: Date(timeIntervalSince1970: 1),
        tree: try BSETree(nodes: [root, folder] + bookmarkNodes)
    )
}

private func matchingGroupSourceID(_ value: Int) -> BSESourceID {
    BSESourceID(matchingGroupUUID(value))
}

private func matchingGroupNodeID(_ value: Int) -> LogicalNodeID {
    LogicalNodeID(matchingGroupUUID(value + 100))
}

private func matchingGroupUUID(_ value: Int) -> UUID {
    UUID(uuidString: String(
        format: "FA500000-0000-0000-0000-%012d",
        value
    ))!
}
