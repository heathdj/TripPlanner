//
//  Trip_PlannerUITests.swift
//  Trip PlannerUITests
//
//  Created by David Heath on 7/31/26.
//

import XCTest

final class Trip_PlannerUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testDashboardRemovesFlexibleTravelWindowCard() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["Trip Planner"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Flexible Travel Windows"].exists)
        XCTAssertFalse(app.staticTexts["Plan the trip length separately from when it can happen."].exists)
        XCTAssertTrue(app.staticTexts["Planned Trips"].exists)
        XCTAssertGreaterThan(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "2026")).count, 0)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
