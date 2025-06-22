//
//  OnboardingUITests.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import XCTest

final class OnboardingUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui_testing"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testOnboardingWelcomeScreenIsShown() {
        // Check welcome view appears on first launch
        let welcomeTitle = app.staticTexts["Onboarding_Welcome_Title"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 3), "Welcome screen should appear")
    }

    func testOnboardingStepNavigation() {
        // Assume "Next" button is used to go through steps
        let nextButton = app.buttons["Onboarding_Next"]
        XCTAssertTrue(nextButton.exists, "Next button should exist on onboarding")
        nextButton.tap()

        let permissionTitle = app.staticTexts["Onboarding_Permission_Title"]
        XCTAssertTrue(permissionTitle.waitForExistence(timeout: 2), "Permission step should show after next")
    }

    func testPermissionRequestAppears() {
        // Navigate to permissions step
        let nextButton = app.buttons["Onboarding_Next"]
        XCTAssertTrue(nextButton.exists)
        nextButton.tap()

        let permissionButton = app.buttons["Onboarding_Permission_Allow"]
        XCTAssertTrue(permissionButton.waitForExistence(timeout: 2), "Permission allow button should be visible")
    }

    func testOnboardingCompletion() {
        // Navigate through all steps
        let nextButton = app.buttons["Onboarding_Next"]

        // Tap through all onboarding steps (repeat if needed)
        for _ in 1...3 {
            if nextButton.waitForExistence(timeout: 2) {
                nextButton.tap()
            }
        }

        // Assume final screen has a "Get Started" or "Finish" button
        let finishButton = app.buttons["Onboarding_Finish"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 2), "Finish button should exist at end of onboarding")
        finishButton.tap()

        // App should now show main content, e.g., dashboard
        let dashboardTitle = app.staticTexts["Dashboard_Title"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 3), "Dashboard should appear after finishing onboarding")
    }
}
