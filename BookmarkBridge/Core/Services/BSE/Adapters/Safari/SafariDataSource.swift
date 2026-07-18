//
//  SafariDataSource.swift
//  BookmarkBridge
//

/// Read-only extraction boundary for Safari's official local bookmark source.
///
/// Native records remain internal to the Safari adapter module. No BSE model is
/// created here; conversion belongs exclusively to `SafariSnapshotTransformer`.
nonisolated protocol SafariDataSource: Sendable {
    /// Observes the current permission state without prompting the user.
    func checkPermissions() async -> BSEAdapterPermissionStatus

    /// Observes compatibility with the detected local storage version.
    func checkCompatibility() async -> BSEAdapterCompatibility

    /// Captures one coherent, immutable view of the local Safari source.
    func extract() async throws -> SafariExtraction
}
