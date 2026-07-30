//
//  BookmarkBridgeUITests.swift
//  BookmarkBridgeUITests
//
//  Created by Jérôme Hudecek on 15/07/2026.
//

import XCTest

final class BookmarkBridgeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testApplicationLaunches() throws {
        let app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testFirstLaunchOnboardingCanBeCompleted() throws {
        let app = XCUIApplication()
        app.launchEnvironment[
            "BOOKMARKBRIDGE_UI_TEST_ONBOARDING"
        ] = "1"
        app.launch()
        app.typeKey("n", modifierFlags: .command)

        let primaryButton = app.buttons[
            "documentation.onboarding.primary"
        ]
        XCTAssertTrue(
            primaryButton.waitForExistence(timeout: 5)
        )

        let stepIdentifiers = [
            "welcome",
            "overview",
            "workflow",
            "privacy",
            "safari",
            "chrome",
            "firstSync",
            "finish",
        ]
        for identifier in stepIdentifiers {
            let step = app.descendants(
                matching: .any
            )[
                "documentation.onboarding.\(identifier)"
            ].firstMatch
            XCTAssertTrue(
                step.waitForExistence(timeout: 2)
            )
            primaryButton.click()
        }

        XCTAssertFalse(
            primaryButton.waitForExistence(timeout: 1)
        )
    }

    @MainActor
    func testHelpMenuOpensDocumentationWindows() throws {
        let app = XCUIApplication()
        app.launchEnvironment[
            "BOOKMARKBRIDGE_UI_TEST_SKIP_ONBOARDING"
        ] = "1"
        app.launch()
        app.typeKey("n", modifierFlags: .command)

        let helpMenu = app.menuBars.menuBarItems["Aide"]
        helpMenu.click()
        helpMenu.menus.menuItems["Aide BookmarkBridge"].click()
        let helpWindow = app.windows[
            "documentation.help-center"
        ]
        XCTAssertTrue(
            helpWindow.waitForExistence(timeout: 3)
        )
        XCTAssertTrue(
            helpWindow.searchFields.firstMatch
                .waitForExistence(timeout: 2)
        )

        app.typeKey("w", modifierFlags: .command)
        helpMenu.click()
        helpMenu.menus.menuItems["Nouveautés"].click()
        XCTAssertTrue(
            app.windows["documentation.whats-new"]
                .waitForExistence(timeout: 3)
        )
    }

    @MainActor
    func testAboutShowsApplicationIcon() throws {
        let app = XCUIApplication()
        app.launchEnvironment[
            "BOOKMARKBRIDGE_UI_TEST_SKIP_ONBOARDING"
        ] = "1"
        app.launch()

        let appMenu = app.menuBars.menuBarItems["BookmarkBridge"]
        appMenu.click()
        appMenu.menus.menuItems["À propos de BookmarkBridge"].click()

        XCTAssertTrue(
            app.images["Logo BookmarkBridge"]
                .waitForExistence(timeout: 3)
        )
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
