//
//  BaselineStore.swift
//  BookmarkBridge
//

/// Storage-independent persistence boundary with compare-and-save semantics.
nonisolated protocol BaselineStore: Sendable {
    func load() async throws -> Baseline?

    /// Persists atomically only if the stored revision matches `expectedRevision`.
    /// A nil expectation creates a baseline and fails if one already exists.
    func save(
        _ baseline: Baseline,
        expectedRevision: BaselineRevision?
    ) async throws
}
