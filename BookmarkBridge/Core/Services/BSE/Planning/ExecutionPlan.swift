//
//  ExecutionPlan.swift
//  BookmarkBridge
//

/// A deterministic set of executable BSE steps and unresolved decisions.
nonisolated struct ExecutionPlan: Hashable, Codable, Sendable {
    let steps: [ExecutionStep]
    let unplannedResolutions: [ConflictResolution]

    init(
        steps: [ExecutionStep],
        unplannedResolutions: [ConflictResolution]
    ) {
        self.steps = steps
        self.unplannedResolutions = unplannedResolutions
    }

    var isEmpty: Bool {
        steps.isEmpty && unplannedResolutions.isEmpty
    }
}
