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
    func testDocumentationStaysInTheMainWindow() throws {
        let app = XCUIApplication()
        app.launchEnvironment[
            "BOOKMARKBRIDGE_UI_TEST_SKIP_ONBOARDING"
        ] = "1"
        app.launch()
        dismissBrowserClosureIfNeeded(in: app)
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.windows.count, 1)

        app.typeKey("n", modifierFlags: .command)
        XCTAssertEqual(app.windows.count, 1)

        app.typeKey("/", modifierFlags: [.command, .shift])
        XCTAssertTrue(
            app.searchFields.firstMatch
                .waitForExistence(timeout: 2)
        )
        XCTAssertEqual(app.windows.count, 1)
    }

    @MainActor
    func testLanguageChangesImmediatelyAndPersists() throws {
        let app = XCUIApplication()
        app.launchEnvironment[
            "BOOKMARKBRIDGE_UI_TEST_SKIP_ONBOARDING"
        ] = "1"
        app.launch()
        dismissBrowserClosureIfNeeded(in: app)

        let settingsDestination = app.descendants(matching: .any)[
            "navigation.settings"
        ].firstMatch
        XCTAssertTrue(settingsDestination.waitForExistence(timeout: 5))
        settingsDestination.click()

        let picker = app.popUpButtons["settings.language.picker"].firstMatch
        XCTAssertTrue(
            picker.waitForExistence(timeout: 3),
            app.debugDescription
        )
        picker.click()
        let german = app.descendants(matching: .any)[
            "settings.language.option.de"
        ].firstMatch
        XCTAssertTrue(german.waitForExistence(timeout: 2))
        german.click()
        XCTAssertEqual(picker.value as? String, "Deutsch")
        app.terminate()

        let relaunched = XCUIApplication()
        relaunched.launchEnvironment[
            "BOOKMARKBRIDGE_UI_TEST_SKIP_ONBOARDING"
        ] = "1"
        relaunched.launch()
        dismissBrowserClosureIfNeeded(in: relaunched)
        let restoredSettings = relaunched.descendants(matching: .any)[
            "navigation.settings"
        ].firstMatch
        XCTAssertTrue(restoredSettings.waitForExistence(timeout: 5))
        restoredSettings.click()
        let restoredPicker = relaunched.popUpButtons[
            "settings.language.picker"
        ].firstMatch
        XCTAssertTrue(restoredPicker.waitForExistence(timeout: 3))
        XCTAssertEqual(restoredPicker.value as? String, "Deutsch")

        restoredPicker.click()
        relaunched.menuItems.element(boundBy: 0).click()
        relaunched.terminate()
    }

    @MainActor
    private func dismissBrowserClosureIfNeeded(
        in app: XCUIApplication
    ) {
        let cancel = app.buttons["action-button-2"].firstMatch
        if cancel.waitForExistence(timeout: 1) {
            cancel.click()
        }
    }

    @MainActor
    func testClosingMainWindowTerminatesApplication() throws {
        let app = XCUIApplication()
        app.launchEnvironment[
            "BOOKMARKBRIDGE_UI_TEST_SKIP_ONBOARDING"
        ] = "1"
        app.launch()

        app.typeKey("w", modifierFlags: .command)

        let stopped = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                app.state == .notRunning
            },
            object: nil
        )
        wait(for: [stopped], timeout: 3)
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
