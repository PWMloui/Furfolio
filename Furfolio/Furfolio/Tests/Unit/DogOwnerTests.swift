//
//  DogOwnerTests.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
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

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Use an in-memory data store for isolated tests
        dataStore = DataStoreService(inMemory: true)
        
        owner = DogOwner(ownerName: "Samantha", contactInfo: "samantha@example.com")
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
        try super.tearDownWithError()
    }
    
    func testOwnerHasMultipleDogs() {
        let dogs = dataStore.dogs(for: owner)
        XCTAssertEqual(dogs.count, 2)
        XCTAssertTrue(dogs.contains(where: { $0.name == "Daisy" }))
        XCTAssertTrue(dogs.contains(where: { $0.name == "Max" }))
    }
    
    func testAppointmentsForOwner() {
        let appts = dataStore.appointments(for: owner)
        XCTAssertEqual(appts.count, 2)
        XCTAssertEqual(appts[0].owner?.ownerName, "Samantha")
    }
    
    func testChargesForOwner() {
        let charges = dataStore.charges(for: owner)
        XCTAssertEqual(charges.count, 2)
        XCTAssertTrue(charges.contains(where: { $0.notes == "Bath" }))
        XCTAssertTrue(charges.contains(where: { $0.notes == "Nail trim" }))
    }
    
    func testAddDogToOwner() {
        let newDog = Dog(name: "Rex", breed: "Bulldog", owner: owner)
        dataStore.add(newDog)
        let dogs = dataStore.dogs(for: owner)
        XCTAssertEqual(dogs.count, 3)
        XCTAssertTrue(dogs.contains(where: { $0.name == "Rex" }))
    }
    
    func testRemoveDogFromOwner() {
        dataStore.delete(dog1)
        let dogs = dataStore.dogs(for: owner)
        XCTAssertEqual(dogs.count, 1)
        XCTAssertFalse(dogs.contains(where: { $0.name == "Daisy" }))
    }
    
    func testOwnerTotalCharges() {
        let total = dataStore.totalCharges(for: owner)
        XCTAssertEqual(total, 70.0, accuracy: 0.01)
    }
    
    func testOwnerLoyaltyPoints() {
        // Suppose you award 1 point per $10 spent
        let points = dataStore.loyaltyPoints(for: owner)
        XCTAssertEqual(points, 7)
    }
    
    func testOwnerRetentionStatus() {
        // Simulate an at-risk owner with no appts for 90 days
        let pastOwner = DogOwner(ownerName: "Inactive", contactInfo: "x@x.com")
        dataStore.add(pastOwner)
        let retention = dataStore.retentionStatus(for: pastOwner)
        XCTAssertEqual(retention, .atRisk)
    }
}
