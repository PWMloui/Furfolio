//
//  ConflictResolutionTests.swift
//  Furfolio
//
//  Enhanced 2025: Enterprise-Grade, Auditable, Robust Tests
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
    static var testAuditLog: [String] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        owner = DogOwner(ownerName: "Sam Owner", contactInfo: "123-456")
        dog = Dog(name: "Bella", breed: "Poodle", owner: owner)
        let now = Date()
        appointment1 = Appointment(date: now, owner: owner, dog: dog, serviceType: .fullGroom, durationMinutes: 90)
        appointment2 = Appointment(date: now.addingTimeInterval(60*30), owner: owner, dog: dog, serviceType: .bath, durationMinutes: 60)
        charge1 = Charge(date: now, type: .service, amount: 55.0, notes: "Regular", owner: owner, appointment: appointment1)
        charge2 = Charge(date: now, type: .service, amount: 55.0, notes: "Regular", owner: owner, appointment: appointment1)
        Self.testAuditLog.append("Setup: Created appointments and charges for \(owner.ownerName)")
    }

    override func tearDownWithError() throws {
        owner = nil
        dog = nil
        appointment1 = nil
        appointment2 = nil
        charge1 = nil
        charge2 = nil
        Self.testAuditLog.append("Teardown: Reset all test objects")
        try super.tearDownWithError()
    }

    // MARK: - Appointment Overlap Tests

    func testDetectsOverlappingAppointments() throws {
        let conflict = ConflictHelper.appointmentsOverlap(appointment1, appointment2)
        XCTAssertTrue(conflict, "Appointments with overlapping times should be detected as conflicts")
        Self.testAuditLog.append("Checked: Detected conflict for overlapping appointments")
    }

    func testNoConflictForNonOverlappingAppointments() throws {
        let a1 = Appointment(date: Date(), owner: owner, dog: dog, serviceType: .bath, durationMinutes: 30)
        let a2 = Appointment(date: Date().addingTimeInterval(60*60), owner: owner, dog: dog, serviceType: .bath, durationMinutes: 30)
        let conflict = ConflictHelper.appointmentsOverlap(a1, a2)
        XCTAssertFalse(conflict, "Non-overlapping appointments should not be conflicts")
        Self.testAuditLog.append("Checked: No conflict for non-overlapping appointments")
    }

    func testEdgeOverlapAppointments() throws {
        let base = Date()
        let a1 = Appointment(date: base, owner: owner, dog: dog, serviceType: .bath, durationMinutes: 30)
        let a2 = Appointment(date: base.addingTimeInterval(60*30), owner: owner, dog: dog, serviceType: .bath, durationMinutes: 30)
        let conflict = ConflictHelper.appointmentsOverlap(a1, a2)
        XCTAssertFalse(conflict, "Appointments ending when another starts should not overlap")
        Self.testAuditLog.append("Checked: Edge overlap is not a conflict")
    }

    func testPartialOverlapAppointments() throws {
        let base = Date()
        let a1 = Appointment(date: base, owner: owner, dog: dog, serviceType: .bath, durationMinutes: 60)
        let a2 = Appointment(date: base.addingTimeInterval(60*30), owner: owner, dog: dog, serviceType: .bath, durationMinutes: 60)
        let conflict = ConflictHelper.appointmentsOverlap(a1, a2)
        XCTAssertTrue(conflict, "Appointments with partial overlap should be conflicts")
        Self.testAuditLog.append("Checked: Detected partial overlap conflict")
    }

    func testNoConflictDifferentDogsOrOwners() throws {
        let otherOwner = DogOwner(ownerName: "Other", contactInfo: "999-999")
        let otherDog = Dog(name: "Max", breed: "Labrador", owner: otherOwner)
        let a1 = Appointment(date: Date(), owner: owner, dog: dog, serviceType: .bath, durationMinutes: 60)
        let a2 = Appointment(date: a1.date, owner: otherOwner, dog: otherDog, serviceType: .bath, durationMinutes: 60)
        let conflict = ConflictHelper.appointmentsOverlap(a1, a2)
        XCTAssertFalse(conflict, "Appointments for different dogs or owners should not conflict")
        Self.testAuditLog.append("Checked: No conflict for different dog or owner")
    }

    // MARK: - Duplicate Charges Tests

    func testDetectsDuplicateCharges() throws {
        let isDuplicate = ConflictHelper.duplicateCharges(charge1, charge2)
        XCTAssertTrue(isDuplicate, "Identical charges should be detected as duplicates")
        Self.testAuditLog.append("Checked: Duplicate charge detected")
    }

    func testNoDuplicateForDifferentCharges() throws {
        let c1 = Charge(date: Date(), type: .service, amount: 30, notes: "A", owner: owner, appointment: appointment1)
        let c2 = Charge(date: Date().addingTimeInterval(60), type: .product, amount: 10, notes: "B", owner: owner, appointment: appointment1)
        let isDuplicate = ConflictHelper.duplicateCharges(c1, c2)
        XCTAssertFalse(isDuplicate, "Distinct charges should not be marked as duplicates")
        Self.testAuditLog.append("Checked: Distinct charges not detected as duplicate")
    }

    func testDuplicateChargesWithSmallAmountDifference() throws {
        let c1 = Charge(date: Date(), type: .service, amount: 55.00, notes: "Reg", owner: owner, appointment: appointment1)
        let c2 = Charge(date: c1.date, type: .service, amount: 55.001, notes: "Reg", owner: owner, appointment: appointment1)
        let isDuplicate = ConflictHelper.duplicateCharges(c1, c2, tolerance: 0.01)
        XCTAssertTrue(isDuplicate, "Charges within rounding tolerance should be considered duplicates")
        Self.testAuditLog.append("Checked: Duplicate charge detection with rounding tolerance")
    }

    func testDuplicateChargesNullNotes() throws {
        let c1 = Charge(date: Date(), type: .service, amount: 40, notes: nil, owner: owner, appointment: appointment1)
        let c2 = Charge(date: c1.date, type: .service, amount: 40, notes: nil, owner: owner, appointment: appointment1)
        let isDuplicate = ConflictHelper.duplicateCharges(c1, c2)
        XCTAssertTrue(isDuplicate, "Charges with both nil notes should be detected as duplicates")
        Self.testAuditLog.append("Checked: Duplicate detection when notes are nil")
    }

    // MARK: - Audit Log Export

    func testAuditLogExport() {
        let logs = Self.testAuditLog.suffix(12).joined(separator: "\n")
        print("Furfolio ConflictResolutionTests AuditLog:\n\(logs)")
    }
}

// MARK: - Minimal Helper

struct ConflictHelper {
    static func appointmentsOverlap(_ a: Appointment, _ b: Appointment) -> Bool {
        // Only same dog and owner
        guard a.owner === b.owner, a.dog === b.dog else { return false }
        let aEnd = a.date.addingTimeInterval(TimeInterval(a.durationMinutes ?? 60) * 60)
        let bEnd = b.date.addingTimeInterval(TimeInterval(b.durationMinutes ?? 60) * 60)
        return max(a.date, b.date) < min(aEnd, bEnd)
    }

    static func duplicateCharges(
        _ c1: Charge,
        _ c2: Charge,
        tolerance: Double = 0.0001
    ) -> Bool {
        let amountEqual = abs(c1.amount - c2.amount) <= tolerance
        let notesEqual: Bool = (c1.notes ?? "") == (c2.notes ?? "")
        return c1.date == c2.date &&
            amountEqual &&
            c1.type == c2.type &&
            c1.owner.ownerName == c2.owner.ownerName &&
            notesEqual
    }
}
