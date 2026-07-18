//
//  BSEAdapter.swift
//  BookmarkBridge
//

/// Universal boundary between BSE and exactly one external bookmark source.
///
/// Adapters are intentionally stateless from BSE's perspective. They read one
/// source, execute one already-planned atomic step, verify that step, and expose
/// source-local restore operations. Matching, diffing, conflict resolution,
/// planning, and transaction sequencing remain outside this contract.
nonisolated protocol BSEAdapter: Sendable {
    /// Stable BSE identity of the single source owned by this adapter.
    var sourceID: BSESourceID { get }

    /// Immutable operations supported by this adapter implementation.
    var capabilities: BSEAdapterCapabilities { get }

    /// Observes the current permission state without requesting authorization.
    func checkPermissions() async -> BSEAdapterPermissionStatus

    /// Observes whether the current source version is supported.
    func checkCompatibility() async -> BSEAdapterCompatibility

    /// Reads the source without modifying it.
    func readSnapshot() async throws -> BSESnapshot

    /// Executes exactly the supplied atomic step without reinterpreting it.
    ///
    /// Implementations must validate capabilities before writing. A failure
    /// ends this call and never triggers another step or an autonomous rollback.
    func execute(_ step: ExecutionStep) async throws -> BSEAdapterExecutionResult

    /// Observes whether the supplied step is satisfied after execution.
    ///
    /// An implementation that cannot verify returns `.unsupported` and performs
    /// no corrective write.
    func verify(_ step: ExecutionStep) async throws -> BSEAdapterVerificationResult

    /// Creates an opaque, source-local restore point before a future transaction.
    func createRestorePoint() async throws -> BSEAdapterRestorePoint

    /// Restores the source from one of this adapter's restore points.
    func restore(from restorePoint: BSEAdapterRestorePoint) async throws
}
