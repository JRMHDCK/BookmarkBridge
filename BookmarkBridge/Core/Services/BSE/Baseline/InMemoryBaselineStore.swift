//
//  InMemoryBaselineStore.swift
//  BookmarkBridge
//

/// Deterministic actor-backed store for tests and ephemeral repositories.
actor InMemoryBaselineStore: BaselineStore {
    private var storedBaseline: Baseline?

    init(baseline: Baseline? = nil) {
        storedBaseline = baseline
    }

    func load() async throws -> Baseline? {
        storedBaseline
    }

    func save(
        _ baseline: Baseline,
        expectedRevision: BaselineRevision?
    ) async throws {
        try BaselineStoreValidation.validateSave(
            newBaseline: baseline,
            currentBaseline: storedBaseline,
            expectedRevision: expectedRevision
        )
        storedBaseline = baseline
    }
}

nonisolated enum BaselineStoreValidation {
    static func validateSave(
        newBaseline: Baseline,
        currentBaseline: Baseline?,
        expectedRevision: BaselineRevision?
    ) throws {
        guard let currentBaseline else {
            guard expectedRevision == nil else {
                throw BaselineError.baselineNotFound
            }
            return
        }
        guard let expectedRevision else {
            throw BaselineError.baselineAlreadyExists
        }
        guard currentBaseline.revision == expectedRevision else {
            throw BaselineError.revisionConflict(
                expected: expectedRevision,
                actual: currentBaseline.revision
            )
        }
        guard currentBaseline.baselineID == newBaseline.baselineID else {
            throw BaselineError.invariantViolation(.baselineIDChanged)
        }
        guard currentBaseline.revision < newBaseline.revision else {
            throw BaselineError.invariantViolation(.nonMonotoneRevision)
        }
    }
}
