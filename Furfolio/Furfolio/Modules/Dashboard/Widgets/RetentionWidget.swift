//
//  RetentionWidget.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Retention Widget
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct RetentionWidgetAuditEvent: Codable {
    let timestamp: Date
    let retentionRate: Double?
    let churnRate: Double?
    let loyaltyCount: Int?
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Display] RetentionWidget: retention \(retentionRate?.formatted(.number.precision(.fractionLength(1))) ?? "n/a")%, churn \(churnRate?.formatted(.number.precision(.fractionLength(1))) ?? "n/a")%, loyalty \(loyaltyCount ?? 0) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class RetentionWidgetAudit {
    static private(set) var log: [RetentionWidgetAuditEvent] = []

    static func record(
        retentionRate: Double?,
        churnRate: Double?,
        loyaltyCount: Int?,
        tags: [String] = ["retentionWidget"]
    ) {
        let event = RetentionWidgetAuditEvent(
            timestamp: Date(),
            retentionRate: retentionRate,
            churnRate: churnRate,
            loyaltyCount: loyaltyCount,
            tags: tags
        )
        log.append(event)
        if log.count > 40 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No retention widget events recorded."
    }
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - RetentionWidget

public struct RetentionWidget: View {
    @State private var retentionRate: Double? = nil
    @State private var churnRate: Double? = nil
    @State private var loyaltyCount: Int? = nil
    @State private var isLoading = false
    @State private var fetchError: String? = nil

    public var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                    .accessibilityHidden(true)
                Text("Retention")
                    .font(.headline)
                    .accessibilityIdentifier("RetentionWidget-Title")
            }
            .padding(.bottom, 4)

            if isLoading {
                ProgressView()
                    .accessibilityLabel("Loading retention metrics")
                    .accessibilityIdentifier("RetentionWidget-Loading")
            } else if let error = fetchError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .accessibilityIdentifier("RetentionWidget-Error")
            } else {
                HStack(spacing: 16) {
                    retentionMetricView
                    churnMetricView
                    loyaltyMetricView
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityIdentifier("RetentionWidget-Container")
        .onAppear(perform: fetchMetrics)
    }

    private var retentionMetricView: some View {
        VStack(spacing: 2) {
            Text("Retention")
                .font(.caption2)
                .foregroundColor(.secondary)
                .accessibilityIdentifier("RetentionWidget-RetentionLabel")
            if let rate = retentionRate {
                Text("\(rate, specifier: "%.1f")%")
                    .font(.title2.bold())
                    .foregroundColor(.green)
                    .accessibilityIdentifier("RetentionWidget-RetentionValue")
            } else {
                Text("--")
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("RetentionWidget-RetentionNA")
            }
        }
    }

    private var churnMetricView: some View {
        VStack(spacing: 2) {
            Text("Churn")
                .font(.caption2)
                .foregroundColor(.secondary)
                .accessibilityIdentifier("RetentionWidget-ChurnLabel")
            if let churn = churnRate {
                Text("\(churn, specifier: "%.1f")%")
                    .font(.title2.bold())
                    .foregroundColor(.red)
                    .accessibilityIdentifier("RetentionWidget-ChurnValue")
            } else {
                Text("--")
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("RetentionWidget-ChurnNA")
            }
        }
    }

    private var loyaltyMetricView: some View {
        VStack(spacing: 2) {
            Text("Loyalty")
                .font(.caption2)
                .foregroundColor(.secondary)
                .accessibilityIdentifier("RetentionWidget-LoyaltyLabel")
            if let count = loyaltyCount {
                Text("\(count)")
                    .font(.title2.bold())
                    .foregroundColor(.blue)
                    .accessibilityIdentifier("RetentionWidget-LoyaltyValue")
            } else {
                Text("--")
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("RetentionWidget-LoyaltyNA")
            }
        }
    }

    private func fetchMetrics() {
        isLoading = true
        fetchError = nil
        // Simulate async fetch; replace with real MetricService in production
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Simulate metric fetch (replace with MetricService if needed)
            let retention: Double? = 95.8
            let churn: Double? = 2.3
            let loyalty: Int? = 51

            self.retentionRate = retention
            self.churnRate = churn
            self.loyaltyCount = loyalty
            self.isLoading = false
            RetentionWidgetAudit.record(
                retentionRate: retention,
                churnRate: churn,
                loyaltyCount: loyalty
            )
        }
    }

    private var accessibilitySummary: String {
        if isLoading {
            return "Loading retention metrics"
        } else if let error = fetchError {
            return error
        } else {
            return "Retention rate \(retentionRate?.formatted(.number.precision(.fractionLength(1))) ?? "n/a") percent. Churn \(churnRate?.formatted(.number.precision(.fractionLength(1))) ?? "n/a") percent. Loyalty \(loyaltyCount.map { String($0) } ?? "n/a")."
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum RetentionWidgetAuditAdmin {
    public static var lastSummary: String { RetentionWidgetAudit.accessibilitySummary }
    public static var lastJSON: String? { RetentionWidgetAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        RetentionWidgetAudit.recentEvents(limit: limit)
    }
}

// MARK: - Preview

#if DEBUG
struct RetentionWidget_Previews: PreviewProvider {
    static var previews: some View {
        RetentionWidget()
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif
