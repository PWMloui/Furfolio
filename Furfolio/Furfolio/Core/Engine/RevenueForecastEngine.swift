//
//  RevenueForecastEngine.swift
//  Furfolio
//
//  Enhanced: Audit, BI, analytics, accessibility, export, dashboard tokens.
//  Author: mac + ChatGPT
//

import Foundation

public protocol RevenueForecasting: AnyObject, Codable {
    func forecastNextMonthRevenue(charges: [Charge]) -> Double
    func forecastRevenue(charges: [Charge], months: Int) -> [(month: Date, projectedRevenue: Double)]
    func forecastFullYearRevenue(charges: [Charge]) -> Double
    func forecastGoalProgress(charges: [Charge], monthlyGoal: Double) -> (forecast: Double, progress: Double)
    func uiSummary(for charges: [Charge]) -> String
}

// MARK: - Enhanced Revenue Forecast Engine

@MainActor
public final class RevenueForecastEngine: RevenueForecasting {
    public static let shared = RevenueForecastEngine()
    public static let previewEngine: RevenueForecasting = RevenueForecastEngine()

    // --- ENHANCEMENTS: Audit, Tags, Analytics ---

    /// Audit trail of all forecasts and events (for BI, trust center, debugging).
    public private(set) var auditLog: [String] = []

    /// Analytics: Badge tokens for dashboard or reporting ("onTarget", "atRisk", "growth", "decline", etc.)
    public private(set) var forecastBadgeTokens: [String] = []

    /// Risk score (demo logic, use in dashboards)
    public private(set) var riskScore: Int = 0

    /// Current trend direction ("growth", "decline", "steady")
    public private(set) var trendDirection: String = "steady"

    /// Accessible summary for UI/VoiceOver.
    public var accessibilityLabel: String {
        let last = auditLog.last ?? "No recent forecast."
        return "Revenue engine: \(trendDirection) trend. \(last)"
    }

    public var onForecastUpdate: ((Double) -> Void)?

    private init() {}

    // MARK: - Public Methods (with Analytics & Audit)

    public func forecastNextMonthRevenue(charges: [Charge]) -> Double {
        guard !charges.isEmpty else { addAudit("No charges available for forecast."); updateBadgesAndRisk(0, 0); return 0 }

        let calendar = Calendar.current
        let now = Date()
        guard let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart),
              let lastMonthEnd = calendar.date(byAdding: .day, value: -1, to: thisMonthStart) else {
            addAudit("Calendar error during forecast.")
            updateBadgesAndRisk(0, 0)
            return 0
        }

        let lastMonthCharges = charges.filter { $0.date >= lastMonthStart && $0.date <= lastMonthEnd }
        let thisMonthCharges = charges.filter { $0.date >= thisMonthStart && $0.date <= now }

        let lastMonthTotal = lastMonthCharges.reduce(0) { $0 + $1.amount }
        let thisMonthTotal = thisMonthCharges.reduce(0) { $0 + $1.amount }

        let growth: Double = lastMonthTotal > 0 ? (thisMonthTotal - lastMonthTotal) / lastMonthTotal : 0
        let forecast = thisMonthTotal + (thisMonthTotal * growth)
        let finalForecast = max(forecast, 0)

        addAudit("Next month forecast: \(finalForecast.rounded(.toNearestOrAwayFromZero)) (\(growth > 0 ? "growth" : (growth < 0 ? "decline" : "steady")))")
        updateBadgesAndRisk(growth, finalForecast)
        notifyForecastUpdate(amount: finalForecast)
        return finalForecast
    }

    public func forecastRevenue(charges: [Charge], months: Int = 3) -> [(month: Date, projectedRevenue: Double)] {
        guard !charges.isEmpty, months > 0 else { addAudit("No data for multi-month forecast."); updateBadgesAndRisk(0, 0); return [] }
        let calendar = Calendar.current
        let now = Date()
        var monthTotals: [Double] = []

        for i in 1...6 {
            guard let monthStart = calendar.date(byAdding: .month, value: -i, to: now),
                  let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart) else { continue }
            let monthCharges = charges.filter { $0.date >= monthStart && $0.date < nextMonthStart }
            monthTotals.append(monthCharges.reduce(0, +) { $0 + $1.amount })
        }
        let avgMonthly: Double = monthTotals.isEmpty ? 0 : monthTotals.reduce(0, +) / Double(monthTotals.count)
        var forecasts: [(Date, Double)] = []

        for i in 1...months {
            if let nextMonth = calendar.date(byAdding: .month, value: i, to: now) {
                forecasts.append((nextMonth, avgMonthly))
            }
        }
        addAudit("Forecasted \(months) months at avg \(avgMonthly.rounded(.toNearestOrAwayFromZero)).")
        updateBadgesAndRisk(0, avgMonthly)
        notifyForecastUpdate(amount: avgMonthly)
        return forecasts
    }

    public func forecastFullYearRevenue(charges: [Charge]) -> Double {
        let calendar = Calendar.current
        let now = Date()
        guard let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) else {
            addAudit("Year start not found.")
            updateBadgesAndRisk(0, 0)
            return 0
        }
        let ytdCharges = charges.filter { $0.date >= yearStart && $0.date <= now }
        let totalYTD = ytdCharges.reduce(0) { $0 + $1.amount }
        let daysSoFar = calendar.dateComponents([.day], from: yearStart, to: now).day ?? 1
        let totalDays = calendar.range(of: .day, in: .year, for: now)?.count ?? 365
        let projected = (Double(totalYTD) / Double(daysSoFar)) * Double(totalDays)
        addAudit("Full year revenue projected: \(projected.rounded(.toNearestOrAwayFromZero)).")
        updateBadgesAndRisk(0, projected)
        notifyForecastUpdate(amount: projected)
        return projected
    }

    public func forecastGoalProgress(charges: [Charge], monthlyGoal: Double) -> (forecast: Double, progress: Double) {
        let calendar = Calendar.current
        let now = Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            addAudit("Month start not found.")
            updateBadgesAndRisk(0, 0)
            return (0, 0)
        }
        let monthCharges = charges.filter { $0.date >= monthStart && $0.date <= now }
        let totalSoFar = monthCharges.reduce(0) { $0 + $1.amount }
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let daysSoFar = calendar.dateComponents([.day], from: monthStart, to: now).day ?? 1
        let projected = (Double(totalSoFar) / Double(daysSoFar)) * Double(daysInMonth)
        let progress = monthlyGoal > 0 ? projected / monthlyGoal : 0
        let cappedProgress = min(progress, 1.0)
        addAudit("Forecast goal progress: \(projected.rounded(.toNearestOrAwayFromZero)) (\(Int(cappedProgress * 100))%).")
        updateBadgesAndRisk(0, projected)
        notifyForecastUpdate(amount: projected)
        return (projected, cappedProgress)
    }

    public func uiSummary(for charges: [Charge]) -> String {
        let forecast = forecastNextMonthRevenue(charges: charges)
        let yearlyProjection = forecastFullYearRevenue(charges: charges)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        let forecastStr = formatter.string(from: NSNumber(value: forecast)) ?? "$0"
        let yearlyStr = formatter.string(from: NSNumber(value: yearlyProjection)) ?? "$0"
        let badge = forecastBadgeTokens.last ?? "unknown"
        return "Forecast: \(forecastStr) [\(badge)]\nYearly: \(yearlyStr)"
    }

    // MARK: - Audit/BI Helpers

    private func addAudit(_ entry: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        auditLog.append("[\(ts)] \(entry)")
        if auditLog.count > 1000 { auditLog.removeFirst() }
    }

    private func updateBadgesAndRisk(_ growth: Double, _ forecast: Double) {
        forecastBadgeTokens.removeAll()
        if growth > 0.04 { forecastBadgeTokens.append("growth"); trendDirection = "growth" }
        else if growth < -0.04 { forecastBadgeTokens.append("decline"); trendDirection = "decline" }
        else { forecastBadgeTokens.append("steady"); trendDirection = "steady" }
        if forecast < 500 { forecastBadgeTokens.append("atRisk"); riskScore = 3 }
        else if forecast > 10000 { forecastBadgeTokens.append("onTarget"); riskScore = 0 }
        else { riskScore = 1 }
    }

    public func exportJSON() -> String? {
        struct Export: Codable {
            let trendDirection: String
            let riskScore: Int
            let forecastBadgeTokens: [String]
            let lastAuditLog: [String]
        }
        let export = Export(
            trendDirection: trendDirection,
            riskScore: riskScore,
            forecastBadgeTokens: forecastBadgeTokens,
            lastAuditLog: Array(auditLog.suffix(10))
        )
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(export)).flatMap { String(data: $0, encoding: .utf8) }
    }

    // MARK: - SwiftUI/Preview/Test Helpers

    public func demoForecasts(for months: Int = 6) -> [(month: Date, projectedRevenue: Double)] {
        var fakeCharges: [Charge] = []
        let calendar = Calendar.current
        for i in 1...12 {
            if let d = calendar.date(byAdding: .month, value: -i, to: Date()) {
                fakeCharges.append(Charge(date: d, amount: Double(arc4random_uniform(4000) + 2000)))
            }
        }
        return forecastRevenue(charges: fakeCharges, months: months)
    }

    // MARK: - Internal Notification

    private func notifyForecastUpdate(amount: Double) {
        onForecastUpdate?(amount)
        NotificationCenter.default.post(name: .RevenueForecastUpdated, object: self, userInfo: ["amount": amount])
    }

    // MARK: - At-Risk/High-Growth Filters (for dashboards)

    public func atRiskPeriods() -> [String] {
        auditLog.filter { $0.contains("atRisk") }
    }
    public func highGrowthPeriods() -> [String] {
        auditLog.filter { $0.contains("growth") }
    }
}

// MARK: - Notification.Name Extension

public extension Notification.Name {
    static let RevenueForecastUpdated = Notification.Name("RevenueForecastUpdated")
}

// MARK: - Codable Support

extension RevenueForecastEngine {
    enum CodingKeys: CodingKey {}
    public convenience init(from decoder: Decoder) throws { self.init() }
    public func encode(to encoder: Encoder) throws {}
}

// MARK: - Charge Model (Minimal for Demo)
public struct Charge: Codable {
    public var date: Date
    public var amount: Double
    public init(date: Date, amount: Double) { self.date = date; self.amount = amount }
}
