//
//  SafariBookmarkDecoder.swift
//  BookmarkBridge
//

import Foundation

/// Decodes Safari's `Bookmarks.plist` content into an immutable `BookmarkTree`.
///
/// Single responsibility: **decoding only**. It receives `Data` that was already
/// read elsewhere and performs no file access, no locating, and no network I/O.
///
/// Behaviour:
/// - The root must be a `WebBookmarkTypeList`; otherwise decoding throws
///   `BookmarkError.decodingFailed`.
/// - Each top-level list becomes a root `BookmarkFolder` (Bookmarks Bar, folders,
///   Reading List). Top-level non-folder entries are ignored (Safari does not
///   place bare bookmarks at the root).
/// - Unicode/invalid URLs are **percent-encoded automatically** to keep as many
///   bookmarks as possible. A leaf is skipped **only** when its URL is truly
///   unrecoverable (missing/empty, or not expressible as a URL even after
///   encoding).
/// - `capturedAt` is left at a sentinel (`.distantPast`); the reader stamps the
///   real capture time, since the decoder cannot know it.
nonisolated struct SafariBookmarkDecoder: BookmarkDecoding {
    let browser: Browser = .safari

    func decodeTree(from data: Data) throws -> BookmarkTree {
        let object = try propertyList(from: data)
        guard let root = object as? [String: Any] else {
            throw BookmarkError.decodingFailed(browser, reason: "root is not a property-list dictionary")
        }
        guard (root["WebBookmarkType"] as? String) == "WebBookmarkTypeList" else {
            throw BookmarkError.decodingFailed(browser, reason: "root is not a WebBookmarkTypeList")
        }

        let topLevel = (root["Children"] as? [[String: Any]]) ?? []
        let roots = topLevel.compactMap(decodeFolder)

        return BookmarkTree(browser: browser, roots: roots, capturedAt: .distantPast)
    }

    // MARK: - Property list

    private func propertyList(from data: Data) throws -> Any {
        do {
            return try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        } catch {
            throw BookmarkError.decodingFailed(browser, reason: "not a valid property list: \(error.localizedDescription)")
        }
    }

    // MARK: - Nodes

    private func decodeNode(_ dict: [String: Any]) -> BookmarkNode? {
        switch dict["WebBookmarkType"] as? String {
        case "WebBookmarkTypeLeaf": decodeLeaf(dict).map(BookmarkNode.bookmark)
        case "WebBookmarkTypeList": decodeFolder(dict).map(BookmarkNode.folder)
        default: nil
        }
    }

    private func decodeFolder(_ dict: [String: Any]) -> BookmarkFolder? {
        guard (dict["WebBookmarkType"] as? String) == "WebBookmarkTypeList" else { return nil }
        let title = dict["Title"] as? String ?? ""
        let childDicts = (dict["Children"] as? [[String: Any]]) ?? []
        let children = childDicts.compactMap(decodeNode)
        return BookmarkFolder(
            id: identifier(dict, fallback: "folder:\(title)"),
            title: title,
            children: children,
            dateAdded: nil
        )
    }

    private func decodeLeaf(_ dict: [String: Any]) -> Bookmark? {
        guard let urlString = dict["URLString"] as? String, !urlString.isEmpty,
              let url = Self.makeURL(from: urlString) else {
            return nil
        }
        let title = (dict["URIDictionary"] as? [String: Any])?["title"] as? String ?? ""
        let dateAdded = (dict["ReadingList"] as? [String: Any])?["DateAdded"] as? Date
        return Bookmark(
            id: identifier(dict, fallback: "leaf:\(urlString)"),
            title: title,
            url: url,
            dateAdded: dateAdded
        )
    }

    private func identifier(_ dict: [String: Any], fallback: String) -> BookmarkID {
        if let uuid = dict["WebBookmarkUUID"] as? String, !uuid.isEmpty {
            return BookmarkID(uuid)
        }
        return BookmarkID(fallback)
    }

    // MARK: - URL normalization

    /// Converts a raw Safari `URLString` into a valid URL, percent-encoding
    /// non-conforming characters when needed. Returns `nil` only when the string
    /// cannot be expressed as a URL at all.
    static func makeURL(from raw: String) -> URL? {
        // 1. Already a valid, fully-ASCII URL.
        if let url = URL(string: raw), url.absoluteString.allSatisfy(\.isASCII) {
            return url
        }
        // 2. Percent-encode the offending characters, then retry.
        if let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
           let url = URL(string: encoded) {
            return url
        }
        // 3. Last resort: whatever URL(string:) can make of the raw value.
        return URL(string: raw)
    }
}
