//
//  AppointmentTests.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import XCTest
@testable import Furfolio

final class AppointmentTests: XCTestCase {

    var testOwner: DogOwner!
    var testDog: Dog!
    var testAppointment: Appointment!
    var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Set up a mock context or test DB environment if needed
        context = .mock // Replace with your mock/context setup if using SwiftData
        testOwner = DogOwner(ownerName: "Jane Doe", contactInfo: "555-1234")
        testDog = Dog(name: "Rover", breed: "Poodle", owner: testOwner)
        testAppointment = Appointment(date: Date(), owner: testOwner, dog: testDog, serviceType: .fullGroom)
        // Optionally, add the objects to the context
    }

    override func tearDownWithError() throws {
        testOwner = nil
        testDog = nil
        testAppointment = nil
        context = nil
        try super.tearDownWithError()
    }

    func testCreateAppointment() throws {
        XCTAssertNotNil(testAppointment)
        XCTAssertEqual(testAppointment.owner.ownerName, "Jane Doe")
        XCTAssertEqual(testAppointment.dog.name, "Rover")
        XCTAssertEqual(testAppointment.serviceType, .fullGroom)
    }

    func testEditAppointmentDate() throws {
        let newDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        testAppointment.date = newDate
        XCTAssertEqual(testAppointment.date, newDate)
    }

    func testAppointmentConflictDetection() throws {
        // Create two appointments at the same time for the same dog
        let conflictingAppointment = Appointment(date: testAppointment.date, owner: testOwner, dog: testDog, serviceType: .bath)
        let isConflict = Appointment.isConflicting(a: testAppointment, b: conflictingAppointment)
        XCTAssertTrue(isConflict, "Appointments at the same time for the same dog should conflict.")
    }

    func testAppointmentNotes() throws {
        testAppointment.notes = "Special handling needed"
        XCTAssertEqual(testAppointment.notes, "Special handling needed")
    }

    func testAppointmentServiceTypeChange() throws {
        testAppointment.serviceType = .bath
        XCTAssertEqual(testAppointment.serviceType, .bath)
    }

    func testOwnerAppointmentsLinking() throws {
        testOwner.appointments.append(testAppointment)
        XCTAssertTrue(testOwner.appointments.contains(testAppointment))
    }

    // MARK: - Helper/Mock Functions

    // Add a simple conflict detection logic here or reference your real one
    // Replace with your real model implementation
    private static func isConflicting(a: Appointment, b: Appointment) -> Bool {
        let sameTime = a.date == b.date
        let sameDog = a.dog === b.dog
        return sameTime && sameDog
    }
}
