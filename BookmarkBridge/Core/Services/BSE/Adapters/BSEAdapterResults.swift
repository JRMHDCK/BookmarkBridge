//
//  BSEAdapterResults.swift
//  BookmarkBridge
//

/// Outcome of executing exactly one idempotent BSE step.
nonisolated enum BSEAdapterExecutionResult: String, Hashable, Codable, Sendable {
    /// The adapter performed the requested write.
    case applied
    /// The source already satisfied the requested state; no write was performed.
    case alreadySatisfied
}

/// Read-only verification outcome for exactly one BSE step.
nonisolated enum BSEAdapterVerificationResult: String, Hashable, Codable, Sendable {
    case satisfied
    case notSatisfied
    case unsupported
}
