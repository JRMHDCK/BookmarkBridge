//
//  SystemRunningBrowserDetector.swift
//  BookmarkBridge
//

import Foundation

#if canImport(AppKit)
import AppKit

/// Detects a running browser via `NSWorkspace`, matching on bundle identifier.
/// Lives in the app layer because it depends on AppKit.
nonisolated struct SystemRunningBrowserDetector: RunningBrowserDetecting {
    init() {}

    func isRunning(_ browser: Browser) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == browser.bundleIdentifier }
    }
}
#endif
