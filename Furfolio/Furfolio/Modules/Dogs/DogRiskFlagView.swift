//
//  DogRiskFlagView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Extensible Risk Flag View
//

import SwiftUI

enum RiskLevel: String, CaseIterable, Codable, Identifiable {
    case low, medium, high

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .red
        }
    }

    var iconName: String {
        switch self {
        case .low: return "checkmark.seal.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .high: return "flame.fill"
        }
    }

    var label: String {
        switch self {
        case .low: return "Low Risk"
        case .medium: return "Medium Risk"
        case .high: return "High Risk"
        }
    }
}

struct DogRiskFlagView: View {
    let riskLevel: RiskLevel
    let reason: String

    // Audit on render
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: riskLevel.iconName)
                .foregroundColor(riskLevel.color)
                .accessibilityHidden(true)
                .accessibilityIdentifier("DogRiskFlagView-Icon")

            VStack(alignment: .leading, spacing: 2) {
                Text(riskLevel.label)
                    .font(.headline)
                    .foregroundColor(riskLevel.color)
                    .accessibilityLabel("Risk level: \(riskLevel.label)")
                    .accessibilityIdentifier("DogRiskFlagView-Label")
                Text(reason)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Reason: \(reason)")
                    .accessibilityIdentifier("DogRiskFlagView-Reason")
            }
        }
        .padding(10)
        .background(riskLevel.color.opacity(0.18))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(riskLevel.label). \(reason)")
        .accessibilityIdentifier("DogRiskFlagView-Container")
        .onAppear {
            DogRiskFlagAudit.record(riskLevel: riskLevel, reason: reason)
        }
    }
}

// MARK: - Audit/Event Logging

fileprivate struct DogRiskFlagAuditEvent: Codable {
    let timestamp: Date
    let riskLevel: String
    let reason: String
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[DogRiskFlag] \(riskLevel): \(reason) at \(dateStr)"
    }
}
fileprivate final class DogRiskFlagAudit {
    static private(set) var log: [DogRiskFlagAuditEvent] = []
    static func record(riskLevel: RiskLevel, reason: String) {
        let event = DogRiskFlagAuditEvent(
            timestamp: Date(),
            riskLevel: riskLevel.label,
            reason: reason
        )
        log.append(event)
        if log.count > 30 { log.removeFirst() }
    }
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func recentSummaries(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}

// MARK: - Audit/Admin Accessors

public enum DogRiskFlagAuditAdmin {
    public static func lastSummary() -> String { DogRiskFlagAudit.log.last?.summary ?? "No risk flag events yet." }
    public static func lastJSON() -> String? { DogRiskFlagAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] { DogRiskFlagAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview

#if DEBUG
struct DogRiskFlagView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 22) {
            DogRiskFlagView(riskLevel: .low, reason: "No known issues")
            DogRiskFlagView(riskLevel: .medium, reason: "Sensitive skin")
            DogRiskFlagView(riskLevel: .high, reason: "Aggressive behavior")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
