//
//  Trip_PlannerUITests.swift
//  Trip PlannerUITests
//
//  Created by David Heath on 7/31/26.
//

import XCTest

final class Trip_PlannerUITests: XCTestCase {
    private let uiTestScenarioEnvironmentKey = "TRIP_PLANNER_UI_TEST_SCENARIO"

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
    func testLaunchRoutingWithZeroActiveTripsShowsDashboard() throws {
        let app = launchApp(seedScenario: "zeroActive")

        XCTAssertTrue(app.navigationBars["Trip Planner"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No active trips"].exists)
        XCTAssertTrue(app.staticTexts["UI Test Planned"].exists)
        XCTAssertFalse(app.staticTexts["1 Active Trips"].exists)
    }

    @MainActor
    func testLaunchRoutingWithOneActiveTripOpensTripDetail() throws {
        let app = launchApp(seedScenario: "oneActive")

        XCTAssertTrue(app.navigationBars["Launch Active Solo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Go to Dashboard"].exists)

        app.buttons["Go to Dashboard"].firstMatch.tap()

        XCTAssertTrue(app.navigationBars["Trip Planner"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Launch Active Solo"].exists)
    }

    @MainActor
    func testLaunchRoutingWithMultipleActiveTripsShowsChooserOnce() throws {
        let app = launchApp(seedScenario: "multipleActive")

        XCTAssertTrue(app.navigationBars["Active Trips"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2 Active Trips"].exists)
        XCTAssertTrue(app.staticTexts["Launch Active Alpha"].exists)
        XCTAssertTrue(app.staticTexts["Launch Active Beta"].exists)

        app.buttons["Go to Dashboard"].firstMatch.tap()

        XCTAssertTrue(app.navigationBars["Trip Planner"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Launch Active Alpha"].exists)
        XCTAssertFalse(app.staticTexts["2 Active Trips"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    private func launchApp(seedScenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment[uiTestScenarioEnvironmentKey] = seedScenario
        app.launch()
        return app
    }
}
