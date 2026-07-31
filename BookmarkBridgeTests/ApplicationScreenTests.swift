//
//  ApplicationScreenTests.swift
//  BookmarkBridgeTests
//

import Testing
@testable import BookmarkBridge

@Suite("Application screens")
struct ApplicationScreenTests {
    @Test("The application exposes the five prepared destinations")
    func exposesPreparedDestinations() {
        #expect(
            ApplicationScreen.allCases == [
                .dashboard,
                .synchronization,
                .bookmarkAccess,
                .settings,
                .about,
            ]
        )
    }

    @Test("Every destination has a unique title and SF Symbol")
    func destinationsHaveUniquePresentation() {
        let screens = ApplicationScreen.allCases
        #expect(Set(screens.map(\.title)).count == screens.count)
        #expect(Set(screens.map(\.systemImage)).count == screens.count)
        #expect(
            screens.allSatisfy {
                !$0.title.isEmpty && !$0.systemImage.isEmpty
            }
        )
    }
}
