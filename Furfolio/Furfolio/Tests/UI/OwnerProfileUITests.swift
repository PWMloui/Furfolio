//
//  OwnerProfileUITests.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import XCTest

final class OwnerProfileUITests: XCTestCase {

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

    func testOwnerProfileScreenAppears() {
        // Simulate navigation to an owner profile (after adding demo/sample data)
        let ownersTab = app.buttons["Tab_Owners"]
        XCTAssertTrue(ownersTab.exists, "Owners tab should exist")
        ownersTab.tap()

        // Tap on the first owner in the list (ensure accessibilityIdentifier is set in the row)
        let firstOwnerRow = app.cells["OwnerRow_0"]
        XCTAssertTrue(firstOwnerRow.waitForExistence(timeout: 2), "At least one owner should appear in the list")
        firstOwnerRow.tap()

        // Check that Owner Profile is visible
        let profileTitle = app.staticTexts["OwnerProfile_Title"]
        XCTAssertTrue(profileTitle.waitForExistence(timeout: 2), "Owner profile view should be visible")
    }

    func testEditOwnerInfo() {
        // Go to owner profile first
        let ownersTab = app.buttons["Tab_Owners"]
        ownersTab.tap()
        let firstOwnerRow = app.cells["OwnerRow_0"]
        firstOwnerRow.tap()

        // Tap edit button
        let editButton = app.buttons["EditOwner_Button"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 2), "Edit button should be present on profile")
        editButton.tap()

        // Edit name field
        let nameField = app.textFields["EditOwner_Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2), "Name textfield should be present")
        nameField.tap()
        nameField.clearAndEnterText(text: "Updated Owner")

        // Save
        let saveButton = app.buttons["SaveOwner_Button"]
        XCTAssertTrue(saveButton.exists, "Save button should be present")
        saveButton.tap()

        // Verify update
        let updatedName = app.staticTexts["OwnerProfile_Name"]
        XCTAssertTrue(updatedName.waitForExistence(timeout: 2), "Updated name should be visible")
        XCTAssertEqual(updatedName.label, "Updated Owner")
    }

    func testOwnerProfileNavigationBack() {
        let ownersTab = app.buttons["Tab_Owners"]
        ownersTab.tap()
        let firstOwnerRow = app.cells["OwnerRow_0"]
        firstOwnerRow.tap()

        let backButton = app.navigationBars.buttons["Back"]
        XCTAssertTrue(backButton.exists, "Back button should exist on profile")
        backButton.tap()
        XCTAssertTrue(firstOwnerRow.exists, "Should return to owner list")
    }
}

// MARK: - Helper extension for clearing and entering text

extension XCUIElement {
    func clearAndEnterText(text: String) {
        guard let stringValue = self.value as? String else {
            self.tap()
            self.typeText(text)
            return
        }
        self.tap()
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
        self.typeText(text)
    }
}
