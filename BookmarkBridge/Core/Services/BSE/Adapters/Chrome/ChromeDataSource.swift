//
//  ChromeDataSource.swift
//  BookmarkBridge
//

/// Read-only extraction boundary for one official local Chrome profile.
///
/// Native records remain internal to the Chrome adapter module. No BSE model is
/// created here; conversion belongs exclusively to `ChromeSnapshotTransformer`.
nonisolated protocol ChromeDataSource: Sendable {
    /// The single profile owned by this source.
    var profileIdentifier: ChromeProfileIdentifier { get }

    /// Observes the current permission state without prompting the user.
    func checkPermissions() async -> BSEAdapterPermissionStatus

    /// Observes compatibility with the detected local storage version.
    func checkCompatibility() async -> BSEAdapterCompatibility

    /// Captures one coherent, immutable view of the local Chrome profile.
    func extract() async throws -> ChromeExtraction
}
