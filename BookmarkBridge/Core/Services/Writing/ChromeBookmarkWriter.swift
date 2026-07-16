//
//  ChromeBookmarkWriter.swift
//  BookmarkBridge
//

import Foundation

/// Applies **additive** changes to Chrome's `Bookmarks` (JSON), returning new
/// JSON `Data` with a recomputed checksum.
///
/// Works on the **original raw JSON** — existing nodes keep their exact ids,
/// names, URLs and guids — and only appends new URL nodes (fresh unique ids).
/// Pure `Data → Data`: no file access, no `.bak` handling, no browser contact.
/// Those, plus the mandatory backup and the "Chrome is closed" check, belong to
/// the file-writing step wired later.
///
/// - Note (v1): additions are appended to the "Other bookmarks" root; the
///   captured origin folder path (`SyncChange.sourcePath`) will drive faithful
///   folder placement in a later refinement.
nonisolated struct ChromeBookmarkWriter {

    init() {}

    /// Returns the Chrome JSON that adds `additions` to `original`.
    /// - Parameter now: timestamp for the new nodes' `date_added` (injected for tests).
    func applying(_ additions: [Bookmark], to original: Data, now: Date, into targetRoot: String = "other") throws -> Data {
        guard var object = try JSONSerialization.jsonObject(with: original) as? [String: Any],
              var roots = object["roots"] as? [String: Any] else {
            throw BookmarkError.decodingFailed(.chrome, reason: "missing 'roots' object")
        }
        guard var target = roots[targetRoot] as? [String: Any] else {
            throw BookmarkError.decodingFailed(.chrome, reason: "missing '\(targetRoot)' root")
        }

        var nextID = (Self.maxID(in: roots) ?? 0) + 1
        var children = (target["children"] as? [[String: Any]]) ?? []
        for bookmark in additions {
            children.append(Self.urlNode(id: nextID, bookmark: bookmark, now: now))
            nextID += 1
        }
        target["children"] = children
        roots[targetRoot] = target
        object["roots"] = roots
        object["checksum"] = ChromeChecksum.compute(roots: roots)

        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    // MARK: - Helpers

    private static func urlNode(id: Int64, bookmark: Bookmark, now: Date) -> [String: Any] {
        [
            "type": "url",
            "id": String(id),
            "guid": UUID().uuidString.lowercased(),
            "name": bookmark.title,
            "url": bookmark.url.absoluteString,
            "date_added": chromeTimestamp(now),
        ]
    }

    /// The largest numeric id anywhere in the roots, so new ids never collide.
    private static func maxID(in roots: [String: Any]) -> Int64? {
        var maximum: Int64?
        func visit(_ node: [String: Any]) {
            if let idString = node["id"] as? String, let id = Int64(idString) {
                maximum = max(maximum ?? id, id)
            }
            for child in (node["children"] as? [[String: Any]]) ?? [] { visit(child) }
        }
        for value in roots.values {
            if let node = value as? [String: Any] { visit(node) }
        }
        return maximum
    }

    /// Microseconds since 1601-01-01 UTC (Chrome's epoch), as a decimal string.
    private static func chromeTimestamp(_ date: Date) -> String {
        let windowsEpochOffset = 11_644_473_600.0
        return String(Int64((date.timeIntervalSince1970 + windowsEpochOffset) * 1_000_000))
    }
}
