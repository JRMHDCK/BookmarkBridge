//
//  ChromeApplicationStateChecking.swift
//  BookmarkBridge
//

nonisolated protocol ChromeApplicationStateChecking: Sendable {
    func ensureChromeIsClosed() throws
}
