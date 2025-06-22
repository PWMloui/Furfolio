//
//  AppointmentUITests.swift
//  FurfolioUITests
//
//  Created by mac on 6/21/25.
//

import XCTest

final class AppointmentUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-uiTesting")
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    func testAppointmentsTabIsVisible() throws {
        // Test that the Appointments tab exists
        XCTAssertTrue(app.tabBars.buttons["Appointments"].exists)
    }
    
    func testAddAppointment() throws {
        // Navigate to Appointments tab if needed
        if app.tabBars.buttons["Appointments"].exists {
            app.tabBars.buttons["Appointments"].tap()
        }
        
        // Tap Add (+) button
        let addButton = app.buttons["AddAppointmentButton"].firstMatch
        XCTAssertTrue(addButton.exists, "Add Appointment button should exist")
        addButton.tap()
        
        // Fill out the form (replace identifiers as needed)
        let ownerField = app.textFields["OwnerNameField"]
        let dogField = app.textFields["DogNameField"]
        let datePicker = app.datePickers["AppointmentDatePicker"]
        let saveButton = app.buttons["SaveAppointmentButton"]
        
        XCTAssertTrue(ownerField.exists)
        ownerField.tap()
        ownerField.typeText("John Doe")
        
        XCTAssertTrue(dogField.exists)
        dogField.tap()
        dogField.typeText("Buddy")
        
        // Optionally set the date/time
        if datePicker.exists {
            datePicker.adjust(toDate: Date().addingTimeInterval(60*60*24))
        }
        
        XCTAssertTrue(saveButton.exists)
        saveButton.tap()
        
        // Check that appointment is now in the list
        let newCell = app.tables.cells.staticTexts["John Doe"].firstMatch
        XCTAssertTrue(newCell.waitForExistence(timeout: 2), "Appointment should appear in the list")
    }
    
    func testDeleteAppointment() throws {
        if app.tabBars.buttons["Appointments"].exists {
            app.tabBars.buttons["Appointments"].tap()
        }
        let cell = app.tables.cells.element(boundBy: 0)
        if cell.exists {
            cell.swipeLeft()
            let deleteButton = cell.buttons["Delete"].firstMatch
            if deleteButton.exists {
                deleteButton.tap()
            }
            // Optionally check for empty state or decreased count
        }
    }
}
