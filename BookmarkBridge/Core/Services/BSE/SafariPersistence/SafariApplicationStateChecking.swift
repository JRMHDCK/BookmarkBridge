//
//  SafariApplicationStateChecking.swift
//  BookmarkBridge
//

nonisolated protocol SafariApplicationStateChecking: Sendable {
    func ensureSafariIsClosed() throws
}
