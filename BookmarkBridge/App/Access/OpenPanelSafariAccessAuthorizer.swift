//
//  OpenPanelSafariAccessAuthorizer.swift
//  BookmarkBridge
//

#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers

/// Concrete `SafariAccessAuthorizing` backed by `NSOpenPanel`.
///
/// A thin AppKit adapter, and nothing more: it presents a panel restricted to a
/// single file (no directories, no multiple selection), returns the selected
/// URL, and rejects anything that is not named `Bookmarks.plist`. It creates no
/// bookmark, persists nothing, reads no file, and decodes no favourite.
///
/// The panel presentation is injected (`runPanel`) so the cancellation and
/// wrong-file mapping can be unit-tested; the real `NSOpenPanel` presentation
/// (`presentDefaultPanel`) requires a GUI session and is not unit-tested.
@MainActor
struct OpenPanelSafariAccessAuthorizer: SafariAccessAuthorizing {
    /// The exact file name the user must select.
    static let expectedFileName = "Bookmarks.plist"

    private let expectedFileName: String
    private let runPanel: @MainActor () -> URL?

    init(
        expectedFileName: String = OpenPanelSafariAccessAuthorizer.expectedFileName,
        runPanel: @escaping @MainActor () -> URL? = { OpenPanelSafariAccessAuthorizer.presentDefaultPanel() }
    ) {
        self.expectedFileName = expectedFileName
        self.runPanel = runPanel
    }

    func requestAccess() async throws -> URL {
        guard let url = runPanel() else {
            throw SafariAccessError.cancelled
        }
        guard url.lastPathComponent == expectedFileName else {
            throw SafariAccessError.wrongFile(selected: url)
        }
        return url
    }

    // MARK: - Real AppKit panel (not unit-tested; needs a GUI session)

    /// Presents a single-file, read-oriented open panel and returns the chosen
    /// URL, or `nil` if the user cancels.
    static func presentDefaultPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.allowedContentTypes = [.propertyList]
        panel.title = "Autoriser l'accès aux favoris Safari"
        panel.message = "Sélectionnez le fichier « Bookmarks.plist » dans ~/Library/Safari/."
        panel.prompt = "Autoriser la lecture"

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
#endif
