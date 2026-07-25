//
//  NativeIdentityBootstrapResult.swift
//  BookmarkBridge
//

/// Deterministic statistics for one validated native-identity bootstrap.
/// Conflicts abort before registration, so successful results always report
/// zero conflicts.
nonisolated struct NativeIdentityBootstrapResult: Hashable, Sendable {
    let observationsProcessed: Int
    let mappingsCreated: Int
    let mappingsAlreadyPresent: Int
    let migrationsApplied: Int
    let conflictsDetected: Int

    init(
        observationsProcessed: Int,
        mappingsCreated: Int,
        mappingsAlreadyPresent: Int,
        migrationsApplied: Int = 0,
        conflictsDetected: Int
    ) {
        self.observationsProcessed = observationsProcessed
        self.mappingsCreated = mappingsCreated
        self.mappingsAlreadyPresent = mappingsAlreadyPresent
        self.migrationsApplied = migrationsApplied
        self.conflictsDetected = conflictsDetected
    }
}
