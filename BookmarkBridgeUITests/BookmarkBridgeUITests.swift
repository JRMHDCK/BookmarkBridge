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
    func testHelpCenterPreparesManualBugReport() throws {
        let app = XCUIApplication()
        app.launchEnvironment[
            "BOOKMARKBRIDGE_UI_TEST_SKIP_ONBOARDING"
        ] = "1"
        app.launchEnvironment[
            "BOOKMARKBRIDGE_UI_TEST_BUG_REPORT_COMPOSER"
        ] = "1"
        app.launchEnvironment[
            "BOOKMARKBRIDGE_UI_TEST_HELP_CENTER"
        ] = "1"
        app.launch()
        dismissBrowserClosureIfNeeded(in: app)

        let reportButton = app.buttons["bug-report.help"].firstMatch
        XCTAssertTrue(reportButton.waitForExistence(timeout: 3))
        reportButton.click()

        XCTAssertTrue(
            app.buttons["bug-report.help.ready"].firstMatch
                .waitForExistence(timeout: 3)
        )
        XCTAssertEqual(app.windows.count, 1)
    }

    @MainActor
    func testContextualErrorPreparesBugReport() throws {
        let app = XCUIApplication()
        app.launchEnvironment[
            "BOOKMARKBRIDGE_UI_TEST_SKIP_ONBOARDING"
        ] = "1"
        app.launchEnvironment[
            "BOOKMARKBRIDGE_UI_TEST_BUG_REPORT_COMPOSER"
        ] = "1"
        app.launchEnvironment[
            "BOOKMARKBRIDGE_UI_TEST_SYNC_FAILURE"
        ] = "1"
        app.launchEnvironment[
            "BOOKMARKBRIDGE_UI_TEST_HELP_AFTER_BUG_REPORT"
        ] = "1"
        app.launch()
        dismissBrowserClosureIfNeeded(in: app)

        let reportButton = app.buttons[
            "bug-report.contextual"
        ].firstMatch
        XCTAssertTrue(reportButton.waitForExistence(timeout: 3))
        reportButton.click()

        XCTAssertTrue(
            app.buttons["bug-report.help.ready"].firstMatch
                .waitForExistence(timeout: 3)
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
        click(settingsDestination, in: app)

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
        click(restoredSettings, in: relaunched)
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
    private func click(
        _ element: XCUIElement,
        in app: XCUIApplication
    ) {
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
        if element.isHittable {
            element.click()
            return
        }

        let frame = element.frame
        XCTAssertFalse(frame.isEmpty)
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.midX, dy: frame.midY))
            .click()
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
        dismissBrowserClosureIfNeeded(in: app)
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

        let appMenu = app.menuBars.menuBarItems["BookmarkBridge"]
        XCTAssertTrue(appMenu.waitForExistence(timeout: 5))
        appMenu.click()
        let aboutLabels = [
            "About BookmarkBridge",
            "À propos de BookmarkBridge",
            "Acerca de BookmarkBridge",
            "Über BookmarkBridge",
            "Informazioni su BookmarkBridge",
            "Sobre o BookmarkBridge",
            "Over BookmarkBridge",
            "Informacje o BookmarkBridge",
        ]
        let about = app.menuItems.matching(
            NSPredicate(format: "title IN %@", aboutLabels)
        ).firstMatch
        XCTAssertTrue(about.waitForExistence(timeout: 3))
        about.click()

        XCTAssertTrue(
            app.images["about.applicationIcon"]
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
