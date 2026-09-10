//
//  SystemSafariImportPresenter.swift
//  BookmarkBridge
//

import AppKit
import Foundation
import UniformTypeIdentifiers

nonisolated protocol SafariImportDestinationSelecting: Sendable {
    @MainActor
    func selectDestinationFile() -> URL?
}

/// Uses the sandbox-supported Powerbox flow and starts on the Desktop. The
/// chosen URL is therefore writable without broad filesystem entitlements.
nonisolated struct SystemSafariImportDestinationSelector:
    SafariImportDestinationSelecting
{
    @MainActor
    func selectDestinationFile() -> URL? {
        let panel = NSSavePanel()
        panel.title = DocumentationText.value("safariImport.action.prepare")
        panel.directoryURL = FileManager.default.urls(
            for: .desktopDirectory,
            in: .userDomainMask
        ).first
        panel.nameFieldStringValue = "BookmarkBridge-Safari-Import.html"
        panel.allowedContentTypes = [.html]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        return panel.runModal() == .OK ? panel.url : nil
    }
}

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
