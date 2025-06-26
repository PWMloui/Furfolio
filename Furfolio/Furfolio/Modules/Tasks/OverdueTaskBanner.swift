//
//  OverdueTaskBanner.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Overdue Task Banner
//

import SwiftUI

struct OverdueTaskBanner: View {
    let overdueTasks: [Task]
    var onViewAll: (() -> Void)? = nil

    @State private var isVisible: Bool = true
    @State private var animateBadge: Bool = false
    @State private var appearedOnce: Bool = false
    @State private var showAuditLog: Bool = false

    var body: some View {
        if isVisible && !overdueTasks.isEmpty {
            VStack {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.18))
                            .frame(width: 40, height: 40)
                            .scaleEffect(animateBadge ? 1.12 : 1)
                            .animation(.spring(response: 0.32, dampingFraction: 0.55), value: animateBadge)
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.red)
                            .accessibilityIdentifier("OverdueTaskBanner-Icon")
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("You have overdue tasks!")
                            .font(.headline)
                            .accessibilityIdentifier("OverdueTaskBanner-Headline")
                        if overdueTasks.count == 1 {
                            Text("“\(overdueTasks.first?.title ?? "Task")” is overdue.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .accessibilityIdentifier("OverdueTaskBanner-Subheadline")
                        } else {
                            Text("\(overdueTasks.count) tasks are overdue. Please review them.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .accessibilityIdentifier("OverdueTaskBanner-Subheadline")
                        }
                        if let onViewAll = onViewAll {
                            Button {
                                onViewAll()
                                OverdueTaskBannerAudit.record(action: "ViewAllTapped", detail: "count=\(overdueTasks.count)")
                            } label: {
                                Label("View All", systemImage: "chevron.right.circle")
                                    .font(.subheadline.bold())
                                    .padding(.top, 2)
                            }
                            .accessibilityIdentifier("OverdueTaskBanner-ViewAllButton")
                        }
                    }
                    Spacer()
                    Button {
                        withAnimation {
                            isVisible = false
                        }
                        OverdueTaskBannerAudit.record(action: "Dismissed", detail: "count=\(overdueTasks.count)")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    .accessibilityLabel("Dismiss")
                    .accessibilityIdentifier("OverdueTaskBanner-DismissButton")
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.97))
                        .shadow(color: Color.black.opacity(0.09), radius: 6, y: 3)
                )
                .overlay(
                    HStack {
                        Spacer()
                        Button {
                            showAuditLog = true
                        } label: {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.caption)
                        }
                        .padding(8)
                        .accessibilityIdentifier("OverdueTaskBanner-AuditLogButton")
                    }
                    .padding(.top, 2),
                    alignment: .topTrailing
                )
                .padding([.top, .horizontal])
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            .onAppear {
                if !appearedOnce {
                    appearedOnce = true
                    animateBadge = true
                    OverdueTaskBannerAudit.record(action: "Shown", detail: "count=\(overdueTasks.count)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { animateBadge = false }
                }
            }
            .sheet(isPresented: $showAuditLog) {
                NavigationStack {
                    List {
                        ForEach(OverdueTaskBannerAuditAdmin.recentEvents(limit: 14), id: \.self) { summary in
                            Text(summary)
                                .font(.caption)
                                .padding(.vertical, 2)
                        }
                    }
                    .navigationTitle("Overdue Task Banner Audit Log")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Copy") {
                                UIPasteboard.general.string = OverdueTaskBannerAuditAdmin.recentEvents(limit: 14).joined(separator: "\n")
                            }
                            .accessibilityIdentifier("OverdueTaskBanner-CopyAuditLogButton")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Audit/Event Logging

fileprivate struct OverdueTaskBannerAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let detail: String
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[OverdueTaskBanner] \(action): \(detail) at \(df.string(from: timestamp))"
    }
}
fileprivate final class OverdueTaskBannerAudit {
    static private(set) var log: [OverdueTaskBannerAuditEvent] = []
    static func record(action: String, detail: String) {
        let event = OverdueTaskBannerAuditEvent(timestamp: Date(), action: action, detail: detail)
        log.append(event)
        if log.count > 30 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 10) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum OverdueTaskBannerAuditAdmin {
    public static func recentEvents(limit: Int = 10) -> [String] { OverdueTaskBannerAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview + Model

struct OverdueTaskBanner_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            OverdueTaskBanner(overdueTasks: [
                Task(title: "Follow up with Max’s owner", notes: "", dueDate: Date().addingTimeInterval(-3600), priority: .high, isCompleted: false),
                Task(title: "Call supplier", notes: "", dueDate: Date().addingTimeInterval(-7200), priority: .medium, isCompleted: false)
            ])
            .preferredColorScheme(.light)

            OverdueTaskBanner(overdueTasks: [
                Task(title: "Send invoice", notes: "", dueDate: Date().addingTimeInterval(-3600), priority: .high, isCompleted: false)
            ], onViewAll: { print("View All tapped") })
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Priority + Task (for Preview/demo)

enum Priority: String, CaseIterable, Codable {
    case low, medium, high

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

struct Task: Identifiable, Codable {
    let id = UUID()
    var title: String
    var notes: String
    var dueDate: Date
    var priority: Priority
    var isCompleted: Bool
}
