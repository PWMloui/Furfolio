//
//  TaskAnalyticsView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Task Analytics
//

import SwiftUI
import Charts

struct TaskAnalyticsView: View {
    @ObservedObject var taskManager: RecurringTaskManager = .mock()

    @State private var selectedPeriod: AnalyticsPeriod = .week
    @State private var showAuditLog = false
    @State private var animateCompletion = false
    @State private var animateOverdue = false
    @State private var appearedOnce = false

    var completedTasks: [RecurringTask] { taskManager.tasks.filter { $0.isCompleted } }
    var overdueTasks: [RecurringTask] { taskManager.overdueTasks() }
    var completionRate: Double {
        let total = Double(taskManager.tasks.count)
        let completed = Double(completedTasks.count)
        return total > 0 ? completed / total : 0
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Header
                    HStack {
                        Text("Task Analytics")
                            .font(.largeTitle.bold())
                        Spacer()
                        Button {
                            showAuditLog = true
                        } label: {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.title3)
                        }
                        .accessibilityIdentifier("TaskAnalyticsView-AuditLogButton")
                    }
                    .padding(.top)

                    // Completion Rate Summary
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Completion Rate")
                                .font(.headline)
                                .accessibilityIdentifier("TaskAnalyticsView-CompletionHeadline")
                            HStack {
                                Text("\(Int(completionRate * 100))%")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(completionRate >= 0.85 ? .green : (completionRate < 0.4 ? .red : .yellow))
                                    .scaleEffect(animateCompletion ? 1.12 : 1)
                                    .animation(.spring(response: 0.32, dampingFraction: 0.56), value: animateCompletion)
                                    .accessibilityIdentifier("TaskAnalyticsView-CompletionValue")
                                if completionRate >= 0.85 {
                                    Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                                } else if completionRate < 0.4 {
                                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                                }
                            }
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Overdue")
                                .font(.headline)
                                .accessibilityIdentifier("TaskAnalyticsView-OverdueHeadline")
                            HStack {
                                Text("\(overdueTasks.count)")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(overdueTasks.count == 0 ? .green : .red)
                                    .scaleEffect(animateOverdue ? 1.14 : 1)
                                    .animation(.spring(response: 0.31, dampingFraction: 0.55), value: animateOverdue)
                                    .accessibilityIdentifier("TaskAnalyticsView-OverdueValue")
                                if overdueTasks.count == 0 {
                                    Image(systemName: "hand.thumbsup.fill").foregroundColor(.green)
                                } else if overdueTasks.count >= 5 {
                                    Image(systemName: "bell.badge.fill").foregroundColor(.red)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(.secondarySystemBackground))
                            .shadow(radius: 2)
                    )

                    // Completion Trend Chart
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Completion Trend")
                                .font(.headline)
                            Spacer()
                            Picker("Period", selection: $selectedPeriod) {
                                ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                                    Text(period.displayName).tag(period)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                            .accessibilityIdentifier("TaskAnalyticsView-PeriodPicker")
                        }

                        CompletionTrendChart(tasks: taskManager.tasks, period: selectedPeriod)
                            .frame(height: 200)
                    }
                    .padding(.horizontal, 2)

                    // Overdue Tasks List (Preview)
                    if !overdueTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Overdue Tasks")
                                .font(.headline)
                                .accessibilityIdentifier("TaskAnalyticsView-OverdueListHeadline")
                            ForEach(overdueTasks.prefix(5)) { task in
                                HStack {
                                    Text(task.title)
                                    Spacer()
                                    Text(task.dueDate, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                                .accessibilityIdentifier("TaskAnalyticsView-Overdue-\(task.title)")
                            }
                            if overdueTasks.count > 5 {
                                Text("…and \(overdueTasks.count - 5) more")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 6)
                    }

                    Spacer()
                }
                .padding(.horizontal)
            }
            .navigationTitle("Task Analytics")
            .sheet(isPresented: $showAuditLog) {
                NavigationStack {
                    List {
                        ForEach(TaskAnalyticsAuditAdmin.recentEvents(limit: 20), id: \.self) { summary in
                            Text(summary)
                                .font(.caption)
                                .padding(.vertical, 2)
                        }
                    }
                    .navigationTitle("Task Analytics Audit Log")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Copy") {
                                UIPasteboard.general.string = TaskAnalyticsAuditAdmin.recentEvents(limit: 20).joined(separator: "\n")
                            }
                            .accessibilityIdentifier("TaskAnalyticsView-CopyAuditLogButton")
                        }
                    }
                }
            }
            .onChange(of: completionRate) { _ in
                animateCompletion = true
                TaskAnalyticsAudit.record(action: "CompletionRateChanged", detail: "rate=\(Int(completionRate * 100))%")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { animateCompletion = false }
            }
            .onChange(of: overdueTasks.count) { _ in
                animateOverdue = true
                TaskAnalyticsAudit.record(action: "OverdueCountChanged", detail: "overdue=\(overdueTasks.count)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { animateOverdue = false }
            }
            .onChange(of: selectedPeriod) { newPeriod in
                TaskAnalyticsAudit.record(action: "PeriodChanged", detail: newPeriod.displayName)
            }
            .onAppear {
                if !appearedOnce {
                    appearedOnce = true
                    TaskAnalyticsAudit.record(action: "Appear", detail: "")
                }
            }
        }
    }
}

// MARK: - CompletionTrendChart

struct CompletionTrendChart: View {
    let tasks: [RecurringTask]
    let period: AnalyticsPeriod

    var chartData: [Date: Int] {
        let completed = tasks.filter { $0.isCompleted }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: completed) { (task) -> Date in
            switch period {
            case .week:
                return calendar.startOfDay(for: task.dueDate)
            case .month:
                let comps = calendar.dateComponents([.year, .month], from: task.dueDate)
                return calendar.date(from: comps)!
            case .year:
                let comps = calendar.dateComponents([.year], from: task.dueDate)
                return calendar.date(from: comps)!
            }
        }
        return grouped.mapValues { $0.count }
    }

    var sortedDates: [Date] {
        chartData.keys.sorted()
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            Chart {
                ForEach(sortedDates, id: \.self) { date in
                    BarMark(
                        x: .value("Date", date, unit: .day),
                        y: .value("Completed", chartData[date] ?? 0)
                    )
                    .foregroundStyle(by: .value("Period", period.displayName))
                    .annotation {
                        if let count = chartData[date], count > 0 {
                            Text("\(count)").font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: sortedDates)
            }
        } else {
            Text("Charts require iOS 16+")
                .foregroundColor(.secondary)
                .padding()
        }
    }
}

// MARK: - AnalyticsPeriod

enum AnalyticsPeriod: String, CaseIterable {
    case week
    case month
    case year

    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }
}

// MARK: - Audit/Event Logging

fileprivate struct TaskAnalyticsAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let detail: String
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[TaskAnalytics] \(action): \(detail) at \(df.string(from: timestamp))"
    }
}
fileprivate final class TaskAnalyticsAudit {
    static private(set) var log: [TaskAnalyticsAuditEvent] = []
    static func record(action: String, detail: String) {
        let event = TaskAnalyticsAuditEvent(timestamp: Date(), action: action, detail: detail)
        log.append(event)
        if log.count > 40 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 16) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum TaskAnalyticsAuditAdmin {
    public static func recentEvents(limit: Int = 16) -> [String] { TaskAnalyticsAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview

#Preview {
    TaskAnalyticsView()
}
