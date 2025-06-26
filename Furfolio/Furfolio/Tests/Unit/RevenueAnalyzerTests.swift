//
//  RevenueAnalyzerTests.swift
//  Furfolio
//
//  Enhanced 2025: Enterprise-Grade, Auditable, Robust Tests
//

import XCTest
@testable import Furfolio

final class RevenueAnalyzerTests: XCTestCase {
    var analyzer: RevenueAnalyzer!
    var charges: [Charge]!
    var appointments: [Appointment]!
    static var testAuditLog: [String] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Setup demo data for testing
        charges = [
            Charge(date: Date().addingTimeInterval(-86400 * 3), type: .service, amount: 50, notes: "Bath", owner: nil, appointment: nil),
            Charge(date: Date().addingTimeInterval(-86400 * 2), type: .service, amount: 70, notes: "Full Groom", owner: nil, appointment: nil),
            Charge(date: Date().addingTimeInterval(-86400), type: .service, amount: 30, notes: "Nail Trim", owner: nil, appointment: nil),
            Charge(date: Date(), type: .service, amount: 60, notes: "Bath", owner: nil, appointment: nil)
        ]
        appointments = [
            Appointment(date: Date().addingTimeInterval(-86400 * 3), owner: nil, dog: nil, serviceType: .bath, durationMinutes: 60),
            Appointment(date: Date().addingTimeInterval(-86400 * 2), owner: nil, dog: nil, serviceType: .fullGroom, durationMinutes: 90),
            Appointment(date: Date().addingTimeInterval(-86400), owner: nil, dog: nil, serviceType: .nails, durationMinutes: 30),
            Appointment(date: Date(), owner: nil, dog: nil, serviceType: .bath, durationMinutes: 60)
        ]
        analyzer = RevenueAnalyzer()
        Self.testAuditLog.append("Setup: Demo charges and appointments initialized")
    }

    override func tearDownWithError() throws {
        analyzer = nil
        charges = nil
        appointments = nil
        Self.testAuditLog.append("Teardown: Reset all objects")
        try super.tearDownWithError()
    }

    func testTotalRevenue() {
        let total = analyzer.totalRevenue(for: charges)
        XCTAssertEqual(total, 210.0, accuracy: 0.01, "Total revenue should be 210.0, got \(total)")
        Self.testAuditLog.append("Checked: total revenue")
    }

    func testRevenuePerDay() {
        let revByDay = analyzer.revenuePerDay(for: charges)
        XCTAssertEqual(revByDay.count, 4, "Should be 4 days of revenue, got \(revByDay.count)")
        let today = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(revByDay[today], 60, "Today's revenue should be 60, got \(revByDay[today] ?? -1)")
        Self.testAuditLog.append("Checked: revenue per day")
    }

    func testRevenueTrend() {
        let trend = analyzer.revenueTrend(for: charges)
        XCTAssertEqual(trend.count, 4, "Trend should have 4 data points, got \(trend.count)")
        XCTAssertEqual(trend.last?.amount, 60, "Last day in trend should have revenue 60, got \(trend.last?.amount ?? -1)")
        Self.testAuditLog.append("Checked: revenue trend")
    }

    func testMostPopularService() {
        let popular = analyzer.mostPopularService(from: appointments)
        XCTAssertEqual(popular, .bath, "Most popular service should be bath, got \(String(describing: popular))")
        Self.testAuditLog.append("Checked: most popular service")
    }

    func testRevenueForServiceType() {
        let totalBath = analyzer.totalRevenue(for: charges, serviceType: .bath)
        XCTAssertEqual(totalBath, 110, accuracy: 0.01, "Total bath revenue should be 110, got \(totalBath)")
        Self.testAuditLog.append("Checked: revenue for service type")
    }

    func testAverageRevenuePerAppointment() {
        let avg = analyzer.averageRevenuePerAppointment(charges: charges, appointments: appointments)
        XCTAssertEqual(avg, 52.5, accuracy: 0.01, "Average should be 52.5, got \(avg)")
        Self.testAuditLog.append("Checked: average revenue per appointment")
    }

    func testRevenueGrowthRate() {
        let growth = analyzer.revenueGrowthRate(for: charges)
        XCTAssertGreaterThanOrEqual(growth, 0, "Growth should be >= 0, got \(growth)")
        Self.testAuditLog.append("Checked: revenue growth rate")
    }

    func testHighRevenueDayDetection() {
        let highs = analyzer.detectHighRevenueDays(in: charges, threshold: 60)
        XCTAssertTrue(highs.contains { $0.amount >= 60 }, "Should include days with revenue >= 60, found: \(highs.map { $0.amount })")
        Self.testAuditLog.append("Checked: high revenue day detection")
    }

    func testLowRevenueDayDetection() {
        let lows = analyzer.detectLowRevenueDays(in: charges, threshold: 35)
        XCTAssertTrue(lows.contains { $0.amount <= 35 }, "Should include days with revenue <= 35, found: \(lows.map { $0.amount })")
        Self.testAuditLog.append("Checked: low revenue day detection")
    }

    // --- ENHANCED TESTS BELOW ---

    func testZeroRevenueIfNoCharges() {
        let total = analyzer.totalRevenue(for: [])
        XCTAssertEqual(total, 0, "No charges should result in 0 revenue, got \(total)")
        Self.testAuditLog.append("Checked: zero revenue if no charges")
    }

    func testZeroAppointmentsAverageRevenue() {
        let avg = analyzer.averageRevenuePerAppointment(charges: charges, appointments: [])
        XCTAssertEqual(avg, 0, "No appointments should result in average revenue of 0, got \(avg)")
        Self.testAuditLog.append("Checked: average revenue per appointment with zero appointments")
    }

    func testVeryLargeRevenue() {
        let hugeCharge = Charge(date: Date(), type: .service, amount: 1_000_000, notes: "Mega Groom", owner: nil, appointment: nil)
        let total = analyzer.totalRevenue(for: charges + [hugeCharge])
        XCTAssertEqual(total, 1_000_210, accuracy: 0.01, "Should handle very large revenue correctly, got \(total)")
        Self.testAuditLog.append("Checked: very large revenue")
    }

    func testVarianceAndOutlierDetection() {
        // Add an outlier
        let outlier = Charge(date: Date().addingTimeInterval(-86400*5), type: .service, amount: 1000, notes: "Outlier", owner: nil, appointment: nil)
        let extended = charges + [outlier]
        let variance = analyzer.revenueVariance(for: extended)
        XCTAssertTrue(variance > 0, "Variance should be positive with an outlier, got \(variance)")
        let outliers = analyzer.detectRevenueOutliers(in: extended, threshold: 3.0)
        XCTAssertTrue(outliers.contains(where: { $0.amount == 1000 }), "Should detect the outlier charge")
        Self.testAuditLog.append("Checked: variance and outlier detection")
    }

    func testMissingDayDetection() {
        // Remove a day from charges and test
        let filtered = charges.filter { $0.amount != 30 }
        let days = analyzer.revenuePerDay(for: filtered)
        XCTAssertEqual(days.count, 3, "Should only have 3 days after filtering, got \(days.count)")
        Self.testAuditLog.append("Checked: missing day in revenue per day")
    }

    func testAuditLogExport() {
        let logs = Self.testAuditLog.suffix(14).joined(separator: "\n")
        print("Furfolio RevenueAnalyzerTests AuditLog:\n\(logs)")
    }
}
