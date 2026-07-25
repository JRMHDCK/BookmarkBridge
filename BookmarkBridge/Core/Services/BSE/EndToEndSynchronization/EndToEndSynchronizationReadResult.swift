//
//  EndToEndSynchronizationReadResult.swift
//  BookmarkBridge
//

/// Browser-neutral output from the single extraction performed by a reader.
nonisolated struct EndToEndSynchronizationReadResult: Hashable, Sendable {
    let snapshot: BSESnapshot
    let nativeIdentityObservations: [NativeIdentityObservation]
}

nonisolated protocol EndToEndSynchronizationReading: Sendable {
    var sourceID: BSESourceID { get }

    func readForSynchronization() async throws
        -> EndToEndSynchronizationReadResult
}

extension SafariAdapter: EndToEndSynchronizationReading {
    func readForSynchronization() async throws
        -> EndToEndSynchronizationReadResult {
        let result = try await read()
        return EndToEndSynchronizationReadResult(
            snapshot: result.snapshot,
            nativeIdentityObservations: result.nativeIdentityObservations
        )
    }
}

extension ChromeAdapter: EndToEndSynchronizationReading {
    func readForSynchronization() async throws
        -> EndToEndSynchronizationReadResult {
        let result = try await read()
        return EndToEndSynchronizationReadResult(
            snapshot: result.snapshot,
            nativeIdentityObservations: result.nativeIdentityObservations
        )
    }
}
