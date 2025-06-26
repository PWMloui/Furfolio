//
//  OwnerProfileUITests.swift
//  Furfolio
//
//  Enhanced 2025: Enterprise-Grade, Auditable, Robust UI Tests
//

import XCTest

final class OwnerProfileUITests: XCTestCase {

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

    func testOwnerProfileScreenAppears() {
        let ownersTab = app.buttons["Tab_Owners"]
        XCTAssertTrue(ownersTab.exists, "Owners tab should exist")
        ownersTab.tap()
        Self.testAuditLog.append("Action: Tapped Owners tab")

        let firstOwnerRow = app.cells["OwnerRow_0"]
        XCTAssertTrue(firstOwnerRow.waitForExistence(timeout: 2), "At least one owner should appear in the list")
        Self.testAuditLog.append("Checked: First owner row is visible")
        firstOwnerRow.tap()
        Self.testAuditLog.append("Action: Tapped first owner row")

        let profileTitle = app.staticTexts["OwnerProfile_Title"]
        XCTAssertTrue(profileTitle.waitForExistence(timeout: 2), "Owner profile view should be visible")
        Self.testAuditLog.append("Checked: Owner profile view is visible")
    }

    func testEditOwnerInfo() {
        let ownersTab = app.buttons["Tab_Owners"]
        ownersTab.tap()
        Self.testAuditLog.append("Action: Tapped Owners tab")

        let firstOwnerRow = app.cells["OwnerRow_0"]
        firstOwnerRow.tap()
        Self.testAuditLog.append("Action: Tapped first owner row")

        let editButton = app.buttons["EditOwner_Button"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 2), "Edit button should be present on profile")
        Self.testAuditLog.append("Checked: Edit button exists")
        editButton.tap()
        Self.testAuditLog.append("Action: Tapped edit button")

        let nameField = app.textFields["EditOwner_Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2), "Name textfield should be present")
        Self.testAuditLog.append("Checked: Name textfield exists")
        nameField.tap()
        nameField.clearAndEnterText(text: "Updated Owner")
        Self.testAuditLog.append("Action: Updated owner name")

        let saveButton = app.buttons["SaveOwner_Button"]
        XCTAssertTrue(saveButton.exists, "Save button should be present")
        Self.testAuditLog.append("Checked: Save button exists")
        saveButton.tap()
        Self.testAuditLog.append("Action: Tapped save button")

        let updatedName = app.staticTexts["OwnerProfile_Name"]
        XCTAssertTrue(updatedName.waitForExistence(timeout: 2), "Updated name should be visible")
        XCTAssertEqual(updatedName.label, "Updated Owner", "Owner name should be updated")
        Self.testAuditLog.append("Checked: Owner name updated to 'Updated Owner'")
    }

    func testOwnerProfileNavigationBack() {
        let ownersTab = app.buttons["Tab_Owners"]
        ownersTab.tap()
        Self.testAuditLog.append("Action: Tapped Owners tab")

        let firstOwnerRow = app.cells["OwnerRow_0"]
        firstOwnerRow.tap()
        Self.testAuditLog.append("Action: Tapped first owner row")

        let backButton = app.navigationBars.buttons["Back"]
        XCTAssertTrue(backButton.exists, "Back button should exist on profile")
        Self.testAuditLog.append("Checked: Back button exists")
        backButton.tap()
        Self.testAuditLog.append("Action: Tapped back button")
        XCTAssertTrue(firstOwnerRow.exists, "Should return to owner list")
        Self.testAuditLog.append("Checked: Returned to owner list")
    }

    func testAuditLogExport() {
        // Export the last 10 steps for QA/diagnostics
        let logs = Self.testAuditLog.suffix(10).joined(separator: "\n")
        print("Furfolio OwnerProfileUITests AuditLog:\n\(logs)")
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
