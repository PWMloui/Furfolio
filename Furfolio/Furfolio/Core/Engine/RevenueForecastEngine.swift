//
//  RevenueForecastEngine.swift
//  Furfolio
//
//  Enhanced: Audit, BI, analytics, accessibility, export, dashboard tokens, trust center compliance.
//  Author: mac + ChatGPT
//

import Foundation

// MARK: - Audit Context (set at login/session)
public struct RevenueForecastAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "RevenueForecastEngine"
}

// MARK: - Analytics Logger Protocol & Null Logger

public protocol RevenueForecastAnalyticsLogger {
    var testMode: Bool { get }
    func logEvent(
        name: String,
        parameters: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

public struct NullRevenueForecastAnalyticsLogger: RevenueForecastAnalyticsLogger {
    public let testMode: Bool = true
    public init() {}
    public func logEvent(
        name: String,
        parameters: [String: Any]? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) async {
        let paramStr = parameters?.map { "\($0): \($1)" }.joined(separator: ", ") ?? "none"
        print("[NullRevenueForecastAnalyticsLogger][TEST MODE] Event: \(name), Parameters: \(paramStr) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
    }
}

// MARK: - RevenueForecasting Protocol

public protocol RevenueForecasting: AnyObject, Codable {
    func forecastNextMonthRevenue(charges: [Charge]) async -> Double
    func forecastRevenue(charges: [Charge], months: Int) async -> [(month: Date, projectedRevenue: Double)]
    func forecastFullYearRevenue(charges: [Charge]) async -> Double
    func forecastGoalProgress(charges: [Charge], monthlyGoal: Double) async -> (forecast: Double, progress: Double)
    func uiSummary(for charges: [Charge]) async -> String
}

// MARK: - Enhanced Revenue Forecast Engine

@MainActor
public final class RevenueForecastEngine: RevenueForecasting, Codable {
    public static let shared = RevenueForecastEngine()
    public static let previewEngine: RevenueForecasting = RevenueForecastEngine()

    // MARK: - Typealiases & Enums

    public typealias ForecastBadgeToken = String

    public enum ForecastBadge: String, CaseIterable {
        case growth
        case decline
        case steady
        case atRisk
        case onTarget

        public var localizedDescription: String {
            switch self {
            case .growth: return NSLocalizedString("badge_growth", value: "Growth", comment: "")
            case .decline: return NSLocalizedString("badge_decline", value: "Decline", comment: "")
            case .steady: return NSLocalizedString("badge_steady", value: "Steady", comment: "")
            case .atRisk: return NSLocalizedString("badge_atRisk", value: "At Risk", comment: "")
            case .onTarget: return NSLocalizedString("badge_onTarget", value: "On Target", comment: "")
            }
        }
    }

    // MARK: - ENHANCEMENTS: Audit, Tags, Analytics

    public private(set) var auditLog: [String] = []
    public private(set) var forecastBadgeTokens: [ForecastBadgeToken] = []
    public private(set) var riskScore: Int = 0
    public private(set) var trendDirection: String = NSLocalizedString("trend_steady", value: "steady", comment: "Default trend direction")

    public var accessibilityLabel: String {
        let lastEntry = auditLog.last ?? NSLocalizedString("accessibility_noRecentForecast", value: "No recent forecast.", comment: "")
        let trendLocalized = localizedTrendDirection()
        let formatString = NSLocalizedString("accessibility_revenueEngineSummary", value: "Revenue engine: %@ trend. %@", comment: "")
        return String(format: formatString, trendLocalized, lastEntry)
    }

    public var onForecastUpdate: ((Double) -> Void)?

    // MARK: - Trust Center Audit/Event Buffer

    private var analyticsLogger: RevenueForecastAnalyticsLogger = NullRevenueForecastAnalyticsLogger()
    private var auditEventBuffer: [(timestamp: Date, name: String, parameters: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
    private let auditEventBufferMax = 30

    private init() {}

    // MARK: - Public Methods (with Analytics & Audit)

    public func forecastNextMonthRevenue(charges: [Charge]) async -> Double {
        guard !charges.isEmpty else {
            await addAudit(NSLocalizedString("audit_noCharges", value: "No charges available for forecast.", comment: ""))
            updateBadgesAndRisk(growth: 0, forecast: 0)
            await logAuditEvent(name: "forecastNextMonthRevenue_noCharges", parameters: nil)
            return 0
        }

        let calendar = Calendar.current
        let now = Date()
        guard let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart),
              let lastMonthEnd = calendar.date(byAdding: .day, value: -1, to: thisMonthStart) else {
            await addAudit(NSLocalizedString("audit_calendarError", value: "Calendar error during forecast.", comment: ""))
            updateBadgesAndRisk(growth: 0, forecast: 0)
            await logAuditEvent(name: "forecastNextMonthRevenue_calendarError", parameters: nil)
            return 0
        }

        let lastMonthCharges = charges.filter { $0.date >= lastMonthStart && $0.date <= lastMonthEnd }
        let thisMonthCharges = charges.filter { $0.date >= thisMonthStart && $0.date <= now }

        let lastMonthTotal = lastMonthCharges.reduce(0) { $0 + $1.amount }
        let thisMonthTotal = thisMonthCharges.reduce(0) { $0 + $1.amount }

        let growth: Double = lastMonthTotal > 0 ? (thisMonthTotal - lastMonthTotal) / lastMonthTotal : 0
        let forecast = thisMonthTotal + (thisMonthTotal * growth)
        let finalForecast = max(forecast, 0)

        let growthStatusKey: String
        if growth > 0 {
            growthStatusKey = "growth"
        } else if growth < 0 {
            growthStatusKey = "decline"
        } else {
            growthStatusKey = "steady"
        }
        let growthStatusLocalized = NSLocalizedString("trend_\(growthStatusKey)", value: growthStatusKey.capitalized, comment: "")

        let roundedForecast = finalForecast.rounded(.toNearestOrAwayFromZero)
        let auditEntryFormat = NSLocalizedString("audit_nextMonthForecast", value: "Next month forecast: %.2f (%@)", comment: "")
        await addAudit(String(format: auditEntryFormat, roundedForecast, growthStatusLocalized))
        updateBadgesAndRisk(growth: growth, forecast: finalForecast)
        await notifyForecastUpdate(amount: finalForecast)

        await logAuditEvent(name: "forecastNextMonthRevenue", parameters: [
            "forecast": roundedForecast,
            "growth": growth,
            "trend": growthStatusKey
        ])

        return finalForecast
    }

    public func forecastRevenue(charges: [Charge], months: Int = 3) async -> [(month: Date, projectedRevenue: Double)] {
        guard !charges.isEmpty, months > 0 else {
            await addAudit(NSLocalizedString("audit_noDataMultiMonth", value: "No data for multi-month forecast.", comment: ""))
            updateBadgesAndRisk(growth: 0, forecast: 0)
            await logAuditEvent(name: "forecastRevenue_noData", parameters: ["months": months])
            return []
        }
        let calendar = Calendar.current
        let now = Date()
        var monthTotals: [Double] = []

        for i in 1...6 {
            guard let monthStart = calendar.date(byAdding: .month, value: -i, to: now),
                  let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart) else { continue }
            let monthCharges = charges.filter { $0.date >= monthStart && $0.date < nextMonthStart }
            monthTotals.append(monthCharges.reduce(0) { $0 + $1.amount })
        }
        let avgMonthly: Double = monthTotals.isEmpty ? 0 : monthTotals.reduce(0, +) / Double(monthTotals.count)
        var forecasts: [(Date, Double)] = []

        for i in 1...months {
            if let nextMonth = calendar.date(byAdding: .month, value: i, to: now) {
                forecasts.append((nextMonth, avgMonthly))
            }
        }
        let roundedAvg = avgMonthly.rounded(.toNearestOrAwayFromZero)
        let auditEntryFormat = NSLocalizedString("audit_forecastMonths", value: "Forecasted %d months at avg %.2f.", comment: "")
        await addAudit(String(format: auditEntryFormat, months, roundedAvg))
        updateBadgesAndRisk(growth: 0, forecast: avgMonthly)
        await notifyForecastUpdate(amount: avgMonthly)

        await logAuditEvent(name: "forecastRevenue", parameters: [
            "months": months,
            "avgMonthly": roundedAvg
        ])

        return forecasts
    }

    public func forecastFullYearRevenue(charges: [Charge]) async -> Double {
        let calendar = Calendar.current
        let now = Date()
        guard let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) else {
            await addAudit(NSLocalizedString("audit_yearStartNotFound", value: "Year start not found.", comment: ""))
            updateBadgesAndRisk(growth: 0, forecast: 0)
            await logAuditEvent(name: "forecastFullYearRevenue_yearStartNotFound", parameters: nil)
            return 0
        }
        let ytdCharges = charges.filter { $0.date >= yearStart && $0.date <= now }
        let totalYTD = ytdCharges.reduce(0) { $0 + $1.amount }
        let daysSoFar = calendar.dateComponents([.day], from: yearStart, to: now).day ?? 1
        let totalDays = calendar.range(of: .day, in: .year, for: now)?.count ?? 365
        let projected = (Double(totalYTD) / Double(daysSoFar)) * Double(totalDays)
        let roundedProjected = projected.rounded(.toNearestOrAwayFromZero)
        let auditEntryFormat = NSLocalizedString("audit_fullYearProjected", value: "Full year revenue projected: %.2f.", comment: "")
        await addAudit(String(format: auditEntryFormat, roundedProjected))
        updateBadgesAndRisk(growth: 0, forecast: projected)
        await notifyForecastUpdate(amount: projected)

        await logAuditEvent(name: "forecastFullYearRevenue", parameters: [
            "projected": roundedProjected,
            "daysSoFar": daysSoFar,
            "totalDays": totalDays
        ])

        return projected
    }

    public func forecastGoalProgress(charges: [Charge], monthlyGoal: Double) async -> (forecast: Double, progress: Double) {
        let calendar = Calendar.current
        let now = Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            await addAudit(NSLocalizedString("audit_monthStartNotFound", value: "Month start not found.", comment: ""))
            updateBadgesAndRisk(growth: 0, forecast: 0)
            await logAuditEvent(name: "forecastGoalProgress_monthStartNotFound", parameters: nil)
            return (0, 0)
        }
        let monthCharges = charges.filter { $0.date >= monthStart && $0.date <= now }
        let totalSoFar = monthCharges.reduce(0) { $0 + $1.amount }
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let daysSoFar = calendar.dateComponents([.day], from: monthStart, to: now).day ?? 1
        let projected = (Double(totalSoFar) / Double(daysSoFar)) * Double(daysInMonth)
        let progress = monthlyGoal > 0 ? projected / monthlyGoal : 0
        let cappedProgress = min(progress, 1.0)
        let roundedProjected = projected.rounded(.toNearestOrAwayFromZero)
        let progressPercent = Int(cappedProgress * 100)
        let auditEntryFormat = NSLocalizedString("audit_forecastGoalProgress", value: "Forecast goal progress: %.2f (%d%%).", comment: "")
        await addAudit(String(format: auditEntryFormat, roundedProjected, progressPercent))
        updateBadgesAndRisk(growth: 0, forecast: projected)
        await notifyForecastUpdate(amount: projected)

        await logAuditEvent(name: "forecastGoalProgress", parameters: [
            "projected": roundedProjected,
            "progressPercent": progressPercent,
            "monthlyGoal": monthlyGoal
        ])

        return (projected, cappedProgress)
    }

    public func uiSummary(for charges: [Charge]) async -> String {
        let forecast = await forecastNextMonthRevenue(charges: charges)
        let yearlyProjection = await forecastFullYearRevenue(charges: charges)

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale.current

        let forecastStr = formatter.string(from: NSNumber(value: forecast)) ?? formatter.string(from: 0) ?? "$0"
        let yearlyStr = formatter.string(from: NSNumber(value: yearlyProjection)) ?? formatter.string(from: 0) ?? "$0"
        let badgeTokenString = forecastBadgeTokens.last.flatMap { ForecastBadge(rawValue: $0)?.localizedDescription } ?? NSLocalizedString("badge_unknown", value: "Unknown", comment: "")

        let summaryFormat = NSLocalizedString("uiSummary_format", value: "Forecast: %@ [%@]\nYearly: %@", comment: "")
        let summary = String(format: summaryFormat, forecastStr, badgeTokenString, yearlyStr)

        await logAuditEvent(name: "uiSummary", parameters: [
            "forecast": forecastStr,
            "yearly": yearlyStr,
            "badge": badgeTokenString
        ])

        return summary
    }

    // MARK: - Trust Center Audit/Event Helper

    private func logAuditEvent(name: String, parameters: [String: Any]? = nil) async {
        let escalate = name.lowercased().contains("danger") || name.lowercased().contains("critical") || name.lowercased().contains("delete")
            || (parameters?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)
        await analyticsLogger.logEvent(
            name: name,
            parameters: parameters,
            role: RevenueForecastAuditContext.role,
            staffID: RevenueForecastAuditContext.staffID,
            context: RevenueForecastAuditContext.context,
            escalate: escalate
        )
        auditEventBuffer.append((Date(), name, parameters, RevenueForecastAuditContext.role, RevenueForecastAuditContext.staffID, RevenueForecastAuditContext.context, escalate))
        if auditEventBuffer.count > auditEventBufferMax {
            auditEventBuffer.removeFirst(auditEventBuffer.count - auditEventBufferMax)
        }
    }

    public func diagnosticsAuditTrail() -> [String] {
        auditEventBuffer.map { evt in
            let dateStr = ISO8601DateFormatter().string(from: evt.timestamp)
            let paramStr = evt.parameters?.map { "\($0): \($1)" }.joined(separator: ", ") ?? ""
            let role = evt.role ?? "-"
            let staffID = evt.staffID ?? "-"
            let context = evt.context ?? "-"
            let escalate = evt.escalate ? "YES" : "NO"
            return "[\(dateStr)] \(evt.name) \(paramStr) | role:\(role) staffID:\(staffID) context:\(context) escalate:\(escalate)"
        }
    }

    // MARK: - Audit/BI Helpers

    public func addAudit(_ entry: String) async {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        let auditEntry = "[\(ts)] \(entry)"
        auditLog.append(auditEntry)
        if auditLog.count > 1000 {
            auditLog.removeFirst()
        }
    }

    public func updateBadgesAndRisk(growth: Double, forecast: Double) {
        forecastBadgeTokens.removeAll()
        if growth > 0.04 {
            forecastBadgeTokens.append(ForecastBadge.growth.rawValue)
            trendDirection = NSLocalizedString("trend_growth", value: "growth", comment: "")
        } else if growth < -0.04 {
            forecastBadgeTokens.append(ForecastBadge.decline.rawValue)
            trendDirection = NSLocalizedString("trend_decline", value: "decline", comment: "")
        } else {
            forecastBadgeTokens.append(ForecastBadge.steady.rawValue)
            trendDirection = NSLocalizedString("trend_steady", value: "steady", comment: "")
        }
        if forecast < 500 {
            forecastBadgeTokens.append(ForecastBadge.atRisk.rawValue)
            riskScore = 3
        } else if forecast > 10000 {
            forecastBadgeTokens.append(ForecastBadge.onTarget.rawValue)
            riskScore = 0
        } else {
            riskScore = 1
        }
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
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(export)).flatMap { String(data: $0, encoding: .utf8) }
    }

    // MARK: - SwiftUI/Preview/Test Helpers

    public func demoForecasts(for months: Int = 6) -> [(month: Date, projectedRevenue: Double)] {
        var fakeCharges: [Charge] = []
        let calendar = Calendar.current
        let baseDate = Date()
        for i in 1...12 {
            if let date = calendar.date(byAdding: .month, value: -i, to: baseDate) {
                let amount = Double(Int.random(in: 2000...6000))
                fakeCharges.append(Charge(date: date, amount: amount))
            }
        }
        return Task { await forecastRevenue(charges: fakeCharges, months: months) }.value
    }

    public func clearAuditLog() {
        auditLog.removeAll()
    }

    // MARK: - Internal Notification

    private func notifyForecastUpdate(amount: Double) async {
        onForecastUpdate?(amount)
        await MainActor.run {
            NotificationCenter.default.post(name: .RevenueForecastUpdated, object: self, userInfo: ["amount": amount])
        }
    }

    // MARK: - At-Risk/High-Growth Filters (for dashboards)

    public func atRiskPeriods() -> [String] {
        auditLog.filter { $0.localizedCaseInsensitiveContains(ForecastBadge.atRisk.rawValue) }
    }
    public func highGrowthPeriods() -> [String] {
        auditLog.filter { $0.localizedCaseInsensitiveContains(ForecastBadge.growth.rawValue) }
    }

    // MARK: - Codable Support

    enum CodingKeys: CodingKey {
        case auditLog, forecastBadgeTokens, riskScore, trendDirection
    }

    public convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        auditLog = try container.decode([String].self, forKey: .auditLog)
        forecastBadgeTokens = try container.decode([String].self, forKey: .forecastBadgeTokens)
        riskScore = try container.decode(Int.self, forKey: .riskScore)
        trendDirection = try container.decode(String.self, forKey: .trendDirection)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(auditLog, forKey: .auditLog)
        try container.encode(forecastBadgeTokens, forKey: .forecastBadgeTokens)
        try container.encode(riskScore, forKey: .riskScore)
        try container.encode(trendDirection, forKey: .trendDirection)
    }

    // MARK: - Private Helpers

    private func localizedTrendDirection() -> String {
        switch trendDirection.lowercased() {
        case "growth":
            return NSLocalizedString("trend_growth", value: "Growth", comment: "")
        case "decline":
            return NSLocalizedString("trend_decline", value: "Decline", comment: "")
        case "steady":
            return NSLocalizedString("trend_steady", value: "Steady", comment: "")
        default:
            return trendDirection
        }
    }
}

// MARK: - Notification.Name Extension

public extension Notification.Name {
    static let RevenueForecastUpdated = Notification.Name("RevenueForecastUpdated")
}

// MARK: - Charge Model (Minimal for Demo)
public struct Charge: Codable {
    public var date: Date
    public var amount: Double
    public init(date: Date, amount: Double) { self.date = date; self.amount = amount }
}

// MARK: - Unit Test Stubs (Example Usage)

#if DEBUG
import XCTest

public final class RevenueForecastEngineTests: XCTestCase {
    var engine: RevenueForecastEngine!

    override public func setUp() {
        super.setUp()
        engine = RevenueForecastEngine()
    }

    override public func tearDown() {
        engine = nil
        super.tearDown()
    }

    public func testForecastNextMonthRevenue() async {
        let charges = [
            Charge(date: Date().addingTimeInterval(-86400 * 40), amount: 1000),
            Charge(date: Date().addingTimeInterval(-86400 * 10), amount: 1500)
        ]
        let forecast = await engine.forecastNextMonthRevenue(charges: charges)
        XCTAssertGreaterThanOrEqual(forecast, 0)
    }

    public func testForecastRevenue() async {
        let charges = [
            Charge(date: Date().addingTimeInterval(-86400 * 90), amount: 2000),
            Charge(date: Date().addingTimeInterval(-86400 * 60), amount: 2500),
            Charge(date: Date().addingTimeInterval(-86400 * 30), amount: 3000)
        ]
        let forecasts = await engine.forecastRevenue(charges: charges, months: 3)
        XCTAssertEqual(forecasts.count, 3)
    }

    public func testForecastFullYearRevenue() async {
        let charges = [
            Charge(date: Date().addingTimeInterval(-86400 * 200), amount: 5000),
            Charge(date: Date().addingTimeInterval(-86400 * 100), amount: 7000)
        ]
        let projection = await engine.forecastFullYearRevenue(charges: charges)
        XCTAssertGreaterThanOrEqual(projection, 0)
    }

    public func testForecastGoalProgress() async {
        let charges = [
            Charge(date: Date().addingTimeInterval(-86400 * 5), amount: 1000),
            Charge(date: Date().addingTimeInterval(-86400 * 2), amount: 1500)
        ]
        let (forecast, progress) = await engine.forecastGoalProgress(charges: charges, monthlyGoal: 5000)
        XCTAssertGreaterThanOrEqual(forecast, 0)
        XCTAssert(progress >= 0 && progress <= 1)
    }

    public func testClearAuditLog() {
        engine.auditLog.append("Test entry")
        engine.clearAuditLog()
        XCTAssertTrue(engine.auditLog.isEmpty)
    }
}
#endif
