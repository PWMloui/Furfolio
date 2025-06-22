//
//  MockData.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

// MARK: - Mock Data Providers

import Foundation

// Example Mock Data for Dog
struct MockDogData {
    static func makeDog(id: UUID = UUID(), name: String = "Buddy", breed: String = "Labrador", age: Int = 3, notes: String = "Friendly and energetic", ownerId: UUID? = nil) -> Dog {
        Dog(id: id, name: name, breed: breed, age: age, notes: notes, ownerId: ownerId)
    }
    static let sampleDog = makeDog()
    static let anotherDog = makeDog(name: "Max", breed: "Poodle", age: 5, notes: "Nervous around strangers")
}

// Example Mock Data for DogOwner
struct MockOwnerData {
    static func makeOwner(id: UUID = UUID(), name: String = "Jane Doe", phone: String = "555-1234", email: String = "jane@email.com", address: String = "123 Park Ave") -> DogOwner {
        DogOwner(id: id, name: name, phone: phone, email: email, address: address, dogs: [MockDogData.sampleDog])
    }
    static let sampleOwner = makeOwner()
}

// Example Mock Data for Appointment
struct MockAppointmentData {
    static func makeAppointment(id: UUID = UUID(), date: Date = Date(), dog: Dog = MockDogData.sampleDog, owner: DogOwner = MockOwnerData.sampleOwner, serviceType: ServiceType = .fullGroom, notes: String = "First visit") -> Appointment {
        Appointment(id: id, date: date, dog: dog, owner: owner, serviceType: serviceType, notes: notes)
    }
    static let sampleAppointment = makeAppointment()
}

// Example Mock Data for Charge
struct MockChargeData {
    static func makeCharge(id: UUID = UUID(), date: Date = Date(), amount: Double = 75.0, type: String = "Full Groom", notes: String = "", owner: DogOwner = MockOwnerData.sampleOwner) -> Charge {
        Charge(id: id, date: date, amount: amount, type: type, notes: notes, owner: owner)
    }
    static let sampleCharge = makeCharge()
}

// Example Mock Data for Expense
struct MockExpenseData {
    static func makeExpense(id: UUID = UUID(), date: Date = Date(), amount: Double = 24.99, category: String = "Shampoo", vendor: String = "Pet Supplies Inc.", notes: String = "Bulk order") -> Expense {
        Expense(id: id, date: date, amount: amount, category: category, vendor: vendor, notes: notes)
    }
    static let sampleExpense = makeExpense()
}

// Example Mock Data for GroomingSession
struct MockGroomingSessionData {
    static func makeSession(id: UUID = UUID(), date: Date = Date(), dog: Dog = MockDogData.sampleDog, duration: Int = 60, services: [ServiceType] = [.bath, .nailTrim], behavior: String = "Calm", notes: String = "Great session") -> GroomingSession {
        GroomingSession(id: id, date: date, dog: dog, duration: duration, services: services, behavior: behavior, notes: notes)
    }
    static let sampleSession = makeSession()
}

// MARK: - Preview Data Collections
struct MockData {
    static let allDogs: [Dog] = [MockDogData.sampleDog, MockDogData.anotherDog]
    static let allOwners: [DogOwner] = [MockOwnerData.sampleOwner]
    static let allAppointments: [Appointment] = [MockAppointmentData.sampleAppointment]
    static let allCharges: [Charge] = [MockChargeData.sampleCharge]
    static let allExpenses: [Expense] = [MockExpenseData.sampleExpense]
    static let allGroomingSessions: [GroomingSession] = [MockGroomingSessionData.sampleSession]
}

