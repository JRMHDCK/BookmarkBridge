//
//  BSEAdapterCapabilityValidator.swift
//  BookmarkBridge
//

/// Pure validation shared by concrete adapters before any external operation.
///
/// Keeping this policy in BSE avoids browser-specific reinterpretation while
/// leaving all actual I/O private to future concrete adapters.
nonisolated struct BSEAdapterCapabilityValidator: Sendable {
    func validateReading(capabilities: BSEAdapterCapabilities) throws {
        try require(.read, in: capabilities)
    }

    func validateExecution(
        _ step: ExecutionStep,
        capabilities: BSEAdapterCapabilities
    ) throws {
        try require(.write, in: capabilities)
        try require(step.kind.adapterCapability, in: capabilities)
    }

    /// Returns `.unsupported` when verification must stop before external I/O.
    func unsupportedVerificationResult(
        capabilities: BSEAdapterCapabilities
    ) -> BSEAdapterVerificationResult? {
        capabilities.canVerify ? nil : .unsupported
    }

    func validateRestorePointCreation(capabilities: BSEAdapterCapabilities) throws {
        try require(.createRestorePoint, in: capabilities)
    }

    func validateRestoration(
        from restorePoint: BSEAdapterRestorePoint,
        sourceID: BSESourceID,
        capabilities: BSEAdapterCapabilities
    ) throws {
        guard restorePoint.sourceID == sourceID else {
            throw BSEAdapterError.sourceMismatch(
                expected: sourceID,
                actual: restorePoint.sourceID
            )
        }
        try require(.restore, in: capabilities)
    }

    private func require(
        _ capability: BSEAdapterCapability,
        in capabilities: BSEAdapterCapabilities
    ) throws {
        guard capabilities.supports(capability) else {
            throw BSEAdapterError.unsupportedCapability(capability)
        }
    }
}

nonisolated private extension ExecutionStepKind {
    var adapterCapability: BSEAdapterCapability {
        switch self {
        case .create: .create
        case .delete: .delete
        case .move: .move
        case .rename: .rename
        }
    }
}
