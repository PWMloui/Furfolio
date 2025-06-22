//
//  RevenueForecastEngine.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation

// MARK: - RevenueForecastEngine (Tokenized, Modular, Accessible Revenue Projections)

/**
 `RevenueForecastEngine` is a modular, tokenized, auditable engine responsible for revenue forecasting and projections within Furfolio.

 Furfolio is designed as an offline-first, owner-focused financial management platform. This engine supports Furfolio’s mission by providing accurate, timely revenue forecasts that empower business owners to make informed decisions without requiring constant internet connectivity.

 The engine encapsulates multiple forecasting strategies, including simple linear projections, multi-month forecasts, and yearly revenue estimations, while providing extensibility points for UI integration and analytics.

 All UI summary and analytics outputs must utilize design tokens for color, font, and badge presentation to ensure consistency and accessibility. Audit and event hooks are integrated to enable comprehensive tracking and logging of forecast updates.

 This engine is built with extensibility, tokenization for UI, and audit logging in mind, ensuring a robust foundation for future enhancements.
 */

public protocol RevenueForecasting: AnyObject, Codable {
    /// Projects next month's revenue based on recent trends.
    /// - Parameter charges: Array of `Charge` representing revenue transactions.
    /// - Returns: Forecasted revenue amount for the next month.
    ///
    /// - Note: Implementations should support extensibility and tokenized UI integration without hardcoded UI elements.
    func forecastNextMonthRevenue(charges: [Charge]) -> Double

    /// Forecasts revenue for the next N months using average monthly revenue.
    /// - Parameters:
    ///   - charges: Array of `Charge` representing revenue transactions.
    ///   - months: Number of months to forecast ahead.
    /// - Returns: Array of tuples with month start `Date` and projected revenue.
    ///
    /// - Note: Designed for extensibility and integration with tokenized UI components.
    func forecastRevenue(charges: [Charge], months: Int) -> [(month: Date, projectedRevenue: Double)]

    /// Forecasts total revenue for the current year (using YTD and trend).
    /// - Parameter charges: Array of `Charge` representing revenue transactions.
    /// - Returns: Projected total revenue for the current calendar year.
    ///
    /// - Note: Supports audit logging and tokenized UI display.
    func forecastFullYearRevenue(charges: [Charge]) -> Double

    /// Returns projected month-end revenue and percent toward a target goal.
    /// - Parameters:
    ///   - charges: Array of `Charge` representing revenue transactions.
    ///   - monthlyGoal: Target revenue goal for the current month.
    /// - Returns: Tuple containing forecasted revenue and progress ratio (0.0 to 1.0).
    ///
    /// - Note: Enables audit event hooks and UI tokenization.
    func forecastGoalProgress(charges: [Charge], monthlyGoal: Double) -> (forecast: Double, progress: Double)

    /// Produces a human-readable summary string for UI dashboards.
    /// - Parameter charges: Array of `Charge` representing revenue transactions.
    /// - Returns: Summary string describing current revenue status.
    ///
    /// - Note: Future implementations should avoid hardcoded colors or icons and instead use design tokens for badges and fonts to ensure accessibility and consistency.
    func uiSummary(for charges: [Charge]) -> String
}

@MainActor
public final class RevenueForecastEngine: RevenueForecasting {
    // MARK: - Interface

    /// Shared singleton instance for app-wide usage.
    public static let shared = RevenueForecastEngine()

    /// Dummy instance for SwiftUI previews and testing.
    public static let previewEngine: RevenueForecasting = {
        let engine = RevenueForecastEngine()
        return engine
    }()

    /// Optional closure hook called after forecast updates, useful for analytics and audit logs.
    public var onForecastUpdate: ((Double) -> Void)?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /**
     Projects next month's revenue based on recent trends using a simple linear growth model.

     - Parameter charges: Array of `Charge` representing revenue transactions.
     - Returns: Forecasted revenue amount for the next month.

     Usage:
     ```
     let forecast = engine.forecastNextMonthRevenue(charges: charges)
     ```

     - Note: Designed for extensibility, tokenized UI integration, and audit logging.
     */
    public func forecastNextMonthRevenue(charges: [Charge]) -> Double {
        guard !charges.isEmpty else {
            notifyForecastUpdate(amount: 0)
            return 0
        }

        let calendar = Calendar.current
        let now = Date()
        guard let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            notifyForecastUpdate(amount: 0)
            return 0
        }
        guard let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart),
              let lastMonthEnd = calendar.date(byAdding: .day, value: -1, to: thisMonthStart) else {
            notifyForecastUpdate(amount: 0)
            return 0
        }

        let lastMonthCharges = charges.filter { $0.date >= lastMonthStart && $0.date <= lastMonthEnd }
        let thisMonthCharges = charges.filter { $0.date >= thisMonthStart && $0.date <= now }

        let lastMonthTotal = lastMonthCharges.reduce(0) { $0 + $1.amount }
        let thisMonthTotal = thisMonthCharges.reduce(0) { $0 + $1.amount }

        let growth: Double = lastMonthTotal > 0 ? (thisMonthTotal - lastMonthTotal) / lastMonthTotal : 0
        let forecast = thisMonthTotal + (thisMonthTotal * growth)
        let finalForecast = max(forecast, 0)

        notifyForecastUpdate(amount: finalForecast)
        return finalForecast
    }

    /**
     Forecasts revenue for the next N months using average monthly revenue over the last 6 months.

     - Parameters:
       - charges: Array of `Charge` representing revenue transactions.
       - months: Number of months to forecast ahead (default is 3).
     - Returns: Array of tuples containing month start `Date` and projected revenue.

     Usage:
     ```
     let forecasts = engine.forecastRevenue(charges: charges, months: 6)
     ```

     - Note: Supports tokenized UI integration and audit hooks.
     */
    public func forecastRevenue(charges: [Charge], months: Int = 3) -> [(month: Date, projectedRevenue: Double)] {
        guard !charges.isEmpty, months > 0 else {
            notifyForecastUpdate(amount: 0)
            return []
        }

        let calendar = Calendar.current
        let now = Date()
        var monthTotals: [Double] = []

        for i in 1...6 {
            guard let monthStart = calendar.date(byAdding: .month, value: -i, to: now),
                  let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart) else { continue }
            let monthCharges = charges.filter { $0.date >= monthStart && $0.date < nextMonthStart }
            let total = monthCharges.reduce(0) { $0 + $1.amount }
            monthTotals.append(total)
        }

        let avgMonthly: Double = monthTotals.isEmpty ? 0 : monthTotals.reduce(0, +) / Double(monthTotals.count)
        var forecasts: [(Date, Double)] = []

        for i in 1...months {
            if let nextMonth = calendar.date(byAdding: .month, value: i, to: now) {
                forecasts.append((nextMonth, avgMonthly))
            }
        }

        notifyForecastUpdate(amount: avgMonthly)
        return forecasts
    }

    /**
     Forecasts total revenue for the current year based on year-to-date revenue and trend extrapolation.

     - Parameter charges: Array of `Charge` representing revenue transactions.
     - Returns: Projected total revenue for the current calendar year.

     Usage:
     ```
     let yearlyForecast = engine.forecastFullYearRevenue(charges: charges)
     ```

     - Note: Designed for audit logging and tokenized UI display.
     */
    public func forecastFullYearRevenue(charges: [Charge]) -> Double {
        let calendar = Calendar.current
        let now = Date()
        guard let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) else {
            notifyForecastUpdate(amount: 0)
            return 0
        }

        let ytdCharges = charges.filter { $0.date >= yearStart && $0.date <= now }
        let totalYTD = ytdCharges.reduce(0) { $0 + $1.amount }

        let daysSoFar = calendar.dateComponents([.day], from: yearStart, to: now).day ?? 1
        let totalDays = calendar.range(of: .day, in: .year, for: now)?.count ?? 365

        let projected = (Double(totalYTD) / Double(daysSoFar)) * Double(totalDays)
        notifyForecastUpdate(amount: projected)
        return projected
    }

    /**
     Calculates projected month-end revenue and progress toward a monthly revenue goal.

     - Parameters:
       - charges: Array of `Charge` representing revenue transactions.
       - monthlyGoal: Target revenue goal for the current month.
     - Returns: Tuple containing forecasted revenue and progress ratio (0.0 to 1.0).

     Usage:
     ```
     let (forecast, progress) = engine.forecastGoalProgress(charges: charges, monthlyGoal: 10000)
     ```

     - Note: Enables audit event hooks and UI tokenization.
     */
    public func forecastGoalProgress(charges: [Charge], monthlyGoal: Double) -> (forecast: Double, progress: Double) {
        let calendar = Calendar.current
        let now = Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            notifyForecastUpdate(amount: 0)
            return (0, 0)
        }

        let monthCharges = charges.filter { $0.date >= monthStart && $0.date <= now }
        let totalSoFar = monthCharges.reduce(0) { $0 + $1.amount }

        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let daysSoFar = calendar.dateComponents([.day], from: monthStart, to: now).day ?? 1

        let projected = (Double(totalSoFar) / Double(daysSoFar)) * Double(daysInMonth)
        let progress = monthlyGoal > 0 ? projected / monthlyGoal : 0
        let cappedProgress = min(progress, 1.0)

        notifyForecastUpdate(amount: projected)
        return (projected, cappedProgress)
    }

    /**
     Produces a human-readable summary string for UI dashboards to quickly convey revenue status.

     - Parameter charges: Array of `Charge` representing revenue transactions.
     - Returns: Readable summary string.

     Usage:
     ```
     let summary = engine.uiSummary(for: charges)
     ```

     - Note: Future summary outputs must return not just strings, but also color and icon tokens for dashboard badge presentation to support tokenized UI and accessibility.

     - TODO: Return a tuple including summary text, badge color token (AppColors), and icon (SF Symbol or token) for dashboard use.
     */
    public func uiSummary(for charges: [Charge]) -> String {
        let forecast = forecastNextMonthRevenue(charges: charges)
        let yearlyProjection = forecastFullYearRevenue(charges: charges)

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2

        let forecastStr = formatter.string(from: NSNumber(value: forecast)) ?? "$0"
        let yearlyStr = formatter.string(from: NSNumber(value: yearlyProjection)) ?? "$0"

        return "Next Month Forecast: \(forecastStr)\nYearly Projection: \(yearlyStr)"
    }

    // MARK: - Internal Helpers

    private func notifyForecastUpdate(amount: Double) {
        onForecastUpdate?(amount)
        NotificationCenter.default.post(name: .RevenueForecastUpdated, object: self, userInfo: ["amount": amount])
    }
}

// MARK: - Notification.Name Extension

public extension Notification.Name {
    /// Notification posted after any revenue forecast update occurs.
    static let RevenueForecastUpdated = Notification.Name("RevenueForecastUpdated")
}

// MARK: - Codable Support

extension RevenueForecastEngine {
    enum CodingKeys: CodingKey {
        // No stored properties to encode/decode currently.
    }

    public convenience init(from decoder: Decoder) throws {
        self.init()
        // No properties to decode; placeholder for future expansion.
    }

    public func encode(to encoder: Encoder) throws {
        // No properties to encode; placeholder for future expansion.
    }
}
