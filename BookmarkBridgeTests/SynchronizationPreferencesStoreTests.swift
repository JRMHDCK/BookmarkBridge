//
//  SynchronizationPreferencesStoreTests.swift
//  BookmarkBridgeTests
//

import Foundation
import Testing
@testable import BookmarkBridge

@MainActor
@Suite("Synchronization preferences store")
struct SynchronizationPreferencesStoreTests {
    @Test("First launch has no persisted preference")
    func firstLaunch() {
        let fixture = makeFixture()
        defer { fixture.remove() }

        #expect(
            fixture.store.load()
                == SynchronizationPreferences()
        )
    }

    @Test("The complete preference document survives a new store instance")
    func saveAndRestore() {
        let fixture = makeFixture()
        defer { fixture.remove() }
        var expected = SynchronizationPreferences()
        expected.selectedDirectionRawValue =
            SynchronizationDirectionOption.chromeToSafari.rawValue
        expected.selectedChromeProfileDirectory = "Profile 1"
        expected.counterpartExclusions = ["bookmark:https://ignored.example"]
        expected.sourceStates["chrome:Profile 1"] = .init(
            selectedNodeIDs: ["chrome:folder", "chrome:bookmark"],
            knownNodeIDs: [
                "chrome:folder",
                "chrome:bookmark",
                "chrome:unchecked",
            ],
            expandedFolderIDs: ["chrome:folder"]
        )

        fixture.store.save(expected)
        let restored = UserDefaultsSynchronizationPreferencesStore(
            defaults: fixture.defaults
        ).load()

        #expect(restored == expected)
    }

    @Test("Profile and direction updates preserve the stored tree state")
    func independentUpdatesDoNotOverwritePreferences() {
        let store = InMemorySynchronizationPreferencesStore()
        var preferences = SynchronizationPreferences()
        preferences.sourceStates["safari:"] = .init(
            selectedNodeIDs: ["folder"],
            knownNodeIDs: ["folder", "bookmark"],
            expandedFolderIDs: ["folder"]
        )
        store.save(preferences)

        store.saveSelectedProfileDirectory("Default")
        SynchronizationDirectionNavigation(
            preferencesStore: store
        ).select(.safariToChrome)

        #expect(
            store.load().sourceStates["safari:"]
                == preferences.sourceStates["safari:"]
        )
        #expect(store.load().selectedChromeProfileDirectory == "Default")
        #expect(
            store.load().selectedDirectionRawValue
                == SynchronizationDirectionOption.safariToChrome.rawValue
        )
    }

    @Test("Corrupted preference data is discarded without an error")
    func corruptedData() {
        let fixture = makeFixture()
        defer { fixture.remove() }
        fixture.defaults.set(
            Data("not-json".utf8),
            forKey: UserDefaultsSynchronizationPreferencesStore.key
        )

        let restored = fixture.store.load()

        #expect(restored == SynchronizationPreferences())
        #expect(
            fixture.defaults.object(
                forKey: UserDefaultsSynchronizationPreferencesStore.key
            ) == nil
        )
    }

    @Test("A corrupted preference value of the wrong type is discarded")
    func corruptedValueType() {
        let fixture = makeFixture()
        defer { fixture.remove() }
        fixture.defaults.set(
            ["unexpected": "dictionary"],
            forKey: UserDefaultsSynchronizationPreferencesStore.key
        )

        #expect(fixture.store.load() == SynchronizationPreferences())
        #expect(
            fixture.defaults.object(
                forKey: UserDefaultsSynchronizationPreferencesStore.key
            ) == nil
        )
    }

    @Test("The former Chrome-only preference is migrated once")
    func migratesLegacyChromeProfile() {
        let fixture = makeFixture()
        defer { fixture.remove() }
        fixture.defaults.set(
            "Profile 2",
            forKey:
                UserDefaultsSynchronizationPreferencesStore
                    .legacyChromeProfileKey
        )

        let restored = fixture.store.load()

        #expect(restored.selectedChromeProfileDirectory == "Profile 2")
        #expect(
            fixture.defaults.object(
                forKey: UserDefaultsSynchronizationPreferencesStore
                    .legacyChromeProfileKey
            ) == nil
        )
    }

    private func makeFixture() -> PreferencesFixture {
        let suiteName = "BookmarkBridgeTests.Preferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return PreferencesFixture(
            suiteName: suiteName,
            defaults: defaults,
            store: UserDefaultsSynchronizationPreferencesStore(
                defaults: defaults
            )
        )
    }
}

@MainActor
private struct PreferencesFixture {
    let suiteName: String
    let defaults: UserDefaults
    let store: UserDefaultsSynchronizationPreferencesStore

    func remove() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
