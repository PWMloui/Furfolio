//
//  DashboardAccessibilitySummary.swift
//  Furfolio
//

import Foundation

/// Provides accessibility summary strings for Furfolio dashboard components.
struct DashboardAccessibilitySummary {

    /// Returns a summary of appointments for accessibility.
    static func appointmentSummary(upcomingCount: Int, completedCount: Int) -> String {
        switch (upcomingCount, completedCount) {
        case (0, 0):
            return "You have no appointments scheduled or completed."
        case (_, 0):
            return "You have \(upcomingCount) upcoming appointments."
        case (0, _):
            return "You have \(completedCount) completed appointments."
        default:
            return "You have \(upcomingCount) upcoming appointments and \(completedCount) completed appointments."
        }
    }

    /// Returns a summary of revenue data for accessibility.
    static func revenueSummary(totalRevenue: Double, revenueChangePercent: Double) -> String {
        let formattedRevenue = formatCurrency(totalRevenue)
        let changeDescription: String

        switch revenueChangePercent {
        case let x where x > 0:
            changeDescription = "increased by \(String(format: "%.1f", x)) percent"
        case let x where x < 0:
            changeDescription = "decreased by \(String(format: "%.1f", abs(x))) percent"
        default:
            changeDescription = "no change from last month"
        }

        return "Total revenue is \(formattedRevenue), \(changeDescription)."
    }

    /// Returns a summary of customer retention stats.
    static func retentionSummary(totalCustomers: Int, inactiveCustomers: Int) -> String {
        if totalCustomers == 0 {
            return "You have no customers yet."
        } else if inactiveCustomers == 0 {
            return "All \(totalCustomers) customers are active."
        } else {
            return "There are \(totalCustomers) customers in total, with \(inactiveCustomers) inactive customers."
        }
    }

    /// Returns a summary of loyalty program status.
    static func loyaltySummary(totalPoints: Int, pointsToNextReward: Int) -> String {
        if totalPoints == 0 {
            return "You haven't earned any loyalty points yet."
        } else if pointsToNextReward == 0 {
            return "You have \(totalPoints) loyalty points and have earned your next reward."
        } else {
            return "You have \(totalPoints) loyalty points. \(pointsToNextReward) points to your next reward."
        }
    }

    // MARK: - Helpers

    private static func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.currencySymbol = "$"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}
