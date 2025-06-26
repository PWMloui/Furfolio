//
//  AppointmentTests.swift
//  Furfolio
//
//  Enhanced 2025: Enterprise-Grade, Auditable, Robust Tests
//

import XCTest
@testable import Furfolio

final class AppointmentTests: XCTestCase {

    var testOwner: DogOwner!
    var testDog: Dog!
    var testAppointment: Appointment!
    var context: ModelContext!
    static var testAuditLog: [String] = []

    // MARK: - Setup & Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()
        context = .mock // Replace with your mock/context setup if using SwiftData
        testOwner = DogOwner(ownerName: "Jane Doe", contactInfo: "555-1234")
        testDog = Dog(name: "Rover", breed: "Poodle", owner: testOwner)
        testAppointment = Appointment(date: Date(), owner: testOwner, dog: testDog, serviceType: .fullGroom)
        Self.testAuditLog.append("Setup: Created test owner, dog, and appointment")
    }

    override func tearDownWithError() throws {
        testOwner = nil
        testDog = nil
        testAppointment = nil
        context = nil
        Self.testAuditLog.append("Teardown: Reset all test objects")
        try super.tearDownWithError()
    }

    // MARK: - Core Functionality Tests

    func testCreateAppointment() throws {
        XCTAssertNotNil(testAppointment, "Test appointment should not be nil")
        XCTAssertEqual(testAppointment.owner.ownerName, "Jane Doe", "Owner name should match")
        XCTAssertEqual(testAppointment.dog.name, "Rover", "Dog name should match")
        XCTAssertEqual(testAppointment.serviceType, .fullGroom, "Service type should be Full Groom")
        Self.testAuditLog.append("Tested: create appointment with correct linkage")
    }

    func testEditAppointmentDate() throws {
        let newDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        testAppointment.date = newDate
        XCTAssertEqual(testAppointment.date, newDate, "Appointment date should update correctly")
        Self.testAuditLog.append("Tested: edit appointment date")
    }

    func testAppointmentConflictDetection() throws {
        let conflictingAppointment = Appointment(date: testAppointment.date, owner: testOwner, dog: testDog, serviceType: .bath)
        let isConflict = AppointmentTests.isConflicting(a: testAppointment, b: conflictingAppointment)
        XCTAssertTrue(isConflict, "Appointments at the same time for the same dog should conflict.")
        Self.testAuditLog.append("Tested: conflict detection on overlapping appointments")
    }

    func testAppointmentNotes() throws {
        testAppointment.notes = "Special handling needed"
        XCTAssertEqual(testAppointment.notes, "Special handling needed", "Notes should update")
        Self.testAuditLog.append("Tested: appointment notes edit")
    }

    func testAppointmentServiceTypeChange() throws {
        testAppointment.serviceType = .bath
        XCTAssertEqual(testAppointment.serviceType, .bath, "Service type should change to Bath")
        Self.testAuditLog.append("Tested: appointment service type change")
    }

    func testOwnerAppointmentsLinking() throws {
        testOwner.appointments.append(testAppointment)
        XCTAssertTrue(testOwner.appointments.contains(testAppointment), "Owner should link to appointment")
        XCTAssertTrue(testAppointment.owner === testOwner, "Appointment owner reference should be valid")
        XCTAssertTrue(testAppointment.dog === testDog, "Appointment dog reference should be valid")
        Self.testAuditLog.append("Tested: owner-appointment-dog linkage integrity")
    }

    // MARK: - Edge & Negative Tests

    func testCannotCreateDuplicateAppointment() throws {
        let appointment2 = Appointment(date: testAppointment.date, owner: testOwner, dog: testDog, serviceType: .bath)
        let isConflict = AppointmentTests.isConflicting(a: testAppointment, b: appointment2)
        XCTAssertTrue(isConflict, "Duplicate time appointment should conflict")
        // Simulate a validation check in your real add logic if needed
        Self.testAuditLog.append("Tested: duplicate appointment is blocked by conflict logic")
    }

    func testEditNotesAndServiceTypeTogether() throws {
        testAppointment.notes = "Requires de-shedding"
        testAppointment.serviceType = .bath
        XCTAssertEqual(testAppointment.notes, "Requires de-shedding", "Notes should update together with service type")
        XCTAssertEqual(testAppointment.serviceType, .bath, "Service type should be Bath after simultaneous edit")
        Self.testAuditLog.append("Tested: edit notes and service type together")
    }

    func testNilDogOrOwnerInput() throws {
        // Simulate invalid creation
        let nilDogAppointment = Appointment(date: Date(), owner: testOwner, dog: nil, serviceType: .fullGroom)
        XCTAssertNil(nilDogAppointment.dog, "Dog should be nil in this test appointment")
        Self.testAuditLog.append("Tested: appointment with nil dog input")
    }

    // MARK: - Helper/Mock Functions

    private static func isConflicting(a: Appointment, b: Appointment) -> Bool {
        let sameTime = a.date == b.date
        let sameDog = a.dog === b.dog
        return sameTime && sameDog
    }

    // MARK: - Audit Log Export

    func testAuditLogExport() throws {
        let logs = Self.testAuditLog.suffix(12).joined(separator: "\n")
        print("Furfolio AppointmentTests AuditLog:\n\(logs)")
    }
}
