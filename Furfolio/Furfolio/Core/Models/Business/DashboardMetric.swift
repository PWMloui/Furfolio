//
//  DashboardMetric.swift
//  Furfolio
//

import Foundation
import SwiftUI

// MARK: - Audit Logging Protocol and Actor

/// Protocol defining async audit logging capabilities.
protocol AuditLogger {
    /// Logs an audit event with a message, category, valueType, and metadata.
    func logEvent(message: String, category: DashboardMetric.Category, valueType: DashboardMetric.ValueType, metadata: [String: String]?)
    
    /// Returns recent audit events asynchronously.
    func recentEvents() async -> [String]
}

/// Actor to safely handle audit logging with concurrency protection.
actor DashboardMetricAuditLogger: AuditLogger {
    private var events: [String] = []
    private let maxEvents = 100
    
    /// Logs an audit event with contextual metadata.
    func logEvent(message: String, category: DashboardMetric.Category, valueType: DashboardMetric.ValueType, metadata: [String: String]? = nil) {
        var logEntry = "[\(Date())] \(message) | Category: \(category.rawValue) | ValueType: \(valueType) "
        if let metadata = metadata {
            let metaString = metadata.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            logEntry += "| Metadata: [\(metaString)]"
        }
        events.append(logEntry)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }
    
    /// Returns the most recent audit events.
    func recentEvents() async -> [String] {
        return events
    }
}

// Shared audit logger instance for DashboardMetric.
private let sharedAuditLogger = DashboardMetricAuditLogger()

// MARK: - DashboardMetric (Enhanced Version with Audit and Accessibility)

/// Represents a dashboard metric with audit logging, accessibility, and permission support.
struct DashboardMetric: Identifiable, Hashable, Equatable {
    // MARK: - Enums
    
    enum ValueType {
        case string, currency, number, percent, duration
    }
    
    enum Category: String, CaseIterable, Codable {
        case financial, appointment, retention, operations, inventory, staff, custom
    }
    
    enum IconToken: String {
        case revenue = "dollarsign.circle.fill"
        case appointment = "calendar.badge.clock"
        case retention = "arrow.triangle.2.circlepath"
        // Add more tokens as needed
    }
    
    enum ColorToken {
        case accent, success, info, warning, error, custom(Color)
        var color: Color {
            switch self {
            case .accent: return AppColors.accent
            case .success: return AppColors.success
            case .info: return AppColors.info
            case .warning: return AppColors.warning
            case .error: return AppColors.error
            case .custom(let color): return color
            }
        }
    }
    
    // MARK: - Permissions
    
    enum PermissionRole {
        case admin, staff, owner, any
    }
    
    // MARK: - Core Properties
    
    let id: UUID
    let title: LocalizedStringKey
    let value: String
    let valueType: ValueType
    let icon: IconToken
    let color: ColorToken
    let subtitle: LocalizedStringKey?
    let category: Category
    let lastUpdated: Date?
    var onTap: (() -> Void)?
    
    // Permission and sensitivity flags integrated with audit
    let requiredRole: PermissionRole
    let isSensitive: Bool
    
    // MARK: - Accessibility
    
    /// Dynamic localized accessibility label based on valueType and sensitivity.
    var accessibilityLabel: String {
        if let customLabel = _accessibilityLabel {
            return customLabel
        }
        // Default localized label based on valueType and sensitivity
        let baseLabel = NSLocalizedString(titleKey, comment: "")
        let valueDescription = NSLocalizedString(value, comment: "")
        if isSensitive {
            return String(format: NSLocalizedString("Sensitive metric: %@, value hidden", comment: ""), baseLabel)
        } else {
            return String(format: NSLocalizedString("Metric: %@, value: %@", comment: ""), baseLabel, valueDescription)
        }
    }
    
    /// Dynamic localized accessibility hint.
    var accessibilityHint: String {
        if let customHint = _accessibilityHint {
            return customHint
        }
        return NSLocalizedString("Double tap to interact with this metric", comment: "")
    }
    
    /// Dynamic accessibility traits based on sensitivity and highlight.
    var accessibilityTraits: AccessibilityTraits {
        var traits: AccessibilityTraits = .isStaticText
        if isHighlighted {
            traits.insert(.isSelected)
        }
        if isSensitive {
            traits.insert(.isSummaryElement)
        }
        return traits
    }
    
    // MARK: - Internal backing for optional accessibility properties
    
    private var _accessibilityLabel: String?
    private var _accessibilityHint: String?
    private var _accessibilityValue: String?

    /// Dynamic accessibility value based on sensitivity and custom input.
    var accessibilityValueDescription: String {
        if let customValue = _accessibilityValue {
            return customValue
        }
        if isSensitive {
            return NSLocalizedString("Hidden", comment: "Hidden sensitive value")
        }
        return value
    }
    
    // MARK: - Highlighting
    
    var isHighlighted: Bool = false
    
    // MARK: - Audit Tag
    
    /// A unique audit tag for this metric used in audit events.
    var auditTag: String {
        "DashboardMetric-\(id.uuidString.prefix(8))"
    }
    
    // MARK: - Initializer
    
    /// Initializes a new DashboardMetric instance and logs creation asynchronously.
    init(
        id: UUID = UUID(),
        title: LocalizedStringKey,
        value: String,
        valueType: ValueType = .string,
        icon: IconToken,
        color: ColorToken = .accent,
        subtitle: LocalizedStringKey? = nil,
        category: Category = .custom,
        lastUpdated: Date? = nil,
        onTap: (() -> Void)? = nil,
        requiredRole: PermissionRole = .any,
        isSensitive: Bool = false,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        accessibilityValue: String? = nil,
        accessibilityTraits: AccessibilityTraits = .isStaticText,
        isHighlighted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.valueType = valueType
        self.icon = icon
        self.color = color
        self.subtitle = subtitle
        self.category = category
        self.lastUpdated = lastUpdated
        self.onTap = onTap
        self.requiredRole = requiredRole
        self.isSensitive = isSensitive
        self._accessibilityLabel = accessibilityLabel
        self._accessibilityHint = accessibilityHint
        self._accessibilityValue = accessibilityValue
        self.accessibilityTraits = accessibilityTraits
        self.isHighlighted = isHighlighted
        
        // Fire and forget audit event for creation
        Task {
            await sharedAuditLogger.logEvent(
                message: "Created metric \(auditTag)",
                category: category,
                valueType: valueType,
                metadata: ["title": "\(titleKey)", "sensitive": "\(isSensitive)"]
            )
        }
    }
    
    // MARK: - Equatable & Hashable
    
    static func == (lhs: DashboardMetric, rhs: DashboardMetric) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Audit Logging Methods
    
    /// Logs a tap event asynchronously for this metric.
    func logTapEvent() async {
        await sharedAuditLogger.logEvent(
            message: "Tapped metric \(auditTag)",
            category: category,
            valueType: valueType,
            metadata: ["title": "\(titleKey)", "sensitive": "\(isSensitive)"]
        )
    }
    
    /// Retrieves recent audit events asynchronously.
    static func fetchRecentAuditEvents() async -> [String] {
        await sharedAuditLogger.recentEvents()
    }
    
    // MARK: - Convenience
    
    /// Extracts string key from LocalizedStringKey for audit and accessibility.
    private var titleKey: String {
        // Attempt to extract string from LocalizedStringKey for logging
        Mirror(reflecting: title).children.first(where: { $0.label == "key" })?.value as? String ?? "Unknown Title"
    }
    
    // MARK: - Static Examples
    
    static var sampleRevenue: DashboardMetric {
        DashboardMetric(
            title: "Total Revenue",
            value: "$2,750",
            valueType: .currency,
            icon: .revenue,
            color: .success,
            subtitle: "Month to date",
            category: .financial,
            lastUpdated: Date(),
            isHighlighted: true,
            accessibilityLabel: "Total revenue for the month"
        )
    }
    
    static var sampleAppointments: DashboardMetric {
        DashboardMetric(
            title: "Appointments",
            value: "14",
            valueType: .number,
            icon: .appointment,
            color: .accent,
            subtitle: "This week",
            category: .appointment,
            lastUpdated: Date(),
            accessibilityLabel: "Number of appointments this week"
        )
    }
    
    static var sampleRetention: DashboardMetric {
        DashboardMetric(
            title: "Retention Rate",
            value: "85%",
            valueType: .percent,
            icon: .retention,
            color: .info,
            subtitle: "Returning clients",
            category: .retention,
            lastUpdated: Date(),
            accessibilityLabel: "Client retention rate"
        )
    }
    
    static func customMetric(
        id: UUID = UUID(),
        title: LocalizedStringKey,
        value: String,
        valueType: ValueType,
        icon: IconToken,
        color: ColorToken,
        subtitle: LocalizedStringKey? = nil,
        category: Category = .custom,
        lastUpdated: Date? = nil
    ) -> DashboardMetric {
        DashboardMetric(
            id: id, title: title, value: value, valueType: valueType,
            icon: icon, color: color, subtitle: subtitle,
            category: category, lastUpdated: lastUpdated
        )
    }
}

// MARK: - SwiftUI View Modifiers for Accessibility and Audit

extension View {
    /// Applies dynamic accessibility traits based on DashboardMetric properties.
    func dashboardMetricAccessibility(_ metric: DashboardMetric) -> some View {
        self.accessibilityLabel(Text(metric.accessibilityLabel))
            .accessibilityValue(Text(metric.accessibilityValueDescription))
            .accessibilityHint(Text(metric.accessibilityHint))
            .accessibilityAddTraits(metric.accessibilityTraits)
    }
    
    /// Adds an audit log tap handler asynchronously.
    func onDashboardMetricTap(_ metric: DashboardMetric) -> some View {
        self.onTapGesture {
            Task {
                await metric.logTapEvent()
                metric.onTap?()
            }
        }
    }
}

// MARK: - PreviewProvider with Audit Logging Demonstration

#if DEBUG
struct DashboardMetric_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Sample Revenue Metric")
                .dashboardMetricAccessibility(DashboardMetric.sampleRevenue)
                .onDashboardMetricTap(DashboardMetric.sampleRevenue)
            
            Text("Sample Appointments Metric")
                .dashboardMetricAccessibility(DashboardMetric.sampleAppointments)
                .onDashboardMetricTap(DashboardMetric.sampleAppointments)
            
            Text("Sample Retention Metric")
                .dashboardMetricAccessibility(DashboardMetric.sampleRetention)
                .onDashboardMetricTap(DashboardMetric.sampleRetention)
        }
        .padding()
        .onAppear {
            Task {
                // Example: Fetch and print recent audit events for diagnostics
                let events = await DashboardMetric.fetchRecentAuditEvents()
                for event in events {
                    print(event)
                }
            }
        }
    }
}
#endif

// MARK: - Unit Test Stubs (for later implementation)

#if DEBUG
import XCTest

final class DashboardMetricTests: XCTestCase {
    func testAuditLoggingConcurrency() async {
        let metric = DashboardMetric.sampleRevenue
        await metric.logTapEvent()
        let events = await DashboardMetric.fetchRecentAuditEvents()
        XCTAssertTrue(events.contains(where: { $0.contains(metric.auditTag) }))
    }
    
    func testAccessibilityLabels() {
        let sensitiveMetric = DashboardMetric(
            title: "Sensitive Data",
            value: "Secret",
            valueType: .string,
            icon: .revenue,
            isSensitive: true
        )
        XCTAssertTrue(sensitiveMetric.accessibilityLabel.contains("Sensitive"))
    }
    
    func testPermissionRoleIntegration() {
        let adminMetric = DashboardMetric(
            title: "Admin Only",
            value: "42",
            valueType: .number,
            icon: .appointment,
            requiredRole: .admin
        )
        XCTAssertEqual(adminMetric.requiredRole, .admin)
    }
    
    func testAuditEventBufferSize() async {
        // Log more than maxEvents to test buffer capping
        for _ in 0..<150 {
            await sharedAuditLogger.logEvent(message: "Test event", category: .custom, valueType: .string, metadata: nil)
        }
        let events = await DashboardMetric.fetchRecentAuditEvents()
        XCTAssertLessThanOrEqual(events.count, 100)
    }
}
#endif
