//
//  ChromeLocalState.swift
//  BookmarkBridge
//

import Foundation

/// Reads Chrome's `Local State` (JSON) to map a profile **directory name** to its
/// user-facing name (`profile.info_cache[<dir>].name`).
///
/// Pure parsing — no file access. Best-effort: unreadable or unexpected data
/// yields an empty map, so callers naturally fall back to the directory name.
nonisolated enum ChromeLocalState {
    static func profileNames(from data: Data) -> [String: String] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = object["profile"] as? [String: Any],
              let infoCache = profile["info_cache"] as? [String: Any] else {
            return [:]
        }

        var names: [String: String] = [:]
        for (directory, value) in infoCache {
            if let entry = value as? [String: Any],
               let name = entry["name"] as? String,
               !name.isEmpty {
                names[directory] = name
            }
        }
        return names
    }
}
