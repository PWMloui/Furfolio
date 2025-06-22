
//
//  DashboardUITests.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import XCTest

final class DashboardUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments.append("-ui-testing")
        app.launch()
    }

    func testDashboardLoadsAndShowsKPI() throws {
        // Wait for dashboard (using a unique accessibilityIdentifier)
        let dashboard = app.otherElements["DashboardView"]
        XCTAssertTrue(dashboard.waitForExistence(timeout: 5))

        // Check at least one metric card is visible
        let metricCard = app.staticTexts["RevenueKPIStatCard"]
        XCTAssertTrue(metricCard.exists)
    }

    func testDashboardTabNavigation() throws {
        // Go to another tab and back (tab bar item should be present)
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        let ownersTab = app.tabBars.buttons["Owners"]
        XCTAssertTrue(dashboardTab.exists)
        XCTAssertTrue(ownersTab.exists)
        ownersTab.tap()
        dashboardTab.tap()
        // Still on dashboard
        XCTAssertTrue(app.otherElements["DashboardView"].exists)
    }

    // You can expand with more tests, like:
    // - testDashboardFilter
    // - testChartAnimation
    // - testTapKPIShowsDetail
}

