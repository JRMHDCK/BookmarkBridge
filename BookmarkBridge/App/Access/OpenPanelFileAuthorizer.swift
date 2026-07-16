//
//  OpenPanelFileAuthorizer.swift
//  BookmarkBridge
//

#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers

/// An `AccessAuthorizing` backed by `NSOpenPanel` for selecting a **single
/// file** (used by Safari — `Bookmarks.plist`).
///
/// A thin AppKit adapter: presents a panel restricted to one file (no
/// directories, no multiple selection), returns the selected URL, and rejects
/// anything not named `Bookmarks.plist`. It creates no bookmark, persists
/// nothing, reads no file, and decodes no favourite.
///
/// The panel presentation is injected (`runPanel`) so cancellation/wrong-file
/// mapping is unit-testable; the real `NSOpenPanel` presentation requires a GUI
/// session and is not unit-tested.
@MainActor
struct OpenPanelFileAuthorizer: AccessAuthorizing {
    static let expectedFileName = "Bookmarks.plist"

    private let expectedFileName: String
    private let runPanel: @MainActor () -> URL?

    init(
        expectedFileName: String = OpenPanelFileAuthorizer.expectedFileName,
        runPanel: @escaping @MainActor () -> URL? = { OpenPanelFileAuthorizer.presentDefaultPanel() }
    ) {
        self.expectedFileName = expectedFileName
        self.runPanel = runPanel
    }

    func requestAccess() async throws -> URL {
        guard let url = runPanel() else {
            throw AccessError.cancelled
        }
        guard url.lastPathComponent == expectedFileName else {
            throw AccessError.wrongFile(selected: url)
        }
        return url
    }

    // MARK: - Real AppKit panel (not unit-tested; needs a GUI session)

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
