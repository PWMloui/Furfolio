//
//  RevenueAnalyzerTests.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import XCTest
@testable import Furfolio

final class RevenueAnalyzerTests: XCTestCase {
    var analyzer: RevenueAnalyzer!
    var charges: [Charge]!
    var appointments: [Appointment]!

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
    }

    override func tearDownWithError() throws {
        analyzer = nil
        charges = nil
        appointments = nil
        try super.tearDownWithError()
    }

    func testTotalRevenue() {
        let total = analyzer.totalRevenue(for: charges)
        XCTAssertEqual(total, 210.0, accuracy: 0.01, "Total revenue should match sum of all charges")
    }

    func testRevenuePerDay() {
        let revByDay = analyzer.revenuePerDay(for: charges)
        XCTAssertEqual(revByDay.count, 4, "Should be 4 days of revenue")
        let today = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(revByDay[today], 60, "Today's revenue should be 60")
    }

    func testRevenueTrend() {
        let trend = analyzer.revenueTrend(for: charges)
        XCTAssertEqual(trend.count, 4, "Trend should have 4 data points")
        XCTAssertEqual(trend.last?.amount, 60, "Last day in trend should have correct revenue")
    }

    func testMostPopularService() {
        let popular = analyzer.mostPopularService(from: appointments)
        XCTAssertEqual(popular, .bath, "Bath should be most popular")
    }

    func testRevenueForServiceType() {
        let totalBath = analyzer.totalRevenue(for: charges, serviceType: .bath)
        XCTAssertEqual(totalBath, 110, accuracy: 0.01, "Total bath revenue should be 110")
    }

    func testAverageRevenuePerAppointment() {
        let avg = analyzer.averageRevenuePerAppointment(charges: charges, appointments: appointments)
        XCTAssertEqual(avg, 52.5, accuracy: 0.01, "Average should be total divided by count")
    }

    func testRevenueGrowthRate() {
        let growth = analyzer.revenueGrowthRate(for: charges)
        XCTAssertGreaterThanOrEqual(growth, 0, "Growth should not be negative with positive trend")
    }

    func testHighRevenueDayDetection() {
        let highs = analyzer.detectHighRevenueDays(in: charges, threshold: 60)
        XCTAssertTrue(highs.contains { $0.amount >= 60 }, "Should include days with revenue >= 60")
    }

    func testLowRevenueDayDetection() {
        let lows = analyzer.detectLowRevenueDays(in: charges, threshold: 35)
        XCTAssertTrue(lows.contains { $0.amount <= 35 }, "Should include days with revenue <= 35")
    }
}
