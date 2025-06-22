//
//  ConflictResolutionTests.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import XCTest
@testable import Furfolio

final class ConflictResolutionTests: XCTestCase {

    var owner: DogOwner!
    var dog: Dog!
    var appointment1: Appointment!
    var appointment2: Appointment!
    var charge1: Charge!
    var charge2: Charge!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Setup test data
        owner = DogOwner(ownerName: "Sam Owner", contactInfo: "123-456")
        dog = Dog(name: "Bella", breed: "Poodle", owner: owner)
        let now = Date()
        appointment1 = Appointment(date: now, owner: owner, dog: dog, serviceType: .fullGroom, durationMinutes: 90)
        appointment2 = Appointment(date: now.addingTimeInterval(60*30), owner: owner, dog: dog, serviceType: .bath, durationMinutes: 60)
        charge1 = Charge(date: now, type: .service, amount: 55.0, notes: "Regular", owner: owner, appointment: appointment1)
        charge2 = Charge(date: now, type: .service, amount: 55.0, notes: "Regular", owner: owner, appointment: appointment1)
    }

    override func tearDownWithError() throws {
        owner = nil
        dog = nil
        appointment1 = nil
        appointment2 = nil
        charge1 = nil
        charge2 = nil
        try super.tearDownWithError()
    }

    // MARK: - Appointment Overlap

    func testDetectsOverlappingAppointments() throws {
        let conflict = ConflictHelper.appointmentsOverlap(appointment1, appointment2)
        XCTAssertTrue(conflict, "Appointments with overlapping times should be detected as conflicts")
    }

    func testNoConflictForNonOverlappingAppointments() throws {
        let a1 = Appointment(date: Date(), owner: owner, dog: dog, serviceType: .bath, durationMinutes: 30)
        let a2 = Appointment(date: Date().addingTimeInterval(60*60), owner: owner, dog: dog, serviceType: .bath, durationMinutes: 30)
        let conflict = ConflictHelper.appointmentsOverlap(a1, a2)
        XCTAssertFalse(conflict, "Non-overlapping appointments should not be conflicts")
    }

    // MARK: - Duplicate Charges

    func testDetectsDuplicateCharges() throws {
        let isDuplicate = ConflictHelper.duplicateCharges(charge1, charge2)
        XCTAssertTrue(isDuplicate, "Identical charges should be detected as duplicates")
    }

    func testNoDuplicateForDifferentCharges() throws {
        let c1 = Charge(date: Date(), type: .service, amount: 30, notes: "A", owner: owner, appointment: appointment1)
        let c2 = Charge(date: Date().addingTimeInterval(60), type: .product, amount: 10, notes: "B", owner: owner, appointment: appointment1)
        let isDuplicate = ConflictHelper.duplicateCharges(c1, c2)
        XCTAssertFalse(isDuplicate, "Distinct charges should not be marked as duplicates")
    }
}

// MARK: - Minimal Helper

struct ConflictHelper {
    static func appointmentsOverlap(_ a: Appointment, _ b: Appointment) -> Bool {
        let aEnd = a.date.addingTimeInterval(TimeInterval(a.durationMinutes ?? 60) * 60)
        let bEnd = b.date.addingTimeInterval(TimeInterval(b.durationMinutes ?? 60) * 60)
        return max(a.date, b.date) < min(aEnd, bEnd)
    }

    static func duplicateCharges(_ c1: Charge, _ c2: Charge) -> Bool {
        return c1.date == c2.date &&
            c1.amount == c2.amount &&
            c1.type == c2.type &&
            c1.owner.ownerName == c2.owner.ownerName &&
            c1.notes == c2.notes
    }
}
