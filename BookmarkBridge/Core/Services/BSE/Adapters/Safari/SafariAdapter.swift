//
//  SafariAdapter.swift
//  BookmarkBridge
//

import Foundation

/// Read-only BSE adapter for exactly one local Safari bookmark source.
nonisolated struct SafariAdapter: BSEAdapter {
    let sourceID: BSESourceID
    let capabilities = BSEAdapterCapabilities(
        canRead: true,
        canWrite: false,
        canCreate: false,
        canDelete: false,
        canMove: false,
        canRename: false,
        canVerify: false,
        canCreateRestorePoint: false,
        canRestore: false
    )

    private let dataSource: any SafariDataSource
    private let transformer: SafariSnapshotTransformer
    private let monotonicTime: @Sendable () -> TimeInterval

    init(
        sourceID: BSESourceID,
        dataSource: any SafariDataSource,
        transformer: SafariSnapshotTransformer = SafariSnapshotTransformer(),
        monotonicTime: @escaping @Sendable () -> TimeInterval = {
            ProcessInfo.processInfo.systemUptime
        }
    ) {
        self.sourceID = sourceID
        self.dataSource = dataSource
        self.transformer = transformer
        self.monotonicTime = monotonicTime
    }

    func checkPermissions() async -> BSEAdapterPermissionStatus {
        await dataSource.checkPermissions()
    }

    func checkCompatibility() async -> BSEAdapterCompatibility {
        await dataSource.checkCompatibility()
    }

    func readSnapshot() async throws -> BSESnapshot {
        try await read().snapshot
    }

    /// Performs one extraction and one pure transformation, returning optional
    /// Safari diagnostics beside (never inside) the resulting snapshot.
    func read() async throws -> SafariReadResult {
        let startedAt = monotonicTime()
        let extraction = try await dataSource.extract()
        let transformed = try transformer.transform(extraction, sourceID: sourceID)
        let duration = max(0, monotonicTime() - startedAt)
        let report = SafariReadReport(
            foldersRead: transformed.foldersRead,
            bookmarksRead: transformed.bookmarksRead,
            issuesCount: transformed.issues.count,
            duration: duration,
            safariVersion: extraction.safariVersion,
            storageVersion: extraction.storageVersion
        )
        return SafariReadResult(
            snapshot: transformed.snapshot,
            report: report,
            issues: transformed.issues
        )
    }

    func execute(_ step: ExecutionStep) async throws -> BSEAdapterExecutionResult {
        throw BSEAdapterError.unsupportedCapability(.write)
    }

    func verify(_ step: ExecutionStep) async throws -> BSEAdapterVerificationResult {
        .unsupported
    }

    func createRestorePoint() async throws -> BSEAdapterRestorePoint {
        throw BSEAdapterError.unsupportedCapability(.createRestorePoint)
    }

    func restore(from restorePoint: BSEAdapterRestorePoint) async throws {
        throw BSEAdapterError.unsupportedCapability(.restore)
    }
}
