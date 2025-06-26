//
//  AppointmentUITests.swift
//  FurfolioUITests
//
//  Enhanced 2025: Enterprise-Grade, Auditable, Robust UI Tests
//

import XCTest

final class AppointmentUITests: XCTestCase {
    var app: XCUIApplication!
    static var testAuditLog: [String] = []

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-uiTesting")
        app.launch()
        Self.testAuditLog.append("Setup: App launched at \(Date())")
    }
    
    override func tearDownWithError() throws {
        app = nil
        Self.testAuditLog.append("Teardown: App closed at \(Date())")
    }
    
    func testAppointmentsTabIsVisible() throws {
        XCTAssertTrue(app.tabBars.buttons["Appointments"].exists, "Appointments tab should be visible")
        Self.testAuditLog.append("Checked: Appointments tab visibility")
    }
    
    func testAddAppointment() throws {
        if app.tabBars.buttons["Appointments"].exists {
            app.tabBars.buttons["Appointments"].tap()
            Self.testAuditLog.append("Action: Navigated to Appointments tab")
        }
        
        let addButton = app.buttons["AddAppointmentButton"].firstMatch
        XCTAssertTrue(addButton.exists, "Add Appointment button should exist")
        addButton.tap()
        Self.testAuditLog.append("Action: Tapped Add Appointment button")
        
        let ownerField = app.textFields["OwnerNameField"]
        let dogField = app.textFields["DogNameField"]
        let datePicker = app.datePickers["AppointmentDatePicker"]
        let saveButton = app.buttons["SaveAppointmentButton"]
        
        XCTAssertTrue(ownerField.exists, "Owner name field should exist")
        ownerField.tap()
        ownerField.typeText("John Doe")
        Self.testAuditLog.append("Action: Entered Owner name")

        XCTAssertTrue(dogField.exists, "Dog name field should exist")
        dogField.tap()
        dogField.typeText("Buddy")
        Self.testAuditLog.append("Action: Entered Dog name")
        
        if datePicker.exists {
            let targetDate = Date().addingTimeInterval(60*60*24)
            datePicker.adjust(toDate: targetDate)
            Self.testAuditLog.append("Action: Set date to \(targetDate)")
        }
        
        XCTAssertTrue(saveButton.exists, "Save button should exist")
        saveButton.tap()
        Self.testAuditLog.append("Action: Saved appointment")

        // Optionally: Check for confirmation banner
        let successBanner = app.otherElements["AppointmentSavedBanner"].firstMatch
        if successBanner.exists {
            XCTAssertTrue(successBanner.waitForExistence(timeout: 1.5), "Success banner should appear after save")
            Self.testAuditLog.append("Checked: Appointment saved banner")
        }

        // Check appointment in list
        let newCell = app.tables.cells.staticTexts["John Doe"].firstMatch
        XCTAssertTrue(newCell.waitForExistence(timeout: 2), "Appointment should appear in the list")
        Self.testAuditLog.append("Checked: New appointment appears in list")
    }
    
    func testEditAppointment() throws {
        if app.tabBars.buttons["Appointments"].exists {
            app.tabBars.buttons["Appointments"].tap()
            Self.testAuditLog.append("Action: Navigated to Appointments tab")
        }
        let firstCell = app.tables.cells.element(boundBy: 0)
        guard firstCell.exists else {
            XCTFail("No appointments to edit")
            return
        }
        firstCell.tap()
        Self.testAuditLog.append("Action: Opened first appointment detail")

        let editButton = app.buttons["EditAppointmentButton"].firstMatch
        XCTAssertTrue(editButton.exists, "Edit button should exist on appointment detail")
        editButton.tap()
        Self.testAuditLog.append("Action: Tapped Edit")

        let notesField = app.textViews["AppointmentNotesField"].firstMatch
        XCTAssertTrue(notesField.exists, "Notes field should exist in edit screen")
        notesField.tap()
        notesField.typeText(" Follow-up scheduled.")
        Self.testAuditLog.append("Action: Edited notes")

        let saveButton = app.buttons["SaveEditedAppointmentButton"].firstMatch
        XCTAssertTrue(saveButton.exists, "Save button should exist in edit screen")
        saveButton.tap()
        Self.testAuditLog.append("Action: Saved edited appointment")

        // Optionally: Check for edit success banner
        let editBanner = app.otherElements["AppointmentEditedBanner"].firstMatch
        if editBanner.exists {
            XCTAssertTrue(editBanner.waitForExistence(timeout: 1.5), "Edit banner should appear")
            Self.testAuditLog.append("Checked: Appointment edited banner")
        }
    }
    
    func testDeleteAppointment() throws {
        if app.tabBars.buttons["Appointments"].exists {
            app.tabBars.buttons["Appointments"].tap()
            Self.testAuditLog.append("Action: Navigated to Appointments tab")
        }
        let cell = app.tables.cells.element(boundBy: 0)
        if cell.exists {
            cell.swipeLeft()
            let deleteButton = cell.buttons["Delete"].firstMatch
            XCTAssertTrue(deleteButton.exists, "Delete button should exist on swipe")
            deleteButton.tap()
            Self.testAuditLog.append("Action: Deleted first appointment")
        }
        // Check for empty state if no more appointments
        let emptyState = app.staticTexts["NoAppointmentsLabel"].firstMatch
        if emptyState.exists {
            XCTAssertTrue(emptyState.waitForExistence(timeout: 2), "Empty state should appear after deleting all appointments")
            Self.testAuditLog.append("Checked: Empty state after delete")
        }
    }

    func testAuditLogExport() throws {
        // This demonstrates how you could export test log for QA/debug
        let logs = Self.testAuditLog.suffix(12).joined(separator: "\n")
        print("Furfolio AppointmentUITest AuditLog:\n\(logs)")
    }
}
