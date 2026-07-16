//
//  BookmarkURLNormalizer.swift
//  BookmarkBridge
//

import Foundation

/// Turns a raw bookmark URL string (from any browser) into a valid `URL`,
/// percent-encoding non-conforming characters (e.g. Unicode paths) when needed.
///
/// Shared by the Safari and Chrome decoders so URL handling stays consistent and
/// in one place. Returns `nil` only when the string cannot be expressed as a URL
/// at all — the caller then treats the entry as unrecoverable.
nonisolated enum BookmarkURLNormalizer {
    static func url(from raw: String) -> URL? {
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
