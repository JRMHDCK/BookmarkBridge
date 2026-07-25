//
//  ChromeAdapter.swift
//  BookmarkBridge
//

import Foundation

/// Read-only BSE adapter for exactly one local Chrome profile.
nonisolated struct ChromeAdapter: BSEAdapter {
    let sourceID: BSESourceID
    let profileIdentifier: ChromeProfileIdentifier
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

    private let dataSource: any ChromeDataSource
    private let transformer: ChromeSnapshotTransformer
    private let monotonicTime: @Sendable () -> TimeInterval

    init(
        sourceID: BSESourceID,
        profileIdentifier: ChromeProfileIdentifier,
        dataSource: any ChromeDataSource,
        transformer: ChromeSnapshotTransformer = ChromeSnapshotTransformer(),
        monotonicTime: @escaping @Sendable () -> TimeInterval = {
            ProcessInfo.processInfo.systemUptime
        }
    ) {
        self.sourceID = sourceID
        self.profileIdentifier = profileIdentifier
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

    /// Performs one extraction and one pure transformation, returning Chrome
    /// diagnostics beside (never inside) the resulting snapshot.
    func read() async throws -> ChromeReadResult {
        guard dataSource.profileIdentifier == profileIdentifier else {
            throw ChromeReadError.profileMismatch
        }

        let startedAt = monotonicTime()
        let extraction = try await dataSource.extract()
        guard extraction.profileIdentifier == profileIdentifier else {
            throw ChromeReadError.profileMismatch
        }
        let transformed = try transformer.transform(extraction, sourceID: sourceID)
        let duration = max(0, monotonicTime() - startedAt)
        let report = ChromeReadReport(
            foldersRead: transformed.foldersRead,
            bookmarksRead: transformed.bookmarksRead,
            issuesCount: transformed.issues.count,
            duration: duration,
            chromeVersion: extraction.chromeVersion,
            storageVersion: extraction.storageVersion,
            profileIdentifier: extraction.profileIdentifier
        )
        return ChromeReadResult(
            snapshot: transformed.snapshot,
            report: report,
            issues: transformed.issues,
            nativeIdentityObservations: transformed.nativeIdentityObservations
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
