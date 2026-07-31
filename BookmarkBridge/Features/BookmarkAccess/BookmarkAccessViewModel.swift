//
//  BookmarkAccessViewModel.swift
//  BookmarkBridge
//

import Observation

@MainActor
@Observable
final class BookmarkAccessViewModel {
    private(set) var snapshot: BookmarkAccessSnapshot?
    private(set) var selectedChromeProfileDirectory: String?
    private(set) var safariTestStatus: BookmarkAccessStatus?
    private(set) var chromeTestStatus: BookmarkAccessStatus?
    private(set) var isLoading = false

    private let service: any BookmarkAccessManaging
    private let selectionStore: any ChromeProfileSelectionStoring

    init(
        service: any BookmarkAccessManaging,
        selectionStore: any ChromeProfileSelectionStoring
    ) {
        self.service = service
        self.selectionStore = selectionStore
        selectedChromeProfileDirectory =
            selectionStore.selectedProfileDirectory()
    }

    var selectedChromeProfile: ChromeProfileAccess? {
        guard let selectedChromeProfileDirectory else { return nil }
        return snapshot?.chrome.profiles.first {
            $0.directoryName == selectedChromeProfileDirectory
        }
    }

    func load() async {
        isLoading = true
        let inspected = await service.inspectAccess()
        snapshot = inspected
        resolveSelectedProfile(in: inspected.chrome.profiles)
        isLoading = false
    }

    func testAccess(_ browser: Browser) async {
        let status = await service.testAccess(
            for: browser,
            chromeProfileDirectory: selectedChromeProfileDirectory
        )
        switch browser {
        case .safari: safariTestStatus = status
        case .chrome: chromeTestStatus = status
        }
        await load()
    }

    func reauthorize(_ browser: Browser) async throws -> Bool {
        guard try await service.reauthorize(browser) else { return false }
        await load()
        return true
    }

    func selectChromeProfile(_ directory: String) {
        guard snapshot?.chrome.profiles.contains(where: {
            $0.directoryName == directory
        }) == true else {
            return
        }
        selectedChromeProfileDirectory = directory
        selectionStore.saveSelectedProfileDirectory(directory)
        chromeTestStatus = nil
    }

    private func resolveSelectedProfile(
        in profiles: [ChromeProfileAccess]
    ) {
        if let selectedChromeProfileDirectory,
           profiles.contains(where: {
               $0.directoryName == selectedChromeProfileDirectory
           }) {
            return
        }
        guard let first = profiles.first else {
            selectedChromeProfileDirectory = nil
            return
        }
        selectedChromeProfileDirectory = first.directoryName
        selectionStore.saveSelectedProfileDirectory(first.directoryName)
    }
}
