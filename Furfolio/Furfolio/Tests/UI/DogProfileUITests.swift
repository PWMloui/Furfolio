//
//  DogProfileUITests.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import XCTest

final class DogProfileUITests: XCTestCase {
    
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
    
    func testDogProfileLoadsSuccessfully() {
        // Assumes a list of dogs is shown after app launch
        
        // Tap the first dog in the list
        let firstDogCell = app.cells["DogRow_0"]
        XCTAssertTrue(firstDogCell.waitForExistence(timeout: 5), "First dog cell should exist")
        firstDogCell.tap()
        
        // Check that profile view is displayed
        let profileTitle = app.staticTexts["DogProfile_Title"]
        XCTAssertTrue(profileTitle.waitForExistence(timeout: 2), "Dog profile title should be visible")
        
        // Check that important info is shown
        let breedLabel = app.staticTexts["DogProfile_Breed"]
        XCTAssertTrue(breedLabel.exists, "Breed label should be visible")
        
        let ownerLabel = app.staticTexts["DogProfile_Owner"]
        XCTAssertTrue(ownerLabel.exists, "Owner label should be visible")
    }
    
    func testDogProfileShowsGroomingHistory() {
        // Tap the first dog
        let firstDogCell = app.cells["DogRow_0"]
        XCTAssertTrue(firstDogCell.waitForExistence(timeout: 5))
        firstDogCell.tap()
        
        // Check for grooming history section
        let groomingHistory = app.staticTexts["GroomingHistory_Section"]
        XCTAssertTrue(groomingHistory.exists, "Grooming history section should be visible")
    }
    
    func testAddGroomingSessionFromDogProfile() {
        // Tap the first dog
        let firstDogCell = app.cells["DogRow_0"]
        XCTAssertTrue(firstDogCell.waitForExistence(timeout: 5))
        firstDogCell.tap()
        
        // Tap add grooming session button
        let addSessionButton = app.buttons["DogProfile_AddGroomingSession"]
        XCTAssertTrue(addSessionButton.exists)
        addSessionButton.tap()
        
        // Fill form (example)
        let notesField = app.textFields["GroomingSession_Notes"]
        XCTAssertTrue(notesField.waitForExistence(timeout: 2))
        notesField.tap()
        notesField.typeText("Test session for UI test")
        
        let saveButton = app.buttons["SaveGroomingSession"]
        XCTAssertTrue(saveButton.exists)
        saveButton.tap()
        
        // Check confirmation (e.g., a toast or new row)
        let newSession = app.staticTexts["GroomingSession_0"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 3), "New grooming session should appear")
    }
}
