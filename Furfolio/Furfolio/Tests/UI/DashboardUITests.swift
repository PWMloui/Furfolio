//
//  DashboardUITests.swift
//  Furfolio
//
//  Enhanced 2025: Enterprise-Grade, Auditable, Robust UI Tests
//

import XCTest

final class DashboardUITests: XCTestCase {
    let app = XCUIApplication()
    static var testAuditLog: [String] = []

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments.append("-ui-testing")
        app.launch()
        Self.testAuditLog.append("Setup: App launched at \(Date())")
    }

    override func tearDownWithError() throws {
        Self.testAuditLog.append("Teardown: App closed at \(Date())")
    }

    func testDashboardLoadsAndShowsKPI() throws {
        let dashboard = app.otherElements["DashboardView"]
        XCTAssertTrue(dashboard.waitForExistence(timeout: 5), "Dashboard should load within 5 seconds")
        Self.testAuditLog.append("Checked: DashboardView loaded")
        let metricCard = app.staticTexts["RevenueKPIStatCard"]
        XCTAssertTrue(metricCard.exists, "At least one metric card (RevenueKPIStatCard) should be visible")
        Self.testAuditLog.append("Checked: Revenue KPI stat card visible")
    }

    func testDashboardTabNavigation() throws {
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        let ownersTab = app.tabBars.buttons["Owners"]
        XCTAssertTrue(dashboardTab.exists, "Dashboard tab should be present")
        XCTAssertTrue(ownersTab.exists, "Owners tab should be present")
        ownersTab.tap()
        Self.testAuditLog.append("Action: Switched to Owners tab")
        dashboardTab.tap()
        Self.testAuditLog.append("Action: Returned to Dashboard tab")
        XCTAssertTrue(app.otherElements["DashboardView"].exists, "Dashboard view should exist after tab switch")
    }

    func testDashboardFilterBar() throws {
        let dashboard = app.otherElements["DashboardView"]
        XCTAssertTrue(dashboard.waitForExistence(timeout: 5), "Dashboard should load for filter test")
        let filterBar = app.otherElements["DashboardFilterBar"]
        XCTAssertTrue(filterBar.exists, "Dashboard filter bar should be visible")
        Self.testAuditLog.append("Checked: Filter bar visible")
        let filterButton = filterBar.buttons.element(boundBy: 0)
        if filterButton.exists {
            filterButton.tap()
            Self.testAuditLog.append("Action: Tapped first filter button")
        }
        // Optionally verify filtered result (add identifier to filtered chart/card in app for best testability)
    }

    func testDashboardChartAnimation() throws {
        let dashboard = app.otherElements["DashboardView"]
        XCTAssertTrue(dashboard.waitForExistence(timeout: 5), "Dashboard should load for chart animation test")
        let chart = app.otherElements["DashboardChart"]
        XCTAssertTrue(chart.exists, "Dashboard chart should be visible")
        chart.swipeLeft()
        chart.swipeRight()
        Self.testAuditLog.append("Action: Swiped left and right on chart")
        // Optionally verify animation by checking a changed state or chart page identifier
    }

    func testTapKPIShowsDetail() throws {
        let dashboard = app.otherElements["DashboardView"]
        XCTAssertTrue(dashboard.waitForExistence(timeout: 5), "Dashboard should load for KPI tap test")
        let metricCard = app.staticTexts["RevenueKPIStatCard"]
        XCTAssertTrue(metricCard.exists, "Metric card should exist")
        metricCard.tap()
        Self.testAuditLog.append("Action: Tapped Revenue KPI stat card")
        let detail = app.otherElements["RevenueDetailView"]
        XCTAssertTrue(detail.waitForExistence(timeout: 2), "Revenue detail view should appear after tap")
        Self.testAuditLog.append("Checked: Revenue detail view appeared")
    }

    func testAuditLogExport() throws {
        // Export test audit log for QA/debug (optional)
        let logs = Self.testAuditLog.suffix(16).joined(separator: "\n")
        print("Furfolio DashboardUITests AuditLog:\n\(logs)")
    }
}
