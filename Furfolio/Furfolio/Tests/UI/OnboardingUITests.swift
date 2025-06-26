//
//  OnboardingUITests.swift
//  Furfolio
//
//  Enhanced 2025: Enterprise-Grade, Auditable, Robust UI Tests
//

import XCTest

final class OnboardingUITests: XCTestCase {

    private var app: XCUIApplication!
    static var testAuditLog: [String] = []

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui_testing"]
        app.launch()
        Self.testAuditLog.append("Setup: App launched at \(Date())")
    }

    override func tearDownWithError() throws {
        app = nil
        Self.testAuditLog.append("Teardown: App closed at \(Date())")
    }

    func testOnboardingWelcomeScreenIsShown() {
        let welcomeTitle = app.staticTexts["Onboarding_Welcome_Title"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 3), "Welcome screen should appear")
        Self.testAuditLog.append("Checked: Welcome screen is visible")
    }

    func testOnboardingStepNavigation() {
        let nextButton = app.buttons["Onboarding_Next"]
        XCTAssertTrue(nextButton.exists, "Next button should exist on onboarding")
        nextButton.tap()
        Self.testAuditLog.append("Action: Tapped Next on onboarding")

        let permissionTitle = app.staticTexts["Onboarding_Permission_Title"]
        XCTAssertTrue(permissionTitle.waitForExistence(timeout: 2), "Permission step should show after next")
        Self.testAuditLog.append("Checked: Permission step is shown")
    }

    func testPermissionRequestAppears() {
        let nextButton = app.buttons["Onboarding_Next"]
        XCTAssertTrue(nextButton.exists)
        nextButton.tap()
        Self.testAuditLog.append("Action: Advanced to permission step")

        let permissionButton = app.buttons["Onboarding_Permission_Allow"]
        XCTAssertTrue(permissionButton.waitForExistence(timeout: 2), "Permission allow button should be visible")
        Self.testAuditLog.append("Checked: Permission allow button is visible")
    }

    func testOnboardingCompletion() {
        let nextButton = app.buttons["Onboarding_Next"]
        for i in 1...3 {
            if nextButton.waitForExistence(timeout: 2) {
                nextButton.tap()
                Self.testAuditLog.append("Action: Tapped Next step \(i)")
            }
        }
        let finishButton = app.buttons["Onboarding_Finish"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 2), "Finish button should exist at end of onboarding")
        finishButton.tap()
        Self.testAuditLog.append("Action: Finished onboarding")

        let dashboardTitle = app.staticTexts["Dashboard_Title"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 3), "Dashboard should appear after finishing onboarding")
        Self.testAuditLog.append("Checked: Dashboard appears after onboarding")
    }

    func testOnboardingSkip() {
        // If your onboarding flow supports skipping
        let skipButton = app.buttons["Onboarding_Skip"]
        if skipButton.exists {
            skipButton.tap()
            Self.testAuditLog.append("Action: Skipped onboarding")
            let dashboardTitle = app.staticTexts["Dashboard_Title"]
            XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 3), "Dashboard should appear after skipping onboarding")
            Self.testAuditLog.append("Checked: Dashboard appears after skipping onboarding")
        }
    }

    func testPermissionDeniedFlow() {
        // If you support a denial/negative path
        let nextButton = app.buttons["Onboarding_Next"]
        if nextButton.exists { nextButton.tap() }
        let denyButton = app.buttons["Onboarding_Permission_Deny"]
        if denyButton.exists {
            denyButton.tap()
            Self.testAuditLog.append("Action: Denied permission")
            let errorLabel = app.staticTexts["Onboarding_Permission_Denied_Label"]
            XCTAssertTrue(errorLabel.exists, "Permission denied label should show")
            Self.testAuditLog.append("Checked: Permission denied label is visible")
        }
    }

    func testAuditLogExport() {
        // Export the last 10 steps for QA/diagnostics
        let logs = Self.testAuditLog.suffix(10).joined(separator: "\n")
        print("Furfolio OnboardingUITests AuditLog:\n\(logs)")
    }
}
