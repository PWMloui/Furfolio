//
//  DashboardTests.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import XCTest
@testable import Furfolio

final class DashboardTests: XCTestCase {
    var viewModel: DashboardViewModel!
    var owners: [DogOwner]!
    var appointments: [Appointment]!
    var charges: [Charge]!
    
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
        
        // Mock your analytics service or view model
        viewModel = DashboardViewModel(
            owners: owners,
            appointments: appointments,
            charges: charges,
            revenueAnalyzer: RevenueAnalyzer(),
            retentionAnalyzer: CustomerRetentionAnalyzer()
        )
    }
    
    override func tearDownWithError() throws {
        owners = nil
        appointments = nil
        charges = nil
        viewModel = nil
        try super.tearDownWithError()
    }
    
    func testTotalRevenueCalculation() {
        let total = viewModel.totalRevenue
        XCTAssertEqual(total, 125.0, "Dashboard should show total revenue from all charges")
    }
    
    func testAppointmentCount() {
        let count = viewModel.totalAppointments
        XCTAssertEqual(count, 2, "Dashboard should count all appointments")
    }
    
    func testTopServiceDetection() {
        let top = viewModel.topServiceType
        XCTAssertEqual(top, .fullGroom, "Dashboard should detect most popular service")
    }
    
    func testActiveOwnersCount() {
        let active = viewModel.activeOwnersCount
        XCTAssertEqual(active, 2, "Should count both owners as active")
    }
    
    func testRevenueTrend() {
        let trend = viewModel.revenueTrend(forLastDays: 2)
        XCTAssertEqual(trend.count, 2, "Should provide daily revenue for 2 days")
        XCTAssertTrue(trend.values.contains(80.0), "Should include correct revenue for full groom")
        XCTAssertTrue(trend.values.contains(45.0), "Should include correct revenue for bath")
    }
    
    func testRetentionAlertForInactiveOwners() {
        // Simulate last visit 90 days ago
        let oldOwner = DogOwner(ownerName: "Zoe", contactInfo: "555-9999")
        let oldDog = Dog(name: "Rusty", breed: "Corgi", owner: oldOwner)
        let oldDate = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        let oldAppt = Appointment(date: oldDate, owner: oldOwner, dog: oldDog, serviceType: .bath, durationMinutes: 60)
        viewModel.owners.append(oldOwner)
        viewModel.appointments.append(oldAppt)
        
        let atRisk = viewModel.atRiskOwners
        XCTAssertTrue(atRisk.contains(where: { $0.ownerName == "Zoe" }), "Should alert for at-risk/inactive owners")
    }
}
