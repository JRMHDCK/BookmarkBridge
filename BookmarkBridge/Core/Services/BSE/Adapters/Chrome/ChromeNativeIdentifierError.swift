//
//  ChromeNativeIdentifierError.swift
//  BookmarkBridge
//

nonisolated enum ChromeNativeIdentifierError: Error, Hashable, Codable, Sendable {
    case noValidIdentifier(chromeID: String?, chromeGUID: String?)
}
