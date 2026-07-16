//
//  BookmarkMatchKey.swift
//  BookmarkBridge
//

import Foundation

/// A canonical identity for a bookmark URL, used to decide whether two bookmarks
/// point at "the same page" during additive sync and de-duplication.
///
/// Normalization (deliberately conservative, so genuinely different pages never
/// collapse into one):
/// - scheme and host are lower-cased (case-insensitive by spec);
/// - trailing slashes on the path are trimmed (`/foo/` == `/foo`, `/` == ``);
/// - **known tracking parameters are dropped** (see ``isTrackingParameter(_:)``),
///   so a link and the same link with a `utm_source`/`fbclid`/… are one favourite;
/// - all other query parameters are kept, in order, so `?id=123` and `?page=2`
///   remain significant and `?a=1` stays distinct from `?a=2`;
/// - the path and fragment are otherwise preserved as-is (they can be case-
///   sensitive).
nonisolated enum BookmarkMatchKey {
    static func key(for url: URL) -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        let scheme = (components.scheme ?? "").lowercased()
        let host = (components.host ?? "").lowercased()
        let port = components.port.map { ":\($0)" } ?? ""

        var path = components.path
        while path.hasSuffix("/") { path.removeLast() }

        let query = canonicalQuery(components.percentEncodedQueryItems)
        let fragment = components.percentEncodedFragment.map { "#\($0)" } ?? ""

        return "\(scheme)://\(host)\(port)\(path)\(query)\(fragment)"
    }

    /// Rebuilds the query string with tracking parameters removed, preserving the
    /// order and encoding of the remaining ones. Empty (or all-tracking) → no query.
    private static func canonicalQuery(_ items: [URLQueryItem]?) -> String {
        guard let items, !items.isEmpty else { return "" }
        let kept = items.filter { !isTrackingParameter($0.name) }
        guard !kept.isEmpty else { return "" }
        let rebuilt = kept
            .map { item in item.value.map { "\(item.name)=\($0)" } ?? item.name }
            .joined(separator: "&")
        return "?\(rebuilt)"
    }

    /// Known analytics/click parameters that never change which page is meant.
    private static func isTrackingParameter(_ name: String) -> Bool {
        let lowercased = name.lowercased()
        if lowercased.hasPrefix("utm_") || lowercased.hasPrefix("mc_") { return true }
        return ["fbclid", "gclid", "msclkid", "dclid"].contains(lowercased)
    }
}
