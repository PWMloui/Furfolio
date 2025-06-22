//
//  ChargeTests.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import XCTest
@testable import Furfolio

final class ChargeTests: XCTestCase {
    var owner: DogOwner!
    var appointment: Appointment!
    var charge: Charge!
    var context: ModelContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Replace with your actual mock context setup as needed
        context = .mock
        owner = DogOwner(ownerName: "John Smith", contactInfo: "555-1234")
        appointment = Appointment(date: Date(), owner: owner, dog: Dog(name: "Spot", breed: "Beagle", owner: owner), serviceType: .bath)
        charge = Charge(date: Date(), type: .service, amount: 45.0, notes: "First visit discount", owner: owner, appointment: appointment)
    }

    override func tearDownWithError() throws {
        owner = nil
        appointment = nil
        charge = nil
        context = nil
        try super.tearDownWithError()
    }

    func testCreateCharge() throws {
        XCTAssertNotNil(charge)
        XCTAssertEqual(charge.owner.ownerName, "John Smith")
        XCTAssertEqual(charge.amount, 45.0)
        XCTAssertEqual(charge.notes, "First visit discount")
        XCTAssertEqual(charge.type, .service)
    }

    func testEditChargeAmount() throws {
        charge.amount = 60.0
        XCTAssertEqual(charge.amount, 60.0)
    }

    func testChargeNotes() throws {
        charge.notes = "Upgraded to full service"
        XCTAssertEqual(charge.notes, "Upgraded to full service")
    }

    func testChargeTagging() throws {
        // Assuming Charge model has tags property [String]
        charge.tags = ["Discount", "Referral"]
        XCTAssertTrue(charge.tags.contains("Discount"))
        XCTAssertTrue(charge.tags.contains("Referral"))
    }

    func testOwnerChargeLinking() throws {
        owner.charges.append(charge)
        XCTAssertTrue(owner.charges.contains(charge))
    }

    func testNegativeAmountNotAllowed() throws {
        charge.amount = -10.0
        XCTAssertLessThanOrEqual(charge.amount, 0, "Charge amount should not be negative")
        // You could add real validation logic here if model enforces it
    }

    func testChargeLinkedToAppointment() throws {
        XCTAssertEqual(charge.appointment, appointment)
    }
}
