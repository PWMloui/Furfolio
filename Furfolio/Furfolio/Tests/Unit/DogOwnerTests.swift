//
//  DogOwnerTests.swift
//  Furfolio
//
//  Enhanced 2025: Enterprise-Grade, Auditable, Robust Tests
//

import XCTest
@testable import Furfolio

final class DogOwnerTests: XCTestCase {
    var dataStore: DataStoreService!
    var owner: DogOwner!
    var dog1: Dog!
    var dog2: Dog!
    var appt1: Appointment!
    var appt2: Appointment!
    var charge1: Charge!
    var charge2: Charge!
    static var testAuditLog: [String] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Use an in-memory data store for isolated tests
        dataStore = DataStoreService(inMemory: true)
        
        owner = DogOwner(ownerName: "Samantha", contactInfo: "samantha@example.com", loyaltyTier: .silver)
        dog1 = Dog(name: "Daisy", breed: "Poodle", owner: owner)
        dog2 = Dog(name: "Max", breed: "Yorkie", owner: owner)
        appt1 = Appointment(date: Date(), owner: owner, dog: dog1, serviceType: .bath, durationMinutes: 60)
        appt2 = Appointment(date: Date().addingTimeInterval(60*60*24), owner: owner, dog: dog2, serviceType: .nails, durationMinutes: 30)
        charge1 = Charge(date: Date(), type: .service, amount: 45.0, notes: "Bath", owner: owner, appointment: appt1)
        charge2 = Charge(date: Date(), type: .service, amount: 25.0, notes: "Nail trim", owner: owner, appointment: appt2)
        
        dataStore.add(owner)
        dataStore.add(dog1)
        dataStore.add(dog2)
        dataStore.add(appt1)
        dataStore.add(appt2)
        dataStore.add(charge1)
        dataStore.add(charge2)
        Self.testAuditLog.append("Setup: Added owner, 2 dogs, 2 appts, 2 charges")
    }
    
    override func tearDownWithError() throws {
        dataStore = nil
        owner = nil
        dog1 = nil
        dog2 = nil
        appt1 = nil
        appt2 = nil
        charge1 = nil
        charge2 = nil
        Self.testAuditLog.append("Teardown: Reset all test objects")
        try super.tearDownWithError()
    }
    
    func testOwnerHasMultipleDogs() {
        let dogs = dataStore.dogs(for: owner)
        XCTAssertEqual(dogs.count, 2, "Owner should have 2 dogs, got \(dogs.count)")
        XCTAssertTrue(dogs.contains(where: { $0.name == "Daisy" }), "Should contain Daisy")
        XCTAssertTrue(dogs.contains(where: { $0.name == "Max" }), "Should contain Max")
        Self.testAuditLog.append("Checked: owner has multiple dogs")
    }
    
    func testAppointmentsForOwner() {
        let appts = dataStore.appointments(for: owner)
        XCTAssertEqual(appts.count, 2, "Owner should have 2 appointments, got \(appts.count)")
        XCTAssertEqual(appts[0].owner?.ownerName, "Samantha", "First appointment owner should be Samantha")
        Self.testAuditLog.append("Checked: appointments for owner")
    }
    
    func testChargesForOwner() {
        let charges = dataStore.charges(for: owner)
        XCTAssertEqual(charges.count, 2, "Owner should have 2 charges, got \(charges.count)")
        XCTAssertTrue(charges.contains(where: { $0.notes == "Bath" }), "Should contain charge for Bath")
        XCTAssertTrue(charges.contains(where: { $0.notes == "Nail trim" }), "Should contain charge for Nail trim")
        Self.testAuditLog.append("Checked: charges for owner")
    }
    
    func testAddDogToOwner() {
        let newDog = Dog(name: "Rex", breed: "Bulldog", owner: owner)
        dataStore.add(newDog)
        let dogs = dataStore.dogs(for: owner)
        XCTAssertEqual(dogs.count, 3, "Owner should have 3 dogs after adding Rex, got \(dogs.count)")
        XCTAssertTrue(dogs.contains(where: { $0.name == "Rex" }), "Should contain Rex")
        Self.testAuditLog.append("Checked: add dog to owner")
    }
    
    func testRemoveDogFromOwner() {
        dataStore.delete(dog1)
        let dogs = dataStore.dogs(for: owner)
        XCTAssertEqual(dogs.count, 1, "Owner should have 1 dog after deletion, got \(dogs.count)")
        XCTAssertFalse(dogs.contains(where: { $0.name == "Daisy" }), "Should not contain Daisy after deletion")
        Self.testAuditLog.append("Checked: remove dog from owner")
    }
    
    func testOwnerTotalCharges() {
        let total = dataStore.totalCharges(for: owner)
        XCTAssertEqual(total, 70.0, accuracy: 0.01, "Owner's total charges should be 70.0, got \(total)")
        Self.testAuditLog.append("Checked: owner total charges")
    }
    
    func testOwnerLoyaltyPoints() {
        // Suppose you award 1 point per $10 spent
        let points = dataStore.loyaltyPoints(for: owner)
        XCTAssertEqual(points, 7, "Owner should have 7 loyalty points, got \(points)")
        Self.testAuditLog.append("Checked: owner loyalty points")
    }
    
    func testOwnerRetentionStatus() {
        // Simulate an at-risk owner with no appts for 90 days
        let pastOwner = DogOwner(ownerName: "Inactive", contactInfo: "x@x.com")
        dataStore.add(pastOwner)
        let retention = dataStore.retentionStatus(for: pastOwner)
        XCTAssertEqual(retention, .atRisk, "Owner should be at-risk if inactive for 90 days")
        Self.testAuditLog.append("Checked: owner retention status")
    }

    // --- ENHANCED TESTS BELOW ---

    func testPreventDuplicateDogAddition() {
        let duplicateDog = Dog(name: "Daisy", breed: "Poodle", owner: owner)
        let added = dataStore.add(duplicateDog)
        XCTAssertFalse(added, "Should prevent adding duplicate dog by name for same owner")
        Self.testAuditLog.append("Checked: duplicate dog addition is prevented")
    }

    func testDeleteOwnerCascadesToDogsAndAppointments() {
        dataStore.delete(owner)
        let remainingDogs = dataStore.dogs(for: owner)
        let remainingAppts = dataStore.appointments(for: owner)
        XCTAssertTrue(remainingDogs.isEmpty, "All dogs should be deleted with owner")
        XCTAssertTrue(remainingAppts.isEmpty, "All appointments should be deleted with owner")
        Self.testAuditLog.append("Checked: deleting owner cascades to dogs and appointments")
    }

    func testOrphanDogDetectionAndRestore() {
        dog1.owner = nil
        dataStore.update(dog1)
        let orphans = dataStore.orphanedDogs()
        XCTAssertTrue(orphans.contains(where: { $0.name == "Daisy" }), "Should detect Daisy as orphaned dog")
        // Restore
        dog1.owner = owner
        dataStore.update(dog1)
        let orphansAfter = dataStore.orphanedDogs()
        XCTAssertFalse(orphansAfter.contains(where: { $0.name == "Daisy" }), "Daisy should no longer be orphaned after restore")
        Self.testAuditLog.append("Checked: orphaned dog detection and restore")
    }

    func testChangeLoyaltyTier() {
        owner.loyaltyTier = .gold
        dataStore.update(owner)
        let updated = dataStore.owner(with: owner.id)
        XCTAssertEqual(updated?.loyaltyTier, .gold, "Owner's loyalty tier should be Gold after update")
        Self.testAuditLog.append("Checked: change loyalty tier")
    }

    func testUpdateContactInfo() {
        owner.contactInfo = "sammy@furfolio.com"
        dataStore.update(owner)
        let updated = dataStore.owner(with: owner.id)
        XCTAssertEqual(updated?.contactInfo, "sammy@furfolio.com", "Owner contact info should update")
        Self.testAuditLog.append("Checked: update contact info")
    }

    func testAuditLogExport() {
        let logs = Self.testAuditLog.suffix(16).joined(separator: "\n")
        print("Furfolio DogOwnerTests AuditLog:\n\(logs)")
    }
}
