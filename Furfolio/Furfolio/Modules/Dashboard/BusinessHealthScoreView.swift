//
//  BusinessHealthScoreView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Business Health Score UI
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct BusinessHealthAuditEvent: Codable {
    let timestamp: Date
    let score: Int
    let scoreColor: String
    let statusLabel: String
    let statusMessage: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] Health Score: \(score) (\(statusLabel)), color: \(scoreColor) [\(tags.joined(separator: ","))] at \(dateStr): \(statusMessage)"
    }
}

fileprivate final class BusinessHealthAudit {
    static private(set) var log: [BusinessHealthAuditEvent] = []

    static func record(
        score: Int,
        color: Color,
        label: String,
        message: String,
        tags: [String] = ["businessHealthScore"]
    ) {
        let colorDesc: String
        switch color {
        case .green: colorDesc = "green"
        case .yellow: colorDesc = "yellow"
        case .red: colorDesc = "red"
        default: colorDesc = color.description
        }
        let event = BusinessHealthAuditEvent(
            timestamp: Date(),
            score: score,
            scoreColor: colorDesc,
            statusLabel: label,
            statusMessage: message,
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
        log.last?.accessibilityLabel ?? "No business health score events recorded."
    }
}

// MARK: - BusinessHealthScoreView

struct BusinessHealthScoreView: View {
    let score: Int

    private var scoreColor: Color {
        switch score {
        case 75...100:
            return .green
        case 50..<75:
            return .yellow
        default:
            return .red
        }
    }

    private var healthStatusLabel: String {
        switch score {
        case 75...100:
            return "Excellent"
        case 50..<75:
            return "Moderate"
        default:
            return "Critical"
        }
    }

    private var statusMessage: String {
        switch score {
        case 75...100:
            return "Your business is thriving. Great customer retention and solid growth!"
        case 50..<75:
            return "Your business is stable but could benefit from better appointment frequency or revenue improvements."
        default:
            return "Your business needs attention. Consider retention strategies or re-engagement campaigns."
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Business Health Score")
                .font(.headline)
                .foregroundColor(.primary)

            Text("\(score)")
                .font(.system(size: 72, weight: .bold))
                .foregroundColor(scoreColor)

            Text(healthStatusLabel)
                .font(.subheadline.weight(.medium))
                .foregroundColor(scoreColor)

            Text(statusMessage)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: scoreColor.opacity(0.4), radius: 8, x: 0, y: 3)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Business health score is \(score), rated as \(healthStatusLabel). \(statusMessage)")
        .onAppear {
            BusinessHealthAudit.record(
                score: score,
                color: scoreColor,
                label: healthStatusLabel,
                message: statusMessage
            )
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum BusinessHealthAuditAdmin {
    public static var lastSummary: String { BusinessHealthAudit.accessibilitySummary }
    public static var lastJSON: String? { BusinessHealthAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        BusinessHealthAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

#if DEBUG
struct BusinessHealthScoreView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BusinessHealthScoreView(score: 85)
            BusinessHealthScoreView(score: 65)
            BusinessHealthScoreView(score: 40)
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
#endif
