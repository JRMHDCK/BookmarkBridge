//
//  ChromeProfileSelectionStore.swift
//  BookmarkBridge
//

import Foundation

@MainActor
struct UserDefaultsChromeProfileSelectionStore:
    ChromeProfileSelectionStoring
{
    static let key = "BookmarkAccess.SelectedChromeProfileDirectory"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func selectedProfileDirectory() -> String? {
        defaults.string(forKey: Self.key)
    }

    func saveSelectedProfileDirectory(_ directory: String) {
        defaults.set(directory, forKey: Self.key)
    }
}
