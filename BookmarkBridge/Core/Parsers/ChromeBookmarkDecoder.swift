//
//  ChromeBookmarkDecoder.swift
//  BookmarkBridge
//

import Foundation

/// Decodes Chrome's `Bookmarks` (JSON) content into an immutable `BookmarkTree`.
///
/// Single responsibility: **decoding only**. It receives `Data` read elsewhere
/// and performs no file access, no locating, and no network I/O.
///
/// Behaviour:
/// - The root must be a JSON object with a `roots` object; otherwise decoding
///   throws `BookmarkError.decodingFailed`.
/// - Maps `roots.bookmark_bar`, `roots.other`, then `roots.synced` (in that
///   order) to root `BookmarkFolder`s. `synced` (mobile) is included **only if
///   present and non-empty**.
/// - `type: "folder"` → folder, `type: "url"` → bookmark.
/// - Chrome `date_added` (microseconds since 1601-01-01 UTC, as a string) is
///   converted to `Date`.
/// - Unicode/invalid URLs are percent-encoded (`BookmarkURLNormalizer`); a leaf
///   is skipped only when its URL is truly unrecoverable.
/// - `capturedAt` is left at a sentinel (`.distantPast`); the reader stamps the
///   real capture time.
nonisolated struct ChromeBookmarkDecoder: BookmarkDecoding {
    let browser: Browser = .chrome

    /// Seconds between 1601-01-01 and 1970-01-01 (the Chrome/Windows epoch).
    private static let windowsEpochOffset: Double = 11_644_473_600

    /// Root keys in display order. `synced` is conditional (see below).
    private static let orderedRootKeys = ["bookmark_bar", "other", "synced"]

    func decodeTree(from data: Data) throws -> BookmarkTree {
        let object = try jsonObject(from: data)
        guard let roots = object["roots"] as? [String: Any] else {
            throw BookmarkError.decodingFailed(browser, reason: "missing 'roots' object")
        }

        var treeRoots: [BookmarkFolder] = []
        for key in Self.orderedRootKeys {
            guard let rootDict = roots[key] as? [String: Any],
                  let folder = decodeFolder(rootDict) else {
                continue
            }
            // The mobile ("synced") root is only shown when it actually has content.
            if key == "synced" && folder.children.isEmpty {
                continue
            }
            treeRoots.append(folder)
        }

        return BookmarkTree(browser: browser, roots: treeRoots, capturedAt: .distantPast)
    }

    // MARK: - JSON

    private func jsonObject(from data: Data) throws -> [String: Any] {
        do {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw BookmarkError.decodingFailed(browser, reason: "root is not a JSON object")
            }
            return object
        } catch let error as BookmarkError {
            throw error
        } catch {
            throw BookmarkError.decodingFailed(browser, reason: "not valid JSON: \(error.localizedDescription)")
        }
    }

    // MARK: - Nodes

    private func decodeNode(_ dict: [String: Any]) -> BookmarkNode? {
        switch dict["type"] as? String {
        case "url": decodeLeaf(dict).map(BookmarkNode.bookmark)
        case "folder": decodeFolder(dict).map(BookmarkNode.folder)
        default: nil
        }
    }

    private func decodeFolder(_ dict: [String: Any]) -> BookmarkFolder? {
        guard (dict["type"] as? String) == "folder" else { return nil }
        let name = dict["name"] as? String ?? ""
        let childDicts = (dict["children"] as? [[String: Any]]) ?? []
        let children = childDicts.compactMap(decodeNode)
        return BookmarkFolder(
            id: identifier(dict, fallback: "folder:\(name)"),
            title: name,
            children: children,
            dateAdded: dateAdded(dict)
        )
    }

    private func decodeLeaf(_ dict: [String: Any]) -> Bookmark? {
        guard let urlString = dict["url"] as? String, !urlString.isEmpty,
              let url = BookmarkURLNormalizer.url(from: urlString) else {
            return nil
        }
        let name = dict["name"] as? String ?? ""
        return Bookmark(
            id: identifier(dict, fallback: "url:\(urlString)"),
            title: name,
            url: url,
            dateAdded: dateAdded(dict)
        )
    }

    private func identifier(_ dict: [String: Any], fallback: String) -> BookmarkID {
        if let id = dict["id"] as? String, !id.isEmpty {
            return BookmarkID("chrome:\(id)")
        }
        return BookmarkID(fallback)
    }

    private func dateAdded(_ dict: [String: Any]) -> Date? {
        guard let raw = dict["date_added"] as? String else { return nil }
        return Self.date(fromChromeTimestamp: raw)
    }

    // MARK: - Chrome timestamps

    /// Converts a Chrome `date_added` value (microseconds since 1601-01-01 UTC,
    /// as a decimal string) to a `Date`. Returns `nil` for missing/zero values.
    static func date(fromChromeTimestamp string: String) -> Date? {
        guard let microseconds = Int64(string), microseconds > 0 else { return nil }
        let seconds = Double(microseconds) / 1_000_000 - windowsEpochOffset
        return Date(timeIntervalSince1970: seconds)
    }
}
