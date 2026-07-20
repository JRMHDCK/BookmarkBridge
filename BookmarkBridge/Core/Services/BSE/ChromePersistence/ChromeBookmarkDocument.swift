//
//  ChromeBookmarkDocument.swift
//  BookmarkBridge
//

import Foundation

/// Immutable JSON payload plus the fingerprint of the source it was read from.
/// Original bytes are retained so unknown Chrome fields remain available to a
/// future in-memory mutator without being projected into a simplified model.
nonisolated struct ChromeBookmarkDocument: Hashable, Sendable {
    let data: Data
    let sourceFingerprint: ChromeDocumentFingerprint

    init(data: Data, sourceFingerprint: ChromeDocumentFingerprint) throws {
        guard let object = try Self.decode(data) as? [String: Any] else {
            throw ChromePersistenceError.invalidJSON
        }
        guard JSONSerialization.isValidJSONObject(object) else {
            throw ChromePersistenceError.invalidJSON
        }
        self.data = data
        self.sourceFingerprint = sourceFingerprint
    }

    /// Recomputes Chrome's checksum only when the source document already owns
    /// that field. No missing metadata is invented by persistence.
    func dataForPersistence() throws -> Data {
        guard var object = try Self.decode(data) as? [String: Any],
              let roots = object["roots"] as? [String: Any] else {
            throw ChromePersistenceError.invalidJSON
        }
        if object["checksum"] != nil {
            guard object["checksum"] is String else {
                throw ChromePersistenceError.invalidStructure(.invalidChecksum)
            }
            object["checksum"] = ChromeChecksum.compute(roots: roots)
        }
        do {
            return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        } catch {
            throw ChromePersistenceError.invalidJSON
        }
    }

    private static func decode(_ data: Data) throws -> Any {
        do {
            return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw ChromePersistenceError.invalidJSON
        }
    }
}
