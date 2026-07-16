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
/// - the path, query and fragment are otherwise preserved as-is (they can be
///   case- and order-sensitive), so `?a=1` and `?a=2` stay distinct.
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

        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""
        let fragment = components.percentEncodedFragment.map { "#\($0)" } ?? ""

        return "\(scheme)://\(host)\(port)\(path)\(query)\(fragment)"
    }
}
