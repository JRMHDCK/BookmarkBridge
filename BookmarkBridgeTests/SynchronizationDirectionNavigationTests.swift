//
//  SynchronizationDirectionNavigationTests.swift
//  BookmarkBridgeTests
//

import Testing
@testable import BookmarkBridge

@MainActor
@Suite("Synchronization direction navigation")
struct SynchronizationDirectionNavigationTests {
    @Test("The direction model exposes exactly both supported routes")
    func directions() {
        #expect(SynchronizationDirectionOption.allCases == [
            .safariToChrome,
            .chromeToSafari,
        ])
        #expect(SynchronizationDirectionOption.safariToChrome.title ==
            "Safari → Chrome")
        #expect(SynchronizationDirectionOption.chromeToSafari.title ==
            "Chrome → Safari")
        #expect(SynchronizationDirectionOption.safariToChrome.previewDirection
            == .safariToChrome)
        #expect(SynchronizationDirectionOption.chromeToSafari.previewDirection
            == .chromeToSafari)
    }

    @Test("Each destination returns to direction selection")
    func backNavigation() {
        let navigation = SynchronizationDirectionNavigation()

        navigation.select(.safariToChrome)
        #expect(navigation.selectedDirection == .safariToChrome)
        navigation.goBack()
        #expect(navigation.selectedDirection == nil)

        navigation.select(.chromeToSafari)
        #expect(navigation.selectedDirection == .chromeToSafari)
        navigation.goBack()
        #expect(navigation.selectedDirection == nil)
    }

    @Test("The last direction is saved and restored")
    func directionPersistence() {
        let store = InMemorySynchronizationPreferencesStore()
        let first = SynchronizationDirectionNavigation(
            preferencesStore: store
        )

        #expect(first.selectedDirection == nil)
        first.select(.chromeToSafari)

        let restored = SynchronizationDirectionNavigation(
            preferencesStore: store
        )
        #expect(restored.selectedDirection == .chromeToSafari)
    }

    @Test("An unknown persisted direction is ignored")
    func invalidDirectionIsIgnored() {
        var preferences = SynchronizationPreferences()
        preferences.selectedDirectionRawValue = "unsupported"
        let navigation = SynchronizationDirectionNavigation(
            preferencesStore: InMemorySynchronizationPreferencesStore(
                preferences: preferences
            )
        )

        #expect(navigation.selectedDirection == nil)
    }
}
