//
//  DatabaseIntegrityTests.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import XCTest
@testable import Furfolio

final class DatabaseIntegrityTests: XCTestCase {
    var dataStore: DataStoreService!
    var owner: DogOwner!
    var dog: Dog!
    var appt: Appointment!
    var charge: Charge!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        // In-memory or mock data store
        dataStore = DataStoreService(inMemory: true)
        
        // Demo business entities
        owner = DogOwner(ownerName: "Liz", contactInfo: "liz@paws.com")
        dog = Dog(name: "Baxter", breed: "Pug", owner: owner)
        appt = Appointment(date: Date(), owner: owner, dog: dog, serviceType: .fullGroom, durationMinutes: 75)
        charge = Charge(date: Date(), type: .service, amount: 65, notes: "Groom", owner: owner, appointment: appt)
        
        // Add all entities to store
        dataStore.add(owner)
        dataStore.add(dog)
        dataStore.add(appt)
        dataStore.add(charge)
    }
    
    override func tearDownWithError() throws {
        // Clear everything
        dataStore = nil
        owner = nil
        dog = nil
        appt = nil
        charge = nil
        try super.tearDownWithError()
    }
    
    func testOwnerDogRelationshipIntegrity() {
        let dogs = dataStore.dogs(for: owner)
        XCTAssertTrue(dogs.contains(where: { $0.name == "Baxter" }),
                      "Dog should be linked to owner")
        XCTAssertEqual(dogs.first?.owner?.ownerName, "Liz")
    }
    
    func testAppointmentRelationships() {
        let appts = dataStore.appointments(for: owner)
        XCTAssertEqual(appts.count, 1, "Owner should have 1 appointment")
        XCTAssertEqual(appts.first?.dog?.name, "Baxter")
    }
    
    func testChargeToAppointmentLink() {
        let charges = dataStore.charges(for: owner)
        XCTAssertEqual(charges.first?.appointment?.serviceType, .fullGroom)
    }
    
    func testDeleteOwnerRemovesOrphans() {
        // Remove owner, simulate cascade delete
        dataStore.delete(owner)
        
        let allDogs = dataStore.allDogs()
        let allAppointments = dataStore.allAppointments()
        let allCharges = dataStore.allCharges()
        
        XCTAssertTrue(allDogs.isEmpty, "All dogs should be deleted if owner removed")
        XCTAssertTrue(allAppointments.isEmpty, "Appointments should be deleted if owner removed")
        XCTAssertTrue(allCharges.isEmpty, "Charges should be deleted if owner removed")
    }
    
    func testOrphanedDogDetection() {
        // Remove link between dog and owner
        dog.owner = nil
        dataStore.update(dog)
        let orphans = dataStore.orphanedDogs()
        XCTAssertTrue(orphans.contains(where: { $0.name == "Baxter" }), "Should detect orphaned dogs")
    }
    
    func testDataConsistencyChecker() {
        // Simulate corruption
        dog.owner = nil
        appt.owner = nil
        dataStore.update(dog)
        dataStore.update(appt)
        
        let checker = DatabaseIntegrityChecker(dataStore: dataStore)
        let issues = checker.runAllChecks()
        XCTAssertTrue(issues.contains(where: { $0.contains("orphaned dog") }), "Should report orphaned dog")
        XCTAssertTrue(issues.contains(where: { $0.contains("appointment missing owner") }), "Should report orphaned appointment")
    }
}
