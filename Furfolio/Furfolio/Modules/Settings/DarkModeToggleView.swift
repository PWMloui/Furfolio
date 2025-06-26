//
//  DarkModeToggleView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Dark Mode Toggle
//

import SwiftUI

struct DarkModeToggleView: View {
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @State private var animateBadge: Bool = false
    @State private var appearedOnce = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill((isDarkMode ? Color.yellow : Color.orange).opacity(0.15))
                    .frame(width: 38, height: 38)
                    .scaleEffect(animateBadge ? 1.11 : 1.0)
                    .animation(.spring(response: 0.33, dampingFraction: 0.5), value: animateBadge)
                Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                    .font(.title2)
                    .foregroundStyle(isDarkMode ? .yellow : .orange)
                    .accessibilityIdentifier("DarkModeToggleView-Icon")
            }
            Toggle(isOn: $isDarkMode) {
                Text(isDarkMode ? NSLocalizedString("Dark Mode", comment: "") : NSLocalizedString("Light Mode", comment: ""))
                    .font(.headline)
                    .accessibilityIdentifier("DarkModeToggleView-Label")
            }
            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
            .accessibilityIdentifier("DarkModeToggleView-Toggle")
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isDarkMode ? NSLocalizedString("Dark mode enabled", comment: "") : NSLocalizedString("Light mode enabled", comment: ""))
        .accessibilityIdentifier("DarkModeToggleView-Root")
        .onAppear {
            if !appearedOnce {
                DarkModeToggleAudit.record(action: "Appear", enabled: isDarkMode)
                appearedOnce = true
            }
        }
        .onChange(of: isDarkMode) { newValue in
            animateBadge = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            updateAppearance(dark: newValue)
            DarkModeToggleAudit.record(action: "Toggle", enabled: newValue)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.66) { animateBadge = false }
        }
    }

    private func updateAppearance(dark: Bool) {
        // New iOS 18 AppKit/SwiftUI scene phase for global UI
        // For older iOS: use UIWindow or AppDelegate tricks if needed.
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.overrideUserInterfaceStyle = dark ? .dark : .light
    }
}

// --- Audit/Event Logging ---

fileprivate struct DarkModeToggleAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let enabled: Bool
    var summary: String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return "[DarkModeToggleView] \(action): \(enabled ? "Dark" : "Light") at \(df.string(from: timestamp))"
    }
}
fileprivate final class DarkModeToggleAudit {
    static private(set) var log: [DarkModeToggleAuditEvent] = []
    static func record(action: String, enabled: Bool) {
        let event = DarkModeToggleAuditEvent(timestamp: Date(), action: action, enabled: enabled)
        log.append(event)
        if log.count > 24 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 6) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum DarkModeToggleAuditAdmin {
    public static func lastSummary() -> String { DarkModeToggleAudit.log.last?.summary ?? "No events yet." }
    public static func recentEvents(limit: Int = 6) -> [String] { DarkModeToggleAudit.recentSummaries(limit: limit) }
}

#Preview {
    DarkModeToggleView()
}
