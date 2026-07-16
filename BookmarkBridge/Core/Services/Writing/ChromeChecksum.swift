//
//  ChromeChecksum.swift
//  BookmarkBridge
//

import Foundation
import CryptoKit

/// Reproduces Chrome's bookmark-file integrity checksum.
///
/// Chrome stores an MD5 digest in the `checksum` field and, on load, compares it
/// against a digest recomputed from the bookmark tree. The digest is built by
/// walking the permanent roots in a fixed order and, per node, feeding: the id,
/// the title (UTF-8), the type string (`"url"`/`"folder"`), and — for URL nodes —
/// the URL. Mirrors Chromium's `BookmarkCodec::UpdateChecksum*`.
///
/// It is computed over the **raw JSON dictionary** (original ids/titles/URLs
/// preserved) so a modified file matches what Chrome expects.
///
/// - Important: this must be validated against a real (throwaway) Chrome profile
///   before writing any real bookmark file. A mismatch is not data loss (Chrome
///   reloads and re-saves), but a match avoids Chrome flagging external edits.
nonisolated enum ChromeChecksum {
    /// Fixed order in which Chrome encodes its permanent roots.
    private static let rootOrder = ["bookmark_bar", "other", "synced"]

    /// The 32-character lowercase hex digest for the given `roots` object.
    static func compute(roots: [String: Any]) -> String {
        var md5 = Insecure.MD5()
        for key in rootOrder {
            if let root = roots[key] as? [String: Any] {
                update(&md5, node: root)
            }
        }
        return md5.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func update(_ md5: inout Insecure.MD5, node: [String: Any]) {
        let id = node["id"] as? String ?? ""
        let title = node["name"] as? String ?? ""
        let type = node["type"] as? String ?? ""

        md5.update(data: Data(id.utf8))
        md5.update(data: Data(title.utf8))
        md5.update(data: Data(type.utf8))

        if type == "url" {
            md5.update(data: Data((node["url"] as? String ?? "").utf8))
        } else {
            for child in (node["children"] as? [[String: Any]]) ?? [] {
                update(&md5, node: child)
            }
        }
    }
}
