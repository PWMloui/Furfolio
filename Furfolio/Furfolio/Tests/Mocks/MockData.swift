//
//  MockData.swift
//  Furfolio
//
//  Enhanced 2025: Enterprise-Grade, Audit-Ready Mock Data
//

import Foundation

// MARK: - Mock Data for Dog
struct MockDogData {
    static func makeDog(
        id: UUID = UUID(),
        name: String = "Buddy",
        breed: String = "Labrador",
        age: Int = 3,
        gender: String = "male",
        birthdate: Date = ISO8601DateFormatter().date(from: "2020-04-16T00:00:00Z") ?? Date(),
        color: String = "yellow",
        weightKg: Double = 32.8,
        microchipId: String = "980000223344556",
        notes: String = "Friendly and energetic",
        ownerId: UUID? = nil,
        tags: [String] = ["friendly", "energetic"],
        vaccinated: Bool = true,
        status: String = "active",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        image: String = "buddy.jpg"
    ) -> Dog {
        Dog(
            id: id, name: name, breed: breed, age: age, gender: gender,
            birthdate: birthdate, color: color, weightKg: weightKg, microchipId: microchipId,
            notes: notes, ownerId: ownerId, tags: tags, vaccinated: vaccinated,
            status: status, createdAt: createdAt, updatedAt: updatedAt, image: image
        )
    }
    static let sampleDog = makeDog()
    static let anotherDog = makeDog(name: "Max", breed: "Poodle", age: 5, gender: "male", color: "apricot", notes: "Nervous around strangers", tags: ["nervous"])
}

// MARK: - Mock Data for DogOwner
struct MockOwnerData {
    static func makeOwner(
        id: UUID = UUID(),
        name: String = "Jane Doe",
        phone: String = "555-1234",
        email: String = "jane@email.com",
        address: String = "123 Park Ave",
        dogIDs: [UUID] = [MockDogData.sampleDog.id],
        loyaltyTier: String = "gold",
        preferredContactMethod: String = "sms",
        tags: [String] = ["vip"],
        notes: String = "Responds quickly.",
        status: String = "active",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> DogOwner {
        DogOwner(
            id: id, name: name, phone: phone, email: email, address: address,
            dogIDs: dogIDs, loyaltyTier: loyaltyTier, preferredContactMethod: preferredContactMethod,
            tags: tags, notes: notes, status: status, createdAt: createdAt, updatedAt: updatedAt
        )
    }
    static let sampleOwner = makeOwner()
}

// MARK: - Mock Data for Appointment
struct MockAppointmentData {
    static func makeAppointment(
        id: UUID = UUID(),
        date: Date = Date(),
        dog: Dog = MockDogData.sampleDog,
        owner: DogOwner = MockOwnerData.sampleOwner,
        serviceType: ServiceType = .fullGroom,
        serviceCode: String = "FG01",
        notes: String = "First visit",
        status: String = "scheduled",
        price: Double = 75.0,
        currency: String = "USD",
        reminderEnabled: Bool = true,
        tags: [String] = ["VIP", "repeat"],
        requiresSpecialHandling: Bool = false,
        staff: [String] = ["Anna Lee"],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> Appointment {
        Appointment(
            id: id, date: date, dog: dog, owner: owner, serviceType: serviceType,
            serviceCode: serviceCode, notes: notes, status: status,
            price: price, currency: currency, reminderEnabled: reminderEnabled, tags: tags,
            requiresSpecialHandling: requiresSpecialHandling, staff: staff,
            createdAt: createdAt, updatedAt: updatedAt
        )
    }
    static let sampleAppointment = makeAppointment()
}

// MARK: - Mock Data for Charge
struct MockChargeData {
    static func makeCharge(
        id: UUID = UUID(),
        date: Date = Date(),
        amount: Double = 75.0,
        type: String = "Full Groom",
        notes: String = "",
        owner: DogOwner = MockOwnerData.sampleOwner,
        currency: String = "USD"
    ) -> Charge {
        Charge(
            id: id, date: date, amount: amount, type: type,
            notes: notes, owner: owner, currency: currency
        )
    }
    static let sampleCharge = makeCharge()
}

// MARK: - Mock Data for Expense
struct MockExpenseData {
    static func makeExpense(
        id: UUID = UUID(),
        date: Date = Date(),
        amount: Double = 24.99,
        category: String = "Shampoo",
        vendor: String = "Pet Supplies Inc.",
        notes: String = "Bulk order",
        status: String = "approved"
    ) -> Expense {
        Expense(
            id: id, date: date, amount: amount, category: category,
            vendor: vendor, notes: notes, status: status
        )
    }
    static let sampleExpense = makeExpense()
}

// MARK: - Mock Data for GroomingSession
struct MockGroomingSessionData {
    static func makeSession(
        id: UUID = UUID(),
        date: Date = Date(),
        dog: Dog = MockDogData.sampleDog,
        duration: Int = 60,
        services: [ServiceType] = [.bath, .nailTrim],
        behavior: String = "Calm",
        notes: String = "Great session",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) -> GroomingSession {
        GroomingSession(
            id: id, date: date, dog: dog, duration: duration,
            services: services, behavior: behavior, notes: notes,
            createdAt: createdAt, updatedAt: updatedAt
        )
    }
    static let sampleSession = makeSession()
}

// MARK: - Preview Data Collections & QA Log
struct MockData {
    static let allDogs: [Dog] = [MockDogData.sampleDog, MockDogData.anotherDog]
    static let allOwners: [DogOwner] = [MockOwnerData.sampleOwner]
    static let allAppointments: [Appointment] = [MockAppointmentData.sampleAppointment]
    static let allCharges: [Charge] = [MockChargeData.sampleCharge]
    static let allExpenses: [Expense] = [MockExpenseData.sampleExpense]
    static let allGroomingSessions: [GroomingSession] = [MockGroomingSessionData.sampleSession]

    // Audit Log for mock data usage (QA/preview/testing)
    static var auditLog: [String] = []
    static func recordUsage(_ message: String) {
        auditLog.append("\(Date()): \(message)")
        if auditLog.count > 30 { auditLog.removeFirst() }
    }
    static func recentAudit(limit: Int = 8) -> [String] {
        auditLog.suffix(limit).map { $0 }
    }
}
