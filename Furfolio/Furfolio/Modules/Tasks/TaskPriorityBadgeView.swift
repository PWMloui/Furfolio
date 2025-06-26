//
//  TaskPriorityBadgeView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Priority Badge
//

import SwiftUI

struct TaskPriorityBadgeView: View {
    let priority: Priority

    @State private var animate = false
    @State private var showAuditLog = false
    @State private var appearedOnce = false

    var body: some View {
        Button {
            showAuditLog = true
            TaskPriorityBadgeAudit.record(action: "Tapped", detail: priority.displayName)
        } label: {
            HStack(spacing: 4) {
                icon
                Text(priority.displayName)
            }
            .font(.caption)
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(badgeColor)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
            .scaleEffect(priority == .high && animate ? 1.07 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.58), value: animate)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(priority.displayName) priority badge")
            .accessibilityIdentifier("TaskPriorityBadgeView-\(priority.displayName)")
        }
        .buttonStyle(.plain)
        .onAppear {
            if !appearedOnce {
                appearedOnce = true
                TaskPriorityBadgeAudit.record(action: "Appear", detail: priority.displayName)
                if priority == .high {
                    animate = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { animate = false }
                }
            }
        }
        .sheet(isPresented: $showAuditLog) {
            NavigationStack {
                List {
                    ForEach(TaskPriorityBadgeAuditAdmin.recentEvents(limit: 10), id: \.self) { summary in
                        Text(summary)
                            .font(.caption)
                            .padding(.vertical, 2)
                    }
                }
                .navigationTitle("Priority Badge Audit Log")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Copy") {
                            UIPasteboard.general.string = TaskPriorityBadgeAuditAdmin.recentEvents(limit: 10).joined(separator: "\n")
                        }
                        .accessibilityIdentifier("TaskPriorityBadgeView-CopyAuditLogButton")
                    }
                }
            }
        }
    }

    private var badgeColor: Color {
        switch priority {
        case .low: return Color.blue
        case .medium: return Color.orange
        case .high: return Color.red
        }
    }

    private var icon: some View {
        Group {
            switch priority {
            case .low:
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 13))
            case .medium:
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 13))
            case .high:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13))
            }
        }
        .opacity(0.95)
    }
}

// MARK: - Priority Enum (Preview/demo only)

enum Priority: String, CaseIterable {
    case low, medium, high

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

// MARK: - Audit/Event Logging

fileprivate struct TaskPriorityBadgeAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let detail: String
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[TaskPriorityBadgeView] \(action): \(detail) at \(df.string(from: timestamp))"
    }
}
fileprivate final class TaskPriorityBadgeAudit {
    static private(set) var log: [TaskPriorityBadgeAuditEvent] = []
    static func record(action: String, detail: String) {
        let event = TaskPriorityBadgeAuditEvent(timestamp: Date(), action: action, detail: detail)
        log.append(event)
        if log.count > 18 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 8) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum TaskPriorityBadgeAuditAdmin {
    public static func recentEvents(limit: Int = 8) -> [String] { TaskPriorityBadgeAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        TaskPriorityBadgeView(priority: .low)
        TaskPriorityBadgeView(priority: .medium)
        TaskPriorityBadgeView(priority: .high)
    }
    .padding()
    .background(Color(.systemBackground))
}
