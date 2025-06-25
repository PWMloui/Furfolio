//
//  DashboardTipBanner.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Tip Banner
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct DashboardTipBannerAuditEvent: Codable {
    let timestamp: Date
    let message: String
    let action: String // "appear" or "dismiss"
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[\(action.capitalized)] Tip: \(message) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class DashboardTipBannerAudit {
    static private(set) var log: [DashboardTipBannerAuditEvent] = []

    static func record(
        message: String,
        action: String,
        tags: [String] = ["tipBanner"]
    ) {
        let event = DashboardTipBannerAuditEvent(
            timestamp: Date(),
            message: message,
            action: action,
            tags: tags
        )
        log.append(event)
        if log.count > 30 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No tip banner events recorded."
    }
}

// MARK: - DashboardTipBanner

struct DashboardTipBanner: View {
    @Binding var isVisible: Bool
    let message: String

    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                    .accessibilityHidden(true)
                    .accessibilityIdentifier("DashboardTipBanner-Icon")

                Text(message)
                    .font(.body)
                    .foregroundColor(.primary)
                    .accessibilityIdentifier("DashboardTipBanner-Message")

                Spacer()

                Button(action: {
                    withAnimation {
                        isVisible = false
                        DashboardTipBannerAudit.record(
                            message: message,
                            action: "dismiss",
                            tags: ["dismiss", "tip"]
                        )
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .padding(4)
                        .background(Color(UIColor.tertiarySystemFill))
                        .clipShape(Circle())
                        .accessibilityLabel("Dismiss tip")
                        .accessibilityIdentifier("DashboardTipBanner-DismissButton")
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
            )
            .padding(.horizontal)
            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale),
                                    removal: .opacity))
            .animation(.easeInOut(duration: 0.3), value: isVisible)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Tip: \(message)")
            .accessibilityIdentifier("DashboardTipBanner-Container")
            .onAppear {
                DashboardTipBannerAudit.record(
                    message: message,
                    action: "appear",
                    tags: ["show", "tip"]
                )
            }
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum DashboardTipBannerAuditAdmin {
    public static var lastSummary: String { DashboardTipBannerAudit.accessibilitySummary }
    public static var lastJSON: String? { DashboardTipBannerAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        DashboardTipBannerAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

#if DEBUG
struct DashboardTipBanner_Previews: PreviewProvider {
    @State static var visible = true
    static var previews: some View {
        VStack {
            DashboardTipBanner(isVisible: $visible, message: "Remember to follow up with customers after their appointment.")
            Spacer()
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
