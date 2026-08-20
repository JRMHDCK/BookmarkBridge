//
//  SystemSafariImportPresenter.swift
//  BookmarkBridge
//

import AppKit
import Foundation

nonisolated struct SystemSafariImportPresenter: SafariImportPresenting {
    @MainActor
    func present(_ importPresentation: SafariImportPresentation) {
        reveal(importPresentation)
        openSafari()
    }

    @MainActor
    func reveal(_ importPresentation: SafariImportPresentation) {
        NSWorkspace.shared.activateFileViewerSelecting([
            importPresentation.fileURL,
        ])
    }

    @MainActor
    func openSafari() {
        guard let safariURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: Browser.safari.bundleIdentifier
        ) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(
            at: safariURL,
            configuration: configuration
        ) { _, _ in }
    }
}
