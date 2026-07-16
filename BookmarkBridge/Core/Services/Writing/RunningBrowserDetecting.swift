//
//  RunningBrowserDetecting.swift
//  BookmarkBridge
//

import Foundation

/// Reports whether a browser is currently running.
///
/// Writing to a browser's bookmark file must never happen while the browser is
/// open (it would race the browser's own writes and could corrupt the file), so
/// the write phase consults this before doing anything. Abstracted as a protocol
/// so the write logic is testable with a double.
nonisolated protocol RunningBrowserDetecting: Sendable {
    func isRunning(_ browser: Browser) -> Bool
}
