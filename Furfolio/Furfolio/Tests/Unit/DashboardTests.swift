//
//  DashboardTests.swift
//  Furfolio
//
//  Enhanced 2025: Enterprise-Grade, Auditable, Robust Tests
//

import XCTest
@testable import Furfolio

final class DashboardTests: XCTestCase {
    var viewModel: DashboardViewModel!
    var owners: [DogOwner]!
    var appointments: [Appointment]!
    var charges: [Charge]!
    static var testAuditLog: [String] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Prepare demo data
        let owner1 = DogOwner(ownerName: "Ava", contactInfo: "555-1000")
        let owner2 = DogOwner(ownerName: "Ben", contactInfo: "555-2000")

        let dog1 = Dog(name: "Milo", breed: "Beagle", owner: owner1)
        let dog2 = Dog(name: "Max", breed: "Poodle", owner: owner2)

        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        let appt1 = Appointment(date: now, owner: owner1, dog: dog1, serviceType: .fullGroom, durationMinutes: 90)
        let appt2 = Appointment(date: yesterday, owner: owner2, dog: dog2, serviceType: .bath, durationMinutes: 60)

        let charge1 = Charge(date: now, type: .service, amount: 80, notes: "Full Groom", owner: owner1, appointment: appt1)
        let charge2 = Charge(date: yesterday, type: .service, amount: 45, notes: "Bath", owner: owner2, appointment: appt2)

        // Set up arrays
        owners = [owner1, owner2]
        appointments = [appt1, appt2]
        charges = [charge1, charge2]

        viewModel = DashboardViewModel(
            owners: owners,
            appointments: appointments,
            charges: charges,
            revenueAnalyzer: RevenueAnalyzer(),
            retentionAnalyzer: CustomerRetentionAnalyzer()
        )
        Self.testAuditLog.append("Setup: Demo data and DashboardViewModel created")
    }

    override func tearDownWithError() throws {
        owners = nil
        appointments = nil
        charges = nil
        viewModel = nil
        Self.testAuditLog.append("Teardown: Reset all test objects")
        try super.tearDownWithError()
    }

    func testTotalRevenueCalculation() {
        let total = viewModel.totalRevenue
        XCTAssertEqual(total, 125.0, accuracy: 0.01, "Dashboard should show total revenue from all charges. Expected 125.0, got \(total)")
        Self.testAuditLog.append("Checked: total revenue calculation")
    }

    func testAppointmentCount() {
        let count = viewModel.totalAppointments
        XCTAssertEqual(count, 2, "Dashboard should count all appointments. Expected 2, got \(count)")
        Self.testAuditLog.append("Checked: appointment count")
    }

    func testTopServiceDetection() {
        let top = viewModel.topServiceType
        XCTAssertEqual(top, .fullGroom, "Dashboard should detect most popular service. Expected .fullGroom, got \(String(describing: top))")
        Self.testAuditLog.append("Checked: top service detection")
    }

    func testActiveOwnersCount() {
        let active = viewModel.activeOwnersCount
        XCTAssertEqual(active, 2, "Should count both owners as active. Expected 2, got \(active)")
        Self.testAuditLog.append("Checked: active owners count")
    }

    func testRevenueTrend() {
        let trend = viewModel.revenueTrend(forLastDays: 2)
        XCTAssertEqual(trend.count, 2, "Should provide daily revenue for 2 days. Got \(trend.count)")
        XCTAssertTrue(trend.values.contains(80.0), "Should include correct revenue for full groom")
        XCTAssertTrue(trend.values.contains(45.0), "Should include correct revenue for bath")
        Self.testAuditLog.append("Checked: revenue trend for last 2 days")
    }

    func testRetentionAlertForInactiveOwners() {
        let oldOwner = DogOwner(ownerName: "Zoe", contactInfo: "555-9999")
        let oldDog = Dog(name: "Rusty", breed: "Corgi", owner: oldOwner)
        let oldDate = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        let oldAppt = Appointment(date: oldDate, owner: oldOwner, dog: oldDog, serviceType: .bath, durationMinutes: 60)
        viewModel.owners.append(oldOwner)
        viewModel.appointments.append(oldAppt)
        let atRisk = viewModel.atRiskOwners
        XCTAssertTrue(atRisk.contains(where: { $0.ownerName == "Zoe" }), "Should alert for at-risk/inactive owners (expected to find Zoe)")
        Self.testAuditLog.append("Checked: retention alert for inactive owners")
    }

    // MARK: - Edge/Negative Tests

    func testNoChargesResultsInZeroRevenue() {
        viewModel.charges = []
        let total = viewModel.totalRevenue
        XCTAssertEqual(total, 0.0, "Zero charges should result in zero revenue, got \(total)")
        Self.testAuditLog.append("Checked: zero revenue when charges are empty")
    }

    func testNoAppointmentsResultsInZeroCount() {
        viewModel.appointments = []
        let count = viewModel.totalAppointments
        XCTAssertEqual(count, 0, "No appointments should result in count of zero")
        Self.testAuditLog.append("Checked: zero appointment count when no appointments exist")
    }

    func testLargeRevenueAndRounding() {
        viewModel.charges.append(Charge(date: Date(), type: .service, amount: 999999.99, notes: "Big deal", owner: owners[0], appointment: appointments[0]))
        let total = viewModel.totalRevenue
        XCTAssertEqual(total, 125.0 + 999999.99, accuracy: 0.01, "Should handle very large revenue amounts and rounding")
        Self.testAuditLog.append("Checked: large revenue and rounding")
    }

    func testTopServiceTypeTie() {
        // Add another fullGroom to create a tie
        let appt3 = Appointment(date: Date(), owner: owners[1], dog: Dog(name: "Fido", breed: "Beagle", owner: owners[1]), serviceType: .bath, durationMinutes: 60)
        let appt4 = Appointment(date: Date(), owner: owners[0], dog: Dog(name: "Bailey", breed: "Labrador", owner: owners[0]), serviceType: .fullGroom, durationMinutes: 60)
        viewModel.appointments.append(contentsOf: [appt3, appt4])
        let top = viewModel.topServiceType
        XCTAssertNotNil(top, "Should still report a top service type in the event of a tie")
        Self.testAuditLog.append("Checked: top service detection with tie")
    }

    // MARK: - Audit Log Export

    func testAuditLogExport() {
        let logs = Self.testAuditLog.suffix(14).joined(separator: "\n")
        print("Furfolio DashboardTests AuditLog:\n\(logs)")
    }
}
