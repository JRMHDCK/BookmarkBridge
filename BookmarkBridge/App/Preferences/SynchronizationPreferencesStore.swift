//
//  SynchronizationPreferencesStore.swift
//  BookmarkBridge
//

import Foundation

nonisolated struct SynchronizationPreferences: Codable, Equatable, Sendable {
    nonisolated struct SourceState: Codable, Equatable, Sendable {
        var selectedNodeIDs: Set<String> = []
        var knownNodeIDs: Set<String> = []
        var expandedFolderIDs: Set<String> = []
    }

    static let currentSchemaVersion = 1

    var schemaVersion = currentSchemaVersion
    var selectedDirectionRawValue: String?
    var selectedChromeProfileDirectory: String?
    var sourceStates: [String: SourceState] = [:]
    var counterpartExclusions: Set<String> = []
}

@MainActor
protocol SynchronizationPreferencesStoring: Sendable {
    func load() -> SynchronizationPreferences
    func save(_ preferences: SynchronizationPreferences)
}

@MainActor
struct UserDefaultsSynchronizationPreferencesStore:
    SynchronizationPreferencesStoring,
    ChromeProfileSelectionStoring
{
    static let key = "Synchronization.Preferences"
    static let legacyChromeProfileKey =
        "BookmarkAccess.SelectedChromeProfileDirectory"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> SynchronizationPreferences {
        let currentSchemaVersion =
            SynchronizationPreferences.currentSchemaVersion
        guard defaults.object(forKey: Self.key) != nil else {
            return migrateLegacyPreferences()
        }
        guard let data = defaults.data(forKey: Self.key) else {
            defaults.removeObject(forKey: Self.key)
            return SynchronizationPreferences()
        }
        guard let preferences = try? decoder.decode(
            SynchronizationPreferences.self,
            from: data
        ), preferences.schemaVersion == currentSchemaVersion else {
            defaults.removeObject(forKey: Self.key)
            return SynchronizationPreferences()
        }
        return preferences
    }

    func save(_ preferences: SynchronizationPreferences) {
        guard let data = try? encoder.encode(preferences) else { return }
        defaults.set(data, forKey: Self.key)
        defaults.removeObject(forKey: Self.legacyChromeProfileKey)
    }

    func selectedProfileDirectory() -> String? {
        load().selectedChromeProfileDirectory
    }

    func saveSelectedProfileDirectory(_ directory: String?) {
        var preferences = load()
        preferences.selectedChromeProfileDirectory = directory
        save(preferences)
    }

    private func migrateLegacyPreferences() -> SynchronizationPreferences {
        guard let directory = defaults.string(
            forKey: Self.legacyChromeProfileKey
        ) else {
            return SynchronizationPreferences()
        }
        var preferences = SynchronizationPreferences()
        preferences.selectedChromeProfileDirectory = directory
        save(preferences)
        return preferences
    }
}

@MainActor
final class InMemorySynchronizationPreferencesStore:
    SynchronizationPreferencesStoring,
    ChromeProfileSelectionStoring
{
    private(set) var preferences: SynchronizationPreferences

    init(
        preferences: SynchronizationPreferences = SynchronizationPreferences()
    ) {
        self.preferences = preferences
    }

    func load() -> SynchronizationPreferences { preferences }

    func save(_ preferences: SynchronizationPreferences) {
        self.preferences = preferences
    }

    func selectedProfileDirectory() -> String? {
        preferences.selectedChromeProfileDirectory
    }

    func saveSelectedProfileDirectory(_ directory: String?) {
        preferences.selectedChromeProfileDirectory = directory
    }
}
