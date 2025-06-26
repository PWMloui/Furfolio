//
//  DatabaseIntegrityTests.swift
//  Furfolio
//
//  Enhanced 2025: Enterprise-Grade, Auditable, Robust Tests
//

import XCTest
@testable import Furfolio

final class DatabaseIntegrityTests: XCTestCase {
    var dataStore: DataStoreService!
    var owner: DogOwner!
    var dog: Dog!
    var appt: Appointment!
    var charge: Charge!
    static var testAuditLog: [String] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        dataStore = DataStoreService(inMemory: true)
        owner = DogOwner(ownerName: "Liz", contactInfo: "liz@paws.com")
        dog = Dog(name: "Baxter", breed: "Pug", owner: owner)
        appt = Appointment(date: Date(), owner: owner, dog: dog, serviceType: .fullGroom, durationMinutes: 75)
        charge = Charge(date: Date(), type: .service, amount: 65, notes: "Groom", owner: owner, appointment: appt)
        dataStore.add(owner)
        dataStore.add(dog)
        dataStore.add(appt)
        dataStore.add(charge)
        Self.testAuditLog.append("Setup: Added owner, dog, appt, charge")
    }

    override func tearDownWithError() throws {
        dataStore = nil
        owner = nil
        dog = nil
        appt = nil
        charge = nil
        Self.testAuditLog.append("Teardown: Reset all test objects")
        try super.tearDownWithError()
    }

    func testOwnerDogRelationshipIntegrity() {
        let dogs = dataStore.dogs(for: owner)
        XCTAssertTrue(dogs.contains(where: { $0.name == "Baxter" }),
            "Dog should be linked to owner (expected 'Baxter', got \(dogs.map{$0.name}))")
        XCTAssertEqual(dogs.first?.owner?.ownerName, "Liz", "Dog's owner should be Liz")
        Self.testAuditLog.append("Checked: owner-dog relationship")
    }

    func testAppointmentRelationships() {
        let appts = dataStore.appointments(for: owner)
        XCTAssertEqual(appts.count, 1, "Owner should have 1 appointment (got \(appts.count))")
        XCTAssertEqual(appts.first?.dog?.name, "Baxter", "Appointment's dog should be Baxter")
        Self.testAuditLog.append("Checked: owner-appointment-dog relationship")
    }

    func testChargeToAppointmentLink() {
        let charges = dataStore.charges(for: owner)
        XCTAssertEqual(charges.first?.appointment?.serviceType, .fullGroom, "Charge should be linked to appointment with .fullGroom")
        Self.testAuditLog.append("Checked: charge to appointment link")
    }

    func testDuplicateOwnerPrevention() {
        let duplicate = DogOwner(ownerName: "Liz", contactInfo: "liz@paws.com")
        let added = dataStore.add(duplicate)
        XCTAssertFalse(added, "Should prevent duplicate owner addition")
        Self.testAuditLog.append("Checked: duplicate owner prevention")
    }

    func testDeleteOwnerRemovesOrphansDeepCascade() {
        dataStore.delete(owner)
        let allDogs = dataStore.allDogs()
        let allAppointments = dataStore.allAppointments()
        let allCharges = dataStore.allCharges()
        XCTAssertTrue(allDogs.isEmpty, "Dogs should be deleted with owner (expected 0, got \(allDogs.count))")
        XCTAssertTrue(allAppointments.isEmpty, "Appointments should be deleted with owner (expected 0, got \(allAppointments.count))")
        XCTAssertTrue(allCharges.isEmpty, "Charges should be deleted with owner (expected 0, got \(allCharges.count))")
        Self.testAuditLog.append("Checked: cascade delete owner → dog, appt, charge")
    }

    func testOrphanedDogDetection() {
        dog.owner = nil
        dataStore.update(dog)
        let orphans = dataStore.orphanedDogs()
        XCTAssertTrue(orphans.contains(where: { $0.name == "Baxter" }),
            "Should detect orphaned dog (expected Baxter, got \(orphans.map{$0.name}))")
        Self.testAuditLog.append("Checked: orphaned dog detection")
    }

    func testDataConsistencyChecker() {
        dog.owner = nil
        appt.owner = nil
        dataStore.update(dog)
        dataStore.update(appt)
        let checker = DatabaseIntegrityChecker(dataStore: dataStore)
        let issues = checker.runAllChecks()
        XCTAssertTrue(issues.contains(where: { $0.contains("orphaned dog") }), "Should report orphaned dog")
        XCTAssertTrue(issues.contains(where: { $0.contains("appointment missing owner") }), "Should report orphaned appointment")
        Self.testAuditLog.append("Checked: data consistency checker")
    }

    func testRestoreOrphanedDog() {
        dog.owner = nil
        dataStore.update(dog)
        dog.owner = owner
        dataStore.update(dog)
        let orphans = dataStore.orphanedDogs()
        XCTAssertFalse(orphans.contains(where: { $0.name == "Baxter" }), "Re-linking should restore dog to owner")
        Self.testAuditLog.append("Checked: restore orphaned dog")
    }

    func testAuditLogExport() {
        let logs = Self.testAuditLog.suffix(14).joined(separator: "\n")
        print("Furfolio DatabaseIntegrityTests AuditLog:\n\(logs)")
    }
}
