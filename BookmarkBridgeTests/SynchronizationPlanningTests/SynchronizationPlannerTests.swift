//
//  SynchronizationPlannerTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@Suite("BSE Synchronization Planner")
struct SynchronizationPlannerTests {
    @Test("An empty diff produces four empty ordered phases")
    func emptyPlan() throws {
        let plan = try PlanningTestSupport.plan(before: [], after: [])

        #expect(plan.phases.count == 4)
        #expect(plan.phases.allSatisfy { $0.operations.isEmpty })
        #expect(plan.operations.isEmpty)
        #expect(plan.report.plannedOperationCount == 0)
        guard case .preparation = plan.phases[0],
              case .structural = plan.phases[1],
              case .content = plan.phases[2],
              case .cleanup = plan.phases[3] else {
            Issue.record("Unexpected phase order")
            return
        }
    }

    @Test("A folder creation preserves its node kind and structural data")
    func folderCreation() throws {
        let created = try PlanningTestSupport.folder(id: 1, title: "Created")
        let plan = try PlanningTestSupport.plan(before: [], after: [created])

        #expect(plan.phases[0].operations == [.create(CreateNodeOperation(
            logicalNodeID: created.logicalNodeID,
            kind: .folder,
            title: "Created",
            url: nil,
            parentID: nil,
            position: 0
        ))])
    }

    @Test("A bookmark creation preserves its node kind, URL, and structure")
    func bookmarkCreation() throws {
        let root = try PlanningTestSupport.folder(id: 1)
        let bookmark = try PlanningTestSupport.bookmark(
            id: 2,
            parent: 1,
            title: "Created bookmark",
            url: "https://created.test",
            position: 0
        )
        let plan = try PlanningTestSupport.plan(
            before: [root],
            after: [root, bookmark]
        )

        #expect(plan.phases[0].operations == [.create(CreateNodeOperation(
            logicalNodeID: bookmark.logicalNodeID,
            kind: .bookmark,
            title: "Created bookmark",
            url: bookmark.url,
            parentID: root.logicalNodeID,
            position: 0
        ))])
    }

    @Test("Created ancestors precede descendants despite inverse lexical identities")
    func nestedCreationDependencyOrder() throws {
        let root = try PlanningTestSupport.folder(id: 100)
        let parent = try PlanningTestSupport.folder(id: 30, parent: 100)
        let child = try PlanningTestSupport.folder(id: 20, parent: 30)
        let bookmark = try PlanningTestSupport.bookmark(id: 10, parent: 20)

        let plan = try PlanningTestSupport.plan(
            before: [root],
            after: [root, parent, child, bookmark]
        )

        #expect(plan.phases[0].operations.map(\.logicalNodeID) == [
            parent.logicalNodeID,
            child.logicalNodeID,
            bookmark.logicalNodeID,
        ])
    }

    @Test("Independent creation trees retain a stable deterministic order")
    func independentCreationTrees() throws {
        let root = try PlanningTestSupport.folder(id: 100)
        let firstParent = try PlanningTestSupport.folder(id: 40, parent: 100)
        let firstChild = try PlanningTestSupport.folder(id: 10, parent: 40)
        let secondParent = try PlanningTestSupport.folder(id: 30, parent: 100)
        let secondChild = try PlanningTestSupport.bookmark(id: 20, parent: 30)
        let after = [root, firstParent, firstChild, secondParent, secondChild]
        let diff = try PlanningTestSupport.diff(before: [root], after: after)
        let reversed = LogicalDiffResult(
            changes: Array(diff.changes.reversed()),
            report: diff.report
        )

        let first = try PlanningTestSupport.plan(diff: diff, before: [root])
        let second = try PlanningTestSupport.plan(diff: reversed, before: [root])

        #expect(first == second)
        #expect(first.phases[0].operations.map(\.logicalNodeID) == [
            secondParent.logicalNodeID,
            secondChild.logicalNodeID,
            firstParent.logicalNodeID,
            firstChild.logicalNodeID,
        ])
    }

    @Test("An existing parent introduces no artificial creation dependency")
    func creationUnderExistingParent() throws {
        let root = try PlanningTestSupport.folder(id: 100)
        let higherIDAtFirstPosition = try PlanningTestSupport.folder(
            id: 20,
            position: 0,
            parent: 100
        )
        let lowerIDAtSecondPosition = try PlanningTestSupport.folder(
            id: 10,
            position: 1,
            parent: 100
        )

        let plan = try PlanningTestSupport.plan(
            before: [root],
            after: [root, higherIDAtFirstPosition, lowerIDAtSecondPosition]
        )

        #expect(plan.phases[0].operations.map(\.logicalNodeID) == [
            higherIDAtFirstPosition.logicalNodeID,
            lowerIDAtSecondPosition.logicalNodeID,
        ])
    }

    @Test("Deletion is planned in cleanup")
    func deletion() throws {
        let deleted = try PlanningTestSupport.folder(id: 1)
        let plan = try PlanningTestSupport.plan(before: [deleted], after: [])

        #expect(plan.phases[3].operations == [.delete(DeleteNodeOperation(
            logicalNodeID: deleted.logicalNodeID
        ))])
    }

    @Test("Permanent-root creation and deletion are rejected explicitly")
    func permanentRootPopulationChangesAreRejected() throws {
        let root = try PlanningTestSupport.folder(
            id: 1,
            permanentRootRole: .primaryBookmarks
        )

        #expect(throws: SynchronizationPlanningError
            .invalidPermanentRootMutation(root.logicalNodeID)) {
            _ = try PlanningTestSupport.plan(before: [], after: [root])
        }
        #expect(throws: SynchronizationPlanningError
            .invalidPermanentRootMutation(root.logicalNodeID)) {
            _ = try PlanningTestSupport.plan(before: [root], after: [])
        }
    }

    @Test("Permanent-root structural and content mutations are rejected explicitly")
    func permanentRootMutationsAreRejected() throws {
        let before = try PlanningTestSupport.folder(
            id: 1,
            title: "Native title",
            permanentRootRole: .primaryBookmarks
        )
        let after = try PlanningTestSupport.folder(
            id: 1,
            title: "Changed title",
            position: 1,
            permanentRootRole: .primaryBookmarks
        )

        #expect(throws: SynchronizationPlanningError
            .invalidPermanentRootMutation(before.logicalNodeID)) {
            _ = try PlanningTestSupport.plan(
                before: [before],
                after: [after]
            )
        }
    }

    @Test("A single bookmark deletion is planned without deleting its parent")
    func bookmarkDeletion() throws {
        let root = try PlanningTestSupport.folder(id: 10)
        let bookmark = try PlanningTestSupport.bookmark(id: 1, parent: 10)

        let plan = try PlanningTestSupport.plan(
            before: [root, bookmark],
            after: [root]
        )

        #expect(plan.phases[3].operations == [.delete(DeleteNodeOperation(
            logicalNodeID: bookmark.logicalNodeID
        ))])
    }

    @Test("A deleted subtree is explicit and ordered children before parents")
    func subtreeDeletionOrder() throws {
        let root = try PlanningTestSupport.folder(id: 10)
        let folder = try PlanningTestSupport.folder(id: 1, parent: 10)
        let subfolder = try PlanningTestSupport.folder(id: 9, parent: 1)
        let bookmark = try PlanningTestSupport.bookmark(id: 2, parent: 9)

        let plan = try PlanningTestSupport.plan(
            before: [root, folder, subfolder, bookmark],
            after: [root]
        )

        #expect(plan.phases[3].operations.map(\.logicalNodeID) == [
            bookmark.logicalNodeID,
            subfolder.logicalNodeID,
            folder.logicalNodeID,
        ])
        #expect(plan.phases[3].operations.count == 3)
        #expect(plan.phases[3].operations.allSatisfy {
            if case .delete = $0 { true } else { false }
        })
    }

    @Test("Independent branches use depth then logical identity")
    func independentBranchDeletionOrder() throws {
        let root = try PlanningTestSupport.folder(id: 20)
        let firstFolder = try PlanningTestSupport.folder(id: 8, parent: 20)
        let firstChild = try PlanningTestSupport.bookmark(id: 7, parent: 8)
        let secondFolder = try PlanningTestSupport.folder(id: 1, parent: 20)
        let secondChild = try PlanningTestSupport.bookmark(id: 9, parent: 1)

        let plan = try PlanningTestSupport.plan(
            before: [root, firstFolder, firstChild, secondFolder, secondChild],
            after: [root]
        )

        #expect(plan.phases[3].operations.map(\.logicalNodeID) == [
            firstChild.logicalNodeID,
            secondChild.logicalNodeID,
            secondFolder.logicalNodeID,
            firstFolder.logicalNodeID,
        ])
    }

    @Test("Equal-depth deletions are ordered by LogicalNodeID")
    func equalDepthDeletionOrder() throws {
        let root = try PlanningTestSupport.folder(id: 10)
        let higherID = try PlanningTestSupport.bookmark(id: 5, parent: 10)
        let lowerID = try PlanningTestSupport.bookmark(id: 2, parent: 10)

        let plan = try PlanningTestSupport.plan(
            before: [root, higherID, lowerID],
            after: [root]
        )

        #expect(plan.phases[3].operations.map(\.logicalNodeID) == [
            lowerID.logicalNodeID,
            higherID.logicalNodeID,
        ])
    }

    @Test("Delete ordering is deterministic for reordered diff input")
    func deterministicDeletionOrder() throws {
        let root = try PlanningTestSupport.folder(id: 10)
        let folder = try PlanningTestSupport.folder(id: 8, parent: 10)
        let child = try PlanningTestSupport.bookmark(id: 1, parent: 8)
        let before = [root, folder, child]
        let diff = try PlanningTestSupport.diff(before: before, after: [root])
        let reversed = LogicalDiffResult(
            changes: Array(diff.changes.reversed()),
            report: diff.report
        )

        let first = try PlanningTestSupport.plan(diff: diff, before: before)
        let second = try PlanningTestSupport.plan(diff: reversed, before: before)

        #expect(first == second)
    }

    @Test("Missing deleted nodes fail explicitly")
    func missingDeletedNode() throws {
        let deleted = try PlanningTestSupport.folder(id: 1)
        let diff = LogicalDiffResult(
            changes: [.deleted(DeletedChange(before: deleted))],
            report: LogicalDiffReport(
                beforeNodeCount: 1,
                afterNodeCount: 0,
                unchangedNodeCount: 0,
                createdCount: 0,
                deletedCount: 1,
                renamedCount: 0,
                urlChangedCount: 0,
                movedCount: 0,
                reorderedCount: 0,
                lifecycleChangedCount: 0
            )
        )

        #expect(throws: SynchronizationPlanningError.missingDeletedNode(
            deleted.logicalNodeID
        )) {
            _ = try PlanningTestSupport.plan(diff: diff, before: [])
        }
    }

    @Test("Depth resolution fails explicitly for a missing parent")
    func missingParentDuringDepthResolution() throws {
        let node = try PlanningTestSupport.bookmark(id: 1, parent: 2)
        var resolver = DeletionDepthResolver(nodes: [node])

        #expect(throws: SynchronizationPlanningError.missingParent(
            logicalNodeID: node.logicalNodeID,
            parentID: PlanningTestSupport.logicalID(2)
        )) {
            _ = try resolver.depth(for: node.logicalNodeID)
        }
    }

    @Test("Depth resolution fails explicitly for a parent cycle")
    func cycleDuringDepthResolution() throws {
        let first = try PlanningTestSupport.folder(id: 1, parent: 2)
        let second = try PlanningTestSupport.folder(id: 2, parent: 1)
        var resolver = DeletionDepthResolver(nodes: [first, second])

        #expect(throws: SynchronizationPlanningError.parentCycle(
            first.logicalNodeID
        )) {
            _ = try resolver.depth(for: first.logicalNodeID)
        }
    }

    @Test("Rename and URL changes are planned independently in content")
    func contentChanges() throws {
        let root = try PlanningTestSupport.folder(id: 1)
        let before = try PlanningTestSupport.bookmark(
            id: 2,
            parent: 1,
            title: "Before",
            url: "https://before.test"
        )
        let after = try PlanningTestSupport.bookmark(
            id: 2,
            parent: 1,
            title: "After",
            url: "https://after.test"
        )
        let plan = try PlanningTestSupport.plan(
            before: [root, before],
            after: [root, after]
        )

        #expect(plan.phases[2].operations == [
            .rename(RenameNodeOperation(
                logicalNodeID: before.logicalNodeID,
                title: "After"
            )),
            .updateURL(UpdateURLOperation(
                logicalNodeID: before.logicalNodeID,
                url: try #require(after.url)
            )),
        ])
    }

    @Test("Move and reorder changes become one complete move destination")
    func structuralChanges() throws {
        let firstParent = try PlanningTestSupport.folder(id: 1)
        let secondParent = try PlanningTestSupport.folder(id: 2)
        let existingChild = try PlanningTestSupport.bookmark(
            id: 4,
            parent: 2,
            position: 0
        )
        let before = try PlanningTestSupport.bookmark(id: 3, parent: 1, position: 0)
        let after = try PlanningTestSupport.bookmark(id: 3, parent: 2, position: 1)
        let plan = try PlanningTestSupport.plan(
            before: [firstParent, secondParent, before, existingChild],
            after: [firstParent, secondParent, after, existingChild]
        )

        #expect(plan.phases[1].operations == [
            .move(MoveNodeOperation(
                logicalNodeID: before.logicalNodeID,
                parentID: secondParent.logicalNodeID,
                position: 1
            )),
        ])
        #expect(plan.report.inputChangeCount == 2)
        #expect(plan.report.plannedOperationCount == 1)
        #expect(plan.report.skippedChangeCount == 0)
    }

    @Test("A move into a newly created parent follows that creation phase")
    func moveToCreatedParent() throws {
        let root = try PlanningTestSupport.folder(id: 100)
        let createdParent = try PlanningTestSupport.folder(id: 20, parent: 100)
        let before = try PlanningTestSupport.bookmark(id: 10, parent: 100)
        let after = try PlanningTestSupport.bookmark(id: 10, parent: 20)

        let plan = try PlanningTestSupport.plan(
            before: [root, before],
            after: [root, createdParent, after]
        )

        #expect(plan.phases[0].operations.map(\.logicalNodeID) == [
            createdParent.logicalNodeID,
        ])
        #expect(plan.phases[1].operations == [.move(MoveNodeOperation(
            logicalNodeID: before.logicalNodeID,
            parentID: createdParent.logicalNodeID,
            position: 0
        ))])
    }

    @Test("A move establishes the position required by a later creation")
    func moveBeforePositionDependentCreation() throws {
        let root = try PlanningTestSupport.folder(id: 100)
        let destination = try PlanningTestSupport.folder(
            id: 10,
            position: 0,
            parent: 100
        )
        let origin = try PlanningTestSupport.folder(
            id: 20,
            position: 1,
            parent: 100
        )
        let movedBefore = try PlanningTestSupport.bookmark(
            id: 30,
            parent: 20,
            position: 0
        )
        let movedAfter = try PlanningTestSupport.bookmark(
            id: 30,
            parent: 10,
            position: 0
        )
        let created = try PlanningTestSupport.bookmark(
            id: 40,
            parent: 10,
            position: 1
        )

        let plan = try PlanningTestSupport.plan(
            before: [root, destination, origin, movedBefore],
            after: [root, destination, origin, movedAfter, created]
        )

        #expect(plan.phases[0].operations.map(\.logicalNodeID) == [
            created.logicalNodeID,
        ])
        #expect(plan.phases[1].operations.map(\.logicalNodeID) == [
            movedBefore.logicalNodeID,
        ])
    }

    @Test("Two moves establish an ordered prefix before a creation")
    func twoMovesBeforePositionDependentCreation() throws {
        let root = try PlanningTestSupport.folder(id: 100)
        let destination = try PlanningTestSupport.folder(id: 10, parent: 100)
        let firstOrigin = try PlanningTestSupport.folder(id: 20, parent: 100)
        let secondOrigin = try PlanningTestSupport.folder(id: 21, parent: 100)
        let firstBefore = try PlanningTestSupport.bookmark(id: 30, parent: 20)
        let secondBefore = try PlanningTestSupport.bookmark(id: 31, parent: 21)
        let firstAfter = try PlanningTestSupport.bookmark(
            id: 30,
            parent: 10,
            position: 0
        )
        let secondAfter = try PlanningTestSupport.bookmark(
            id: 31,
            parent: 10,
            position: 1
        )
        let created = try PlanningTestSupport.bookmark(
            id: 40,
            parent: 10,
            position: 2
        )

        let plan = try PlanningTestSupport.plan(
            before: [
                root,
                destination,
                firstOrigin,
                secondOrigin,
                firstBefore,
                secondBefore,
            ],
            after: [
                root,
                destination,
                firstOrigin,
                secondOrigin,
                firstAfter,
                secondAfter,
                created,
            ]
        )

        #expect(plan.phases[0].operations.map(\.logicalNodeID) == [
            created.logicalNodeID,
        ])
        #expect(plan.phases[1].operations.map(\.logicalNodeID) == [
            firstBefore.logicalNodeID,
            secondBefore.logicalNodeID,
        ])
    }

    @Test("Several creations wait for the moves that make their positions valid")
    func severalCreationsDependOnMoves() throws {
        let root = try PlanningTestSupport.folder(id: 100)
        let destination = try PlanningTestSupport.folder(id: 10, parent: 100)
        let origin = try PlanningTestSupport.folder(id: 20, parent: 100)
        let movedBefore = try PlanningTestSupport.bookmark(id: 30, parent: 20)
        let movedAfter = try PlanningTestSupport.bookmark(
            id: 30,
            parent: 10,
            position: 0
        )
        let firstCreated = try PlanningTestSupport.bookmark(
            id: 40,
            parent: 10,
            position: 1
        )
        let secondCreated = try PlanningTestSupport.bookmark(
            id: 50,
            parent: 10,
            position: 2
        )

        let plan = try PlanningTestSupport.plan(
            before: [root, destination, origin, movedBefore],
            after: [
                root,
                destination,
                origin,
                movedAfter,
                firstCreated,
                secondCreated,
            ]
        )

        #expect(plan.phases[0].operations.map(\.logicalNodeID) == [
            firstCreated.logicalNodeID,
            secondCreated.logicalNodeID,
        ])
        #expect(plan.phases[1].operations.map(\.logicalNodeID) == [
            movedBefore.logicalNodeID,
        ])
    }

    @Test("A later ready move can unlock a blocked created destination")
    func positionSchedulingSkipsBlockedStructuralHead() throws {
        let root = try PlanningTestSupport.folder(id: 100)
        let destination = try PlanningTestSupport.folder(id: 20, parent: 100)
        let firstOrigin = try PlanningTestSupport.folder(id: 30, parent: 100)
        let secondOrigin = try PlanningTestSupport.folder(id: 40, parent: 100)
        let movedToCreatedParentBefore = try PlanningTestSupport.bookmark(
            id: 10,
            parent: 40
        )
        let positionProviderBefore = try PlanningTestSupport.bookmark(
            id: 90,
            parent: 30
        )
        let createdParent = try PlanningTestSupport.folder(
            id: 50,
            position: 1,
            parent: 20
        )
        let positionProviderAfter = try PlanningTestSupport.bookmark(
            id: 90,
            parent: 20,
            position: 0
        )
        let movedToCreatedParentAfter = try PlanningTestSupport.bookmark(
            id: 10,
            parent: 50,
            position: 0
        )

        let plan = try PlanningTestSupport.plan(
            before: [
                root,
                destination,
                firstOrigin,
                secondOrigin,
                movedToCreatedParentBefore,
                positionProviderBefore,
            ],
            after: [
                root,
                destination,
                firstOrigin,
                secondOrigin,
                positionProviderAfter,
                createdParent,
                movedToCreatedParentAfter,
            ]
        )

        #expect(plan.phases[0].operations.map(\.logicalNodeID) == [
            createdParent.logicalNodeID,
        ])
        #expect(plan.phases[1].operations.map(\.logicalNodeID) == [
            movedToCreatedParentBefore.logicalNodeID,
            positionProviderBefore.logicalNodeID,
        ])
    }

    @Test("A projected position gap is normalized to an executable insertion")
    func impossiblePositionDependency() throws {
        let root = try PlanningTestSupport.folder(id: 100)
        let destination = try PlanningTestSupport.folder(id: 10, parent: 100)
        let created = try PlanningTestSupport.bookmark(
            id: 20,
            parent: 10,
            position: 1
        )

        let plan = try PlanningTestSupport.plan(
            before: [root, destination],
            after: [root, destination, created]
        )
        #expect(plan.phases[0].operations == [.create(CreateNodeOperation(
            logicalNodeID: created.logicalNodeID,
            kind: .bookmark,
            title: "Bookmark",
            url: created.url,
            parentID: destination.logicalNodeID,
            position: 0
        ))])
    }

    @Test("Position dependency ordering is independent of diff iteration order")
    func deterministicPositionDependencyOrder() throws {
        let root = try PlanningTestSupport.folder(id: 100)
        let destination = try PlanningTestSupport.folder(id: 10, parent: 100)
        let origin = try PlanningTestSupport.folder(id: 20, parent: 100)
        let movedBefore = try PlanningTestSupport.bookmark(id: 30, parent: 20)
        let movedAfter = try PlanningTestSupport.bookmark(
            id: 30,
            parent: 10,
            position: 0
        )
        let created = try PlanningTestSupport.bookmark(
            id: 40,
            parent: 10,
            position: 1
        )
        let before = [root, destination, origin, movedBefore]
        let diff = try PlanningTestSupport.diff(
            before: before,
            after: [root, destination, origin, movedAfter, created]
        )
        let reversed = LogicalDiffResult(
            changes: Array(diff.changes.reversed()),
            report: diff.report
        )

        let first = try PlanningTestSupport.plan(diff: diff, before: before)
        let second = try PlanningTestSupport.plan(diff: reversed, before: before)

        #expect(first == second)
    }

    @Test("A former descendant detaches before becoming its parent's destination")
    func parentAndDescendantMoveOrder() throws {
        let root = try PlanningTestSupport.folder(id: 100)
        let parentBefore = try PlanningTestSupport.folder(id: 10, parent: 100)
        let childBefore = try PlanningTestSupport.folder(id: 90, parent: 10)
        let parentAfter = try PlanningTestSupport.folder(id: 10, parent: 90)
        let childAfter = try PlanningTestSupport.folder(id: 90, parent: 100)

        let plan = try PlanningTestSupport.plan(
            before: [root, parentBefore, childBefore],
            after: [root, parentAfter, childAfter]
        )

        #expect(plan.phases[1].operations.map(\.logicalNodeID) == [
            childBefore.logicalNodeID,
            parentBefore.logicalNodeID,
        ])
    }

    @Test("A three-move dependency chain is ordered destination ancestors first")
    func chainedMoveDependencies() throws {
        let root = try PlanningTestSupport.folder(id: 100)
        let firstBefore = try PlanningTestSupport.folder(id: 10, parent: 100)
        let secondBefore = try PlanningTestSupport.folder(id: 20, parent: 10)
        let thirdBefore = try PlanningTestSupport.folder(id: 30, parent: 20)
        let firstAfter = try PlanningTestSupport.folder(id: 10, parent: 20)
        let secondAfter = try PlanningTestSupport.folder(id: 20, parent: 30)
        let thirdAfter = try PlanningTestSupport.folder(id: 30, parent: 100)

        let before = [root, firstBefore, secondBefore, thirdBefore]
        let diff = try PlanningTestSupport.diff(
            before: before,
            after: [root, firstAfter, secondAfter, thirdAfter]
        )
        let reversed = LogicalDiffResult(
            changes: Array(diff.changes.reversed()),
            report: diff.report
        )
        let plan = try PlanningTestSupport.plan(diff: diff, before: before)
        let repeated = try PlanningTestSupport.plan(
            diff: reversed,
            before: before
        )

        #expect(plan.phases[1].operations.map(\.logicalNodeID) == [
            thirdBefore.logicalNodeID,
            secondBefore.logicalNodeID,
            firstBefore.logicalNodeID,
        ])
        #expect(plan == repeated)
    }

    @Test("Independent moves preserve the prior LogicalNodeID ordering")
    func independentMovesKeepStableOrder() throws {
        let root = try PlanningTestSupport.folder(id: 100)
        let destination = try PlanningTestSupport.folder(id: 90, parent: 100)
        let firstBefore = try PlanningTestSupport.bookmark(id: 20, parent: 100)
        let secondBefore = try PlanningTestSupport.bookmark(id: 10, parent: 100)
        let firstAfter = try PlanningTestSupport.bookmark(
            id: 20,
            parent: 90,
            position: 1
        )
        let secondAfter = try PlanningTestSupport.bookmark(
            id: 10,
            parent: 90,
            position: 0
        )

        let plan = try PlanningTestSupport.plan(
            before: [root, destination, firstBefore, secondBefore],
            after: [root, destination, firstAfter, secondAfter]
        )

        #expect(plan.phases[1].operations.map(\.logicalNodeID) == [
            secondBefore.logicalNodeID,
            firstBefore.logicalNodeID,
        ])
    }

    @Test("A cyclic move dependency is rejected without a partial plan")
    func impossibleMoveDependency() throws {
        let root = try PlanningTestSupport.folder(id: 100)
        let first = try PlanningTestSupport.folder(id: 10, parent: 100)
        let second = try PlanningTestSupport.folder(id: 20, parent: 100)
        let diff = LogicalDiffResult(
            changes: [
                .moved(MovedChange(
                    logicalNodeID: first.logicalNodeID,
                    before: root.logicalNodeID,
                    after: second.logicalNodeID
                )),
                .moved(MovedChange(
                    logicalNodeID: second.logicalNodeID,
                    before: root.logicalNodeID,
                    after: first.logicalNodeID
                )),
            ],
            report: LogicalDiffReport(
                beforeNodeCount: 3,
                afterNodeCount: 3,
                unchangedNodeCount: 1,
                createdCount: 0,
                deletedCount: 0,
                renamedCount: 0,
                urlChangedCount: 0,
                movedCount: 2,
                reorderedCount: 0,
                lifecycleChangedCount: 0
            )
        )

        #expect(throws: SynchronizationPlanningError
            .unresolvableOperationDependency([
                first.logicalNodeID,
                second.logicalNodeID,
            ])) {
            _ = try PlanningTestSupport.plan(
                diff: diff,
                before: [root, first, second]
            )
        }
    }

    @Test("A move without reorder retains the exact unchanged position")
    func moveWithUnchangedPosition() throws {
        let firstParent = try PlanningTestSupport.folder(id: 1)
        let secondParent = try PlanningTestSupport.folder(id: 2)
        let before = try PlanningTestSupport.bookmark(id: 3, parent: 1, position: 0)
        let after = try PlanningTestSupport.bookmark(id: 3, parent: 2, position: 0)
        let plan = try PlanningTestSupport.plan(
            before: [firstParent, secondParent, before],
            after: [firstParent, secondParent, after]
        )

        #expect(plan.phases[1].operations == [.move(MoveNodeOperation(
            logicalNodeID: before.logicalNodeID,
            parentID: secondParent.logicalNodeID,
            position: 0
        ))])
    }

    @Test("A reorder without a parent change remains a reorder")
    func reorderWithoutMove() throws {
        let parent = try PlanningTestSupport.folder(id: 1)
        let before = try PlanningTestSupport.bookmark(id: 2, parent: 1, position: 0)
        let sibling1 = try PlanningTestSupport.bookmark(id: 3, parent: 1, position: 1)
        let sibling2 = try PlanningTestSupport.bookmark(id: 4, parent: 1, position: 2)
        let sibling3 = try PlanningTestSupport.bookmark(id: 5, parent: 1, position: 3)
        let after = try PlanningTestSupport.bookmark(id: 2, parent: 1, position: 3)
        let afterSibling1 = try PlanningTestSupport.bookmark(
            id: 3, parent: 1, position: 0
        )
        let afterSibling2 = try PlanningTestSupport.bookmark(
            id: 4, parent: 1, position: 1
        )
        let afterSibling3 = try PlanningTestSupport.bookmark(
            id: 5, parent: 1, position: 2
        )
        let plan = try PlanningTestSupport.plan(
            before: [parent, before, sibling1, sibling2, sibling3],
            after: [
                parent,
                after,
                afterSibling1,
                afterSibling2,
                afterSibling3,
            ]
        )

        #expect(plan.phases[1].operations == [.reorder(ReorderNodeOperation(
            logicalNodeID: before.logicalNodeID,
            position: 3
        ))])
    }

    @Test("Sibling reorders become an executable minimal sequence")
    func siblingReordersUseFinalPositionOrder() throws {
        let parent = try PlanningTestSupport.folder(id: 10)
        let first = try PlanningTestSupport.bookmark(
            id: 2,
            parent: 10,
            position: 0
        )
        let second = try PlanningTestSupport.bookmark(
            id: 3,
            parent: 10,
            position: 1
        )
        let third = try PlanningTestSupport.bookmark(
            id: 4,
            parent: 10,
            position: 2
        )
        let reorderedFirst = try PlanningTestSupport.bookmark(
            id: 2,
            parent: 10,
            position: 2
        )
        let reorderedSecond = try PlanningTestSupport.bookmark(
            id: 3,
            parent: 10,
            position: 0
        )
        let reorderedThird = try PlanningTestSupport.bookmark(
            id: 4,
            parent: 10,
            position: 1
        )

        let plan = try PlanningTestSupport.plan(
            before: [parent, first, second, third],
            after: [
                parent,
                reorderedFirst,
                reorderedSecond,
                reorderedThird,
            ]
        )

        #expect(plan.phases[1].operations == [
            .reorder(ReorderNodeOperation(
                logicalNodeID: first.logicalNodeID,
                position: 2
            )),
        ])
    }

    @Test("Reorder targets remain valid until target-only siblings are deleted")
    func reorderWithPendingSiblingDeletion() throws {
        let parent = try PlanningTestSupport.folder(id: 10)
        let first = try PlanningTestSupport.bookmark(
            id: 2,
            parent: 10,
            position: 0
        )
        let deleted = try PlanningTestSupport.bookmark(
            id: 9,
            parent: 10,
            position: 1
        )
        let second = try PlanningTestSupport.bookmark(
            id: 3,
            parent: 10,
            position: 2
        )
        let third = try PlanningTestSupport.bookmark(
            id: 4,
            parent: 10,
            position: 3
        )
        let reorderedFirst = try PlanningTestSupport.bookmark(
            id: 2,
            parent: 10,
            position: 2
        )
        let reorderedSecond = try PlanningTestSupport.bookmark(
            id: 3,
            parent: 10,
            position: 0
        )
        let reorderedThird = try PlanningTestSupport.bookmark(
            id: 4,
            parent: 10,
            position: 1
        )

        let plan = try PlanningTestSupport.plan(
            before: [parent, first, deleted, second, third],
            after: [
                parent,
                reorderedFirst,
                reorderedSecond,
                reorderedThird,
            ]
        )

        #expect(plan.phases[1].operations == [
            .reorder(ReorderNodeOperation(
                logicalNodeID: first.logicalNodeID,
                position: 3
            )),
        ])
        #expect(plan.phases[3].operations == [
            .delete(DeleteNodeOperation(
                logicalNodeID: deleted.logicalNodeID
            )),
        ])
    }

    @Test("Move destination consolidation is independent of diff ordering")
    func deterministicMoveDestination() throws {
        let firstParent = try PlanningTestSupport.folder(id: 1)
        let secondParent = try PlanningTestSupport.folder(id: 2)
        let before = try PlanningTestSupport.bookmark(id: 3, parent: 1, position: 0)
        let after = try PlanningTestSupport.bookmark(id: 3, parent: 2, position: 0)
        let beforeNodes = [firstParent, secondParent, before]
        let diff = try PlanningTestSupport.diff(
            before: beforeNodes,
            after: [firstParent, secondParent, after]
        )
        let reversed = LogicalDiffResult(
            changes: Array(diff.changes.reversed()),
            report: diff.report
        )

        let first = try PlanningTestSupport.plan(diff: diff, before: beforeNodes)
        let second = try PlanningTestSupport.plan(diff: reversed, before: beforeNodes)

        #expect(first == second)
        #expect(first.phases[1].operations.count == 1)
    }

    @Test("A move without its before node cannot invent a target position")
    func moveMissingBeforeNode() throws {
        let logicalNodeID = PlanningTestSupport.logicalID(3)
        let diff = LogicalDiffResult(
            changes: [.moved(MovedChange(
                logicalNodeID: logicalNodeID,
                before: PlanningTestSupport.logicalID(1),
                after: PlanningTestSupport.logicalID(2)
            ))],
            report: LogicalDiffReport(
                beforeNodeCount: 1,
                afterNodeCount: 1,
                unchangedNodeCount: 0,
                createdCount: 0,
                deletedCount: 0,
                renamedCount: 0,
                urlChangedCount: 0,
                movedCount: 1,
                reorderedCount: 0,
                lifecycleChangedCount: 0
            )
        )

        #expect(throws: SynchronizationPlanningError.invalidLogicalDiff) {
            _ = try PlanningTestSupport.plan(diff: diff, before: [])
        }
    }

    @Test("Archived lifecycle is planned in cleanup")
    func archival() throws {
        let before = try PlanningTestSupport.folder(
            id: 1,
            lifecycle: .registered(.active)
        )
        let after = try PlanningTestSupport.folder(
            id: 1,
            lifecycle: .registered(.archived)
        )
        let plan = try PlanningTestSupport.plan(before: [before], after: [after])

        #expect(plan.phases[3].operations == [.archive(ArchiveNodeOperation(
            logicalNodeID: before.logicalNodeID,
            state: .archived
        ))])
    }

    @Test("Deleted lifecycle is deleted, archived, or rejected exactly as policy requests")
    func deletedLifecyclePolicy() throws {
        let before = try PlanningTestSupport.folder(
            id: 1,
            lifecycle: .registered(.active)
        )
        let after = try PlanningTestSupport.folder(
            id: 1,
            lifecycle: .registered(.deleted)
        )
        let diff = try PlanningTestSupport.diff(before: [before], after: [after])
        let deletePlan = try PlanningTestSupport.plan(
            diff: diff,
            before: [before],
            policy: SynchronizationPolicy(
                direction: PlanningTestSupport.direction,
                changeSelection: .allChanges,
                deletedLifecycleHandling: .delete
            )
        )
        let archivePlan = try PlanningTestSupport.plan(
            diff: diff,
            before: [before],
            policy: SynchronizationPolicy(
                direction: PlanningTestSupport.direction,
                changeSelection: .allChanges,
                deletedLifecycleHandling: .archive
            )
        )

        #expect(deletePlan.phases[3].operations == [.delete(DeleteNodeOperation(
            logicalNodeID: before.logicalNodeID
        ))])
        #expect(archivePlan.phases[3].operations == [.archive(ArchiveNodeOperation(
            logicalNodeID: before.logicalNodeID,
            state: .archived
        ))])
        #expect(throws: SynchronizationPlanningError.unsupportedChange(
            before.logicalNodeID
        )) {
            _ = try PlanningTestSupport.plan(
                diff: diff,
                before: [before],
                policy: SynchronizationPolicy(
                    direction: PlanningTestSupport.direction,
                    changeSelection: .allChanges,
                    deletedLifecycleHandling: .reject
                )
            )
        }
    }

    @Test("Several changes on one node remain atomic and phase ordered")
    func severalChangesOnOneNode() throws {
        let firstParent = try PlanningTestSupport.folder(id: 1)
        let secondParent = try PlanningTestSupport.folder(id: 2)
        let before = try PlanningTestSupport.bookmark(
            id: 3,
            parent: 1,
            title: "Before"
        )
        let after = try PlanningTestSupport.bookmark(
            id: 3,
            parent: 2,
            title: "After"
        )
        let plan = try PlanningTestSupport.plan(
            before: [firstParent, secondParent, before],
            after: [firstParent, secondParent, after]
        )

        #expect(plan.operations.map(\.logicalNodeID) == [
            before.logicalNodeID,
            before.logicalNodeID,
        ])
        #expect(plan.report.structuralOperationCount == 1)
        #expect(plan.report.contentOperationCount == 1)
    }

    @Test("Policies select all, additions, or content deterministically")
    func policies() throws {
        let before = try PlanningTestSupport.folder(id: 2, title: "Before")
        let renamed = try PlanningTestSupport.folder(id: 2, title: "After")
        let created = try PlanningTestSupport.folder(id: 1)
        let diff = try PlanningTestSupport.diff(
            before: [before],
            after: [renamed, created]
        )

        let all = try PlanningTestSupport.plan(
            diff: diff,
            before: [before],
            policy: .allChanges(direction: PlanningTestSupport.direction)
        )
        let additions = try PlanningTestSupport.plan(
            diff: diff,
            before: [before],
            policy: .additionsOnly(direction: PlanningTestSupport.direction)
        )
        let content = try PlanningTestSupport.plan(
            diff: diff,
            before: [before],
            policy: .contentOnly(direction: PlanningTestSupport.direction)
        )

        #expect(all.operations.count == 2)
        #expect(additions.operations.count == 1)
        #expect(content.operations.count == 1)
        #expect(additions.report.skippedChangeCount == 1)
        #expect(content.report.skippedChangeCount == 1)
        if case .create = additions.operations[0] {} else {
            Issue.record("Additions-only policy emitted a non-create operation")
        }
        if case .rename = content.operations[0] {} else {
            Issue.record("Content-only policy emitted a non-content operation")
        }
    }

    @Test("Input change order cannot affect operation order")
    func deterministicOrder() throws {
        let before = try PlanningTestSupport.folder(id: 2, title: "Before")
        let after = try PlanningTestSupport.folder(id: 2, title: "After")
        let created = try PlanningTestSupport.folder(id: 1)
        let diff = try PlanningTestSupport.diff(
            before: [before],
            after: [after, created]
        )
        let reversed = LogicalDiffResult(
            changes: Array(diff.changes.reversed()),
            report: diff.report
        )

        let first = try PlanningTestSupport.plan(diff: diff, before: [before])
        let second = try PlanningTestSupport.plan(
            diff: reversed,
            before: [before]
        )

        #expect(first == second)
    }

    @Test("A reactivation is explicit and unsupported by the operation contract")
    func unsupportedLifecycleChange() throws {
        let logicalNodeID = PlanningTestSupport.logicalID(1)
        let change = LogicalChange.lifecycleChanged(LifecycleChangedChange(
            logicalNodeID: logicalNodeID,
            before: .registered(.archived),
            after: .registered(.active)
        ))
        let diff = LogicalDiffResult(
            changes: [change],
            report: PlanningTestSupport.report(lifecycleChangedCount: 1)
        )

        #expect(throws: SynchronizationPlanningError.unsupportedChange(logicalNodeID)) {
            _ = try PlanningTestSupport.plan(diff: diff)
        }
    }

    @Test("A diff whose report disagrees with its changes is rejected")
    func invalidLogicalDiff() throws {
        let diff = LogicalDiffResult(changes: [], report: PlanningTestSupport.report(
            createdCount: 1
        ))

        #expect(throws: SynchronizationPlanningError.invalidLogicalDiff) {
            _ = try PlanningTestSupport.plan(diff: diff)
        }
    }

    @Test("Contradictory operations for one identity are rejected")
    func inconsistentPlan() throws {
        let node = try PlanningTestSupport.folder(id: 1)
        let diff = LogicalDiffResult(
            changes: [
                .created(CreatedChange(after: node)),
                .deleted(DeletedChange(before: node)),
            ],
            report: LogicalDiffReport(
                beforeNodeCount: 1,
                afterNodeCount: 1,
                unchangedNodeCount: 0,
                createdCount: 1,
                deletedCount: 1,
                renamedCount: 0,
                urlChangedCount: 0,
                movedCount: 0,
                reorderedCount: 0,
                lifecycleChangedCount: 0
            )
        )

        #expect(throws: SynchronizationPlanningError.inconsistentPlan) {
            _ = try PlanningTestSupport.plan(diff: diff, before: [node])
        }
    }

    @Test("Planner and models satisfy Swift Concurrency boundaries")
    func strictConcurrency() throws {
        let before = try PlanningTestSupport.graph(nodes: [])
        let diff = try PlanningTestSupport.diff(before: [], after: [])
        let request = SynchronizationPlanningRequest(
            before: before,
            logicalDiff: diff,
            policy: .allChanges(direction: PlanningTestSupport.direction)
        )
        let plan = try SynchronizationPlanner().plan(request: request)

        requireSendable(SynchronizationPlanner())
        requireSendable(request)
        requireSendable(plan)
        requireSendable(plan.phases)
        requireSendable(plan.operations)
    }

    private func requireSendable<T: Sendable>(_ value: T) { _ = value }

    @Test("Consistency validation identifies the first invalid insertion")
    func consistencyValidationFindsFirstDivergence() throws {
        let root = try PlanningTestSupport.folder(id: 100)
        let destination = try PlanningTestSupport.folder(id: 10, parent: 100)
        let origin = try PlanningTestSupport.folder(id: 20, parent: 100)
        let movedBefore = try PlanningTestSupport.bookmark(id: 30, parent: 20)
        let movedAfter = try PlanningTestSupport.bookmark(
            id: 30, parent: 10, position: 0
        )
        let created = try PlanningTestSupport.bookmark(
            id: 40, parent: 10, position: 1
        )
        let beforeNodes = [root, destination, origin, movedBefore]
        let afterNodes = [root, destination, origin, movedAfter, created]
        let request = SynchronizationPlanningRequest(
            before: try PlanningTestSupport.graph(nodes: beforeNodes),
            logicalDiff: try PlanningTestSupport.diff(
                before: beforeNodes,
                after: afterNodes
            ),
            policy: .allChanges(direction: PlanningTestSupport.direction)
        )
        let invalidCreation = SynchronizationOperation.create(
            CreateNodeOperation(
                logicalNodeID: created.logicalNodeID,
                kind: .bookmark,
                title: "Bookmark",
                url: created.url,
                parentID: destination.logicalNodeID,
                position: 1
            )
        )
        let legacyPlan = SynchronizationPlan(
            phases: [
                .preparation([invalidCreation]),
                .structural([.move(MoveNodeOperation(
                    logicalNodeID: movedBefore.logicalNodeID,
                    parentID: destination.logicalNodeID,
                    position: 0
                ))]),
                .content([]),
                .cleanup([]),
            ],
            report: SynchronizationPlanningReport(
                policy: request.policy,
                inputChangeCount: request.logicalDiff.changes.count,
                plannedOperationCount: 2,
                skippedChangeCount: 0,
                preparationOperationCount: 1,
                structuralOperationCount: 1,
                contentOperationCount: 0,
                cleanupOperationCount: 0
            )
        )

        #expect(throws: SynchronizationPlanningError.executionPlanDiverged(
            operationIndex: 0,
            logicalNodeID: created.logicalNodeID
        )) {
            try SynchronizationPlanConsistencyValidator().validate(
                plan: legacyPlan,
                request: request
            )
        }
    }

    @Test("Created nodes are positioned by reordering surviving siblings")
    func createdNodeIsNotReordered() throws {
        let root = try PlanningTestSupport.folder(id: 100)
        let firstBefore = try PlanningTestSupport.bookmark(
            id: 1,
            parent: 100,
            position: 0
        )
        let secondBefore = try PlanningTestSupport.bookmark(
            id: 2,
            parent: 100,
            position: 1
        )
        let secondAfter = try PlanningTestSupport.bookmark(
            id: 2,
            parent: 100,
            position: 0
        )
        let firstAfter = try PlanningTestSupport.bookmark(
            id: 1,
            parent: 100,
            position: 1
        )
        let created = try PlanningTestSupport.bookmark(
            id: 3,
            parent: 100,
            position: 2
        )

        let plan = try PlanningTestSupport.plan(
            before: [root, firstBefore, secondBefore],
            after: [root, secondAfter, firstAfter, created]
        )

        #expect(plan.operations.map(\.kind) == [.create, .reorder])
        #expect(plan.operations[1].logicalNodeID == secondBefore.logicalNodeID)
        #expect(
            plan.operations.filter {
                $0.logicalNodeID == created.logicalNodeID
            }.map(\.kind) == [.create]
        )
    }
}

private enum PlanningTestSupport {
    static var direction: SynchronizationDirection {
        .oneWay(source: sourceID(900), target: sourceID(901))
    }

    static let emptyGraphReport = LogicalStateBuildingReport(
        baselineIdentityCount: 0,
        snapshotCount: 0,
        snapshotNodeCount: 0,
        logicalNodeCount: 0,
        structurallyAvailableNodeCount: 0,
        baselineOnlyNodeCount: 0,
        unregisteredNodeCount: 0,
        observationCount: 0
    )

    static func plan(
        before: [LogicalNodeState],
        after: [LogicalNodeState],
        policy: SynchronizationPolicy = .allChanges(direction: direction)
    ) throws -> SynchronizationPlan {
        let beforeGraph = try graph(nodes: before)
        let afterGraph = try graph(nodes: after)
        let diff = try LogicalDiffEngine().diff(request: LogicalDiffRequest(
            before: beforeGraph,
            after: afterGraph
        ))
        return try SynchronizationPlanner().plan(
            request: SynchronizationPlanningRequest(
                before: beforeGraph,
                logicalDiff: diff,
                policy: policy
            )
        )
    }

    static func plan(
        diff: LogicalDiffResult,
        before: [LogicalNodeState] = [],
        policy: SynchronizationPolicy = .allChanges(direction: direction)
    ) throws -> SynchronizationPlan {
        try SynchronizationPlanner().plan(request: SynchronizationPlanningRequest(
            before: graph(nodes: before),
            logicalDiff: diff,
            policy: policy
        ))
    }

    static func diff(
        before: [LogicalNodeState],
        after: [LogicalNodeState]
    ) throws -> LogicalDiffResult {
        try LogicalDiffEngine().diff(request: LogicalDiffRequest(
            before: graph(nodes: before),
            after: graph(nodes: after)
        ))
    }

    static func graph(
        nodes: [LogicalNodeState]
    ) throws -> LogicalStateGraph {
        try LogicalStateGraph(nodes: nodes, report: emptyGraphReport)
    }

    static func report(
        createdCount: Int = 0,
        lifecycleChangedCount: Int = 0
    ) -> LogicalDiffReport {
        LogicalDiffReport(
            beforeNodeCount: 0,
            afterNodeCount: 0,
            unchangedNodeCount: 0,
            createdCount: createdCount,
            deletedCount: 0,
            renamedCount: 0,
            urlChangedCount: 0,
            movedCount: 0,
            reorderedCount: 0,
            lifecycleChangedCount: lifecycleChangedCount
        )
    }

    static func folder(
        id: Int,
        title: String = "Folder",
        position: Int = 0,
        parent: Int? = nil,
        permanentRootRole: PermanentRootRole? = nil,
        lifecycle: LogicalNodeLifecycle = .unregistered
    ) throws -> LogicalNodeState {
        try LogicalNodeState(
            logicalNodeID: logicalID(id),
            kind: .folder,
            permanentRootRole: permanentRootRole,
            title: title,
            url: nil,
            parentID: parent.map(logicalID),
            position: position,
            lifecycle: lifecycle,
            observations: []
        )
    }

    static func bookmark(
        id: Int,
        parent: Int,
        title: String = "Bookmark",
        url: String = "https://example.test",
        position: Int = 0
    ) throws -> LogicalNodeState {
        try LogicalNodeState(
            logicalNodeID: logicalID(id),
            kind: .bookmark,
            title: title,
            url: URL(string: url),
            parentID: logicalID(parent),
            position: position,
            lifecycle: .unregistered,
            observations: []
        )
    }

    static func logicalID(_ value: Int) -> LogicalNodeID {
        LogicalNodeID(UUID(uuidString: String(
            format: "00000000-0000-0000-0000-%012d",
            value
        ))!)
    }

    static func sourceID(_ value: Int) -> BSESourceID {
        BSESourceID(UUID(uuidString: String(
            format: "10000000-0000-0000-0000-%012d",
            value
        ))!)
    }
}
