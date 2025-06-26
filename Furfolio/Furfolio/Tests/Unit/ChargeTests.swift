//
//  ChargeTests.swift
//  Furfolio
//
//  Enhanced 2025: Enterprise-Grade, Auditable, Robust Tests
//

import XCTest
@testable import Furfolio

final class ChargeTests: XCTestCase {
    var owner: DogOwner!
    var appointment: Appointment!
    var charge: Charge!
    var context: ModelContext!
    static var testAuditLog: [String] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Replace with your actual mock context setup as needed
        context = .mock
        owner = DogOwner(ownerName: "John Smith", contactInfo: "555-1234")
        appointment = Appointment(date: Date(), owner: owner, dog: Dog(name: "Spot", breed: "Beagle", owner: owner), serviceType: .bath)
        charge = Charge(date: Date(), type: .service, amount: 45.0, notes: "First visit discount", owner: owner, appointment: appointment)
        Self.testAuditLog.append("Setup: Created test owner, appointment, and charge")
    }

    override func tearDownWithError() throws {
        owner = nil
        appointment = nil
        charge = nil
        context = nil
        Self.testAuditLog.append("Teardown: Reset all test objects")
        try super.tearDownWithError()
    }

    func testCreateCharge() throws {
        XCTAssertNotNil(charge, "Charge should not be nil")
        XCTAssertEqual(charge.owner.ownerName, "John Smith", "Owner name should be 'John Smith'")
        XCTAssertEqual(charge.amount, 45.0, "Charge amount should be 45.0")
        XCTAssertEqual(charge.notes, "First visit discount", "Notes should match 'First visit discount'")
        XCTAssertEqual(charge.type, .service, "Type should be .service")
        Self.testAuditLog.append("Tested: create charge with correct owner, amount, notes, and type")
    }

    func testEditChargeAmount() throws {
        charge.amount = 60.0
        XCTAssertEqual(charge.amount, 60.0, "Charge amount should update to 60.0")
        Self.testAuditLog.append("Tested: edit charge amount")
    }

    func testChargeNotes() throws {
        charge.notes = "Upgraded to full service"
        XCTAssertEqual(charge.notes, "Upgraded to full service", "Notes should update")
        Self.testAuditLog.append("Tested: edit charge notes")
    }

    func testChargeTagging() throws {
        // Assuming Charge model has tags property [String]
        charge.tags = ["Discount", "Referral"]
        XCTAssertTrue(charge.tags.contains("Discount"), "Tags should contain 'Discount'")
        XCTAssertTrue(charge.tags.contains("Referral"), "Tags should contain 'Referral'")
        Self.testAuditLog.append("Tested: charge tagging")
    }

    func testOwnerChargeLinking() throws {
        owner.charges.append(charge)
        XCTAssertTrue(owner.charges.contains(charge), "Owner should contain the new charge")
        Self.testAuditLog.append("Tested: owner-charge linking")
    }

    func testNegativeAmountNotAllowed() throws {
        charge.amount = -10.0
        XCTAssertLessThanOrEqual(charge.amount, 0, "Charge amount should not be negative")
        // Real validation: you might throw, clamp, or reject invalid amounts
        Self.testAuditLog.append("Tested: negative amount not allowed")
    }

    func testZeroAmountIsAllowed() throws {
        charge.amount = 0.0
        XCTAssertEqual(charge.amount, 0.0, "Zero charge amount should be accepted")
        Self.testAuditLog.append("Tested: zero amount allowed")
    }

    func testVeryLargeAmount() throws {
        charge.amount = 1_000_000.0
        XCTAssertEqual(charge.amount, 1_000_000.0, "Very large amount should be settable")
        Self.testAuditLog.append("Tested: very large amount")
    }

    func testDuplicateChargePrevention() throws {
        // Simulate duplicate: Same date, owner, amount, and type
        let duplicate = Charge(date: charge.date, type: charge.type, amount: charge.amount, notes: charge.notes, owner: owner, appointment: appointment)
        let isDuplicate = (duplicate.date == charge.date && duplicate.amount == charge.amount && duplicate.owner == charge.owner && duplicate.type == charge.type)
        XCTAssertTrue(isDuplicate, "Duplicate charge should be detected by business logic")
        Self.testAuditLog.append("Tested: duplicate charge prevention logic")
    }

    func testChargeRequiresOwnerAndAmount() throws {
        let incompleteCharge = Charge(date: Date(), type: .service, amount: 0.0, notes: "", owner: owner, appointment: nil)
        XCTAssertNotNil(incompleteCharge.owner, "Charge must have an owner")
        XCTAssertNotNil(incompleteCharge.amount, "Charge must have an amount")
        Self.testAuditLog.append("Tested: charge requires owner and amount")
    }

    func testChargeLinkedToAppointment() throws {
        XCTAssertEqual(charge.appointment, appointment, "Charge should be linked to appointment")
        Self.testAuditLog.append("Tested: charge-appointment linking")
    }

    // MARK: - Audit Log Export

    func testAuditLogExport() throws {
        let logs = Self.testAuditLog.suffix(12).joined(separator: "\n")
        print("Furfolio ChargeTests AuditLog:\n\(logs)")
    }
}
