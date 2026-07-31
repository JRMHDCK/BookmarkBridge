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
}
