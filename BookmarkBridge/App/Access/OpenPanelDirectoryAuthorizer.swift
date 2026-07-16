//
//  OpenPanelDirectoryAuthorizer.swift
//  BookmarkBridge
//

#if canImport(AppKit)
import AppKit

/// An `AccessAuthorizing` backed by `NSOpenPanel` for selecting a **single
/// directory** (used by Chrome — the data folder, one grant for all profiles).
///
/// A thin AppKit adapter: presents a directory-only panel, returns the selected
/// URL, and throws `AccessError.cancelled` on dismissal. It validates nothing
/// (the coordinator validates the path suffix), creates no bookmark, persists
/// nothing, and reads no file.
///
/// The panel presentation is injected (`runPanel`) so cancellation is
/// unit-testable; the real `NSOpenPanel` presentation requires a GUI session and
/// is not unit-tested.
@MainActor
struct OpenPanelDirectoryAuthorizer: AccessAuthorizing {
    private let runPanel: @MainActor () -> URL?

    init(runPanel: @escaping @MainActor () -> URL? = { OpenPanelDirectoryAuthorizer.presentDefaultPanel() }) {
        self.runPanel = runPanel
    }

    func requestAccess() async throws -> URL {
        guard let url = runPanel() else {
            throw AccessError.cancelled
        }
        return url
    }

    // MARK: - Real AppKit panel (not unit-tested; needs a GUI session)

    static func presentDefaultPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.title = "Autoriser l'accès aux favoris Chrome"
        panel.message = "Sélectionnez le dossier « Chrome » dans ~/Library/Application Support/Google/."
        panel.prompt = "Autoriser la lecture"

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
#endif
