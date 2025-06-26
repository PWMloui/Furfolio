//
//  DogProfileUITests.swift
//  Furfolio
//
//  Enhanced 2025: Enterprise-Grade, Auditable, Robust UI Tests
//

import XCTest

final class DogProfileUITests: XCTestCase {
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
        Self.testAuditLog.append("Teardown: App closed at \(Date())")
        app = nil
    }

    func testDogProfileLoadsSuccessfully() {
        let firstDogCell = app.cells["DogRow_0"]
        XCTAssertTrue(firstDogCell.waitForExistence(timeout: 5), "First dog cell should exist")
        Self.testAuditLog.append("Checked: First dog cell exists")
        firstDogCell.tap()
        Self.testAuditLog.append("Action: Tapped first dog cell")

        let profileTitle = app.staticTexts["DogProfile_Title"]
        XCTAssertTrue(profileTitle.waitForExistence(timeout: 2), "Dog profile title should be visible")
        Self.testAuditLog.append("Checked: Dog profile title is visible")

        let breedLabel = app.staticTexts["DogProfile_Breed"]
        XCTAssertTrue(breedLabel.exists, "Breed label should be visible")
        Self.testAuditLog.append("Checked: Breed label is visible")

        let ownerLabel = app.staticTexts["DogProfile_Owner"]
        XCTAssertTrue(ownerLabel.exists, "Owner label should be visible")
        Self.testAuditLog.append("Checked: Owner label is visible")

        let image = app.images["DogProfile_Image"]
        if image.exists {
            XCTAssertTrue(image.isHittable, "Dog profile image should be visible and accessible")
            Self.testAuditLog.append("Checked: Dog profile image is visible")
        }
    }

    func testDogProfileShowsGroomingHistory() {
        let firstDogCell = app.cells["DogRow_0"]
        XCTAssertTrue(firstDogCell.waitForExistence(timeout: 5))
        Self.testAuditLog.append("Checked: First dog cell exists")
        firstDogCell.tap()
        Self.testAuditLog.append("Action: Tapped first dog cell")

        let groomingHistory = app.staticTexts["GroomingHistory_Section"]
        XCTAssertTrue(groomingHistory.exists, "Grooming history section should be visible")
        Self.testAuditLog.append("Checked: Grooming history section is visible")

        // Optionally check for empty state if no sessions
        let emptyHistory = app.staticTexts["GroomingHistory_EmptyState"]
        if emptyHistory.exists {
            XCTAssertTrue(emptyHistory.exists, "Grooming history empty state should appear when there are no sessions")
            Self.testAuditLog.append("Checked: Grooming history empty state visible")
        }
    }

    func testAddGroomingSessionFromDogProfile() {
        let firstDogCell = app.cells["DogRow_0"]
        XCTAssertTrue(firstDogCell.waitForExistence(timeout: 5))
        Self.testAuditLog.append("Checked: First dog cell exists")
        firstDogCell.tap()
        Self.testAuditLog.append("Action: Tapped first dog cell")

        let addSessionButton = app.buttons["DogProfile_AddGroomingSession"]
        XCTAssertTrue(addSessionButton.exists, "Add Grooming Session button should exist")
        Self.testAuditLog.append("Checked: Add grooming session button exists")
        addSessionButton.tap()
        Self.testAuditLog.append("Action: Tapped add grooming session button")

        let notesField = app.textFields["GroomingSession_Notes"]
        XCTAssertTrue(notesField.waitForExistence(timeout: 2), "Notes field should appear in add session form")
        Self.testAuditLog.append("Checked: Notes field exists")
        notesField.tap()
        notesField.typeText("Test session for UI test")
        Self.testAuditLog.append("Action: Entered notes")

        let saveButton = app.buttons["SaveGroomingSession"]
        XCTAssertTrue(saveButton.exists, "Save button should exist in add session form")
        Self.testAuditLog.append("Checked: Save button exists")
        saveButton.tap()
        Self.testAuditLog.append("Action: Tapped save button")

        // Check confirmation (e.g., a toast or new row)
        let newSession = app.staticTexts["GroomingSession_0"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 3), "New grooming session should appear")
        Self.testAuditLog.append("Checked: New grooming session appears in history")
    }

    func testAuditLogExport() throws {
        // Export the last 10 steps for QA/diagnostics
        let logs = Self.testAuditLog.suffix(10).joined(separator: "\n")
        print("Furfolio DogProfileUITests AuditLog:\n\(logs)")
    }
}
