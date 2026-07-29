//
//  BookmarkBridgeUITests.swift
//  BookmarkBridgeUITests
//
//  Created by Jerome on 15/07/2026.
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
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
