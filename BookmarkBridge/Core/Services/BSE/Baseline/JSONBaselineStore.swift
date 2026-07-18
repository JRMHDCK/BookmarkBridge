//
//  JSONBaselineStore.swift
//  BookmarkBridge
//

import Foundation

/// First file-backed baseline persistence. JSON never crosses the store boundary.
actor JSONBaselineStore: BaselineStore {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() async throws -> Baseline? {
        try loadFromDisk()
    }

    func save(
        _ baseline: Baseline,
        expectedRevision: BaselineRevision?
    ) async throws {
        let current = try loadFromDisk()
        try BaselineStoreValidation.validateSave(
            newBaseline: baseline,
            currentBaseline: current,
            expectedRevision: expectedRevision
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data: Data
        do {
            data = try encoder.encode(baseline)
        } catch {
            throw BaselineError.storeFailure
        }
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw BaselineError.storeFailure
        }
    }

    private func loadFromDisk() throws -> Baseline? {
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else {
            return nil
        }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw BaselineError.storeFailure
        }
        do {
            return try JSONDecoder().decode(Baseline.self, from: data)
        } catch {
            throw BaselineError.corruptedData
        }
    }
}
