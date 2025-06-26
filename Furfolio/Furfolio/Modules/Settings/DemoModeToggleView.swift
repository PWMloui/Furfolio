//
//  DemoModeToggleView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Demo Mode Toggle
//

import SwiftUI

struct DemoModeToggleView: View {
    @AppStorage("isDemoMode") private var isDemoMode: Bool = false
    @State private var animateBadge: Bool = false
    @State private var appearedOnce: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill((isDemoMode ? Color.blue : Color.gray).opacity(0.13))
                    .frame(width: 38, height: 38)
                    .scaleEffect(animateBadge ? 1.13 : 1.0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.52), value: animateBadge)
                Image(systemName: isDemoMode ? "play.rectangle.fill" : "rectangle.slash")
                    .font(.title2)
                    .foregroundStyle(isDemoMode ? .blue : .secondary)
                    .accessibilityIdentifier("DemoModeToggleView-Icon")
            }
            Toggle(isOn: $isDemoMode) {
                Text(isDemoMode ? NSLocalizedString("Demo Mode On", comment: "") : NSLocalizedString("Demo Mode Off", comment: ""))
                    .font(.headline)
                    .accessibilityIdentifier("DemoModeToggleView-Label")
            }
            .toggleStyle(SwitchToggleStyle(tint: .blue))
            .accessibilityIdentifier("DemoModeToggleView-Toggle")
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isDemoMode ? NSLocalizedString("Demo mode enabled", comment: "") : NSLocalizedString("Demo mode disabled", comment: ""))
        .accessibilityIdentifier("DemoModeToggleView-Root")
        .onAppear {
            if !appearedOnce {
                DemoModeToggleAudit.record(action: "Appear", enabled: isDemoMode)
                appearedOnce = true
            }
        }
        .onChange(of: isDemoMode) { newValue in
            animateBadge = true
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            updateDemoMode(demo: newValue)
            DemoModeToggleAudit.record(action: "Toggle", enabled: newValue)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { animateBadge = false }
        }
    }

    private func updateDemoMode(demo: Bool) {
        // Place your real demo logic here (update AppState, send notification, etc)
        // Example: AppState.shared.isDemoMode = demo
        // NotificationCenter.default.post(name: .didToggleDemoMode, object: demo)
    }
}

// --- Audit/Event Logging ---

fileprivate struct DemoModeToggleAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let enabled: Bool
    var summary: String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return "[DemoModeToggleView] \(action): \(enabled ? "On" : "Off") at \(df.string(from: timestamp))"
    }
}
fileprivate final class DemoModeToggleAudit {
    static private(set) var log: [DemoModeToggleAuditEvent] = []
    static func record(action: String, enabled: Bool) {
        let event = DemoModeToggleAuditEvent(timestamp: Date(), action: action, enabled: enabled)
        log.append(event)
        if log.count > 20 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 6) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum DemoModeToggleAuditAdmin {
    public static func lastSummary() -> String { DemoModeToggleAudit.log.last?.summary ?? "No events yet." }
    public static func recentEvents(limit: Int = 6) -> [String] { DemoModeToggleAudit.recentSummaries(limit: limit) }
}

#Preview {
    DemoModeToggleView()
}
