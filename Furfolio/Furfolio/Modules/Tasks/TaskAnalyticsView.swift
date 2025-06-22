//
//  TaskAnalyticsView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI
import Charts

struct TaskAnalyticsView: View {
    // Replace with your real ViewModel or data source
    @ObservedObject var taskManager: RecurringTaskManager = .mock() // or inject real manager

    @State private var selectedPeriod: AnalyticsPeriod = .week

    var completedTasks: [RecurringTask] {
        taskManager.tasks.filter { $0.isCompleted }
    }
    var overdueTasks: [RecurringTask] {
        taskManager.overdueTasks()
    }
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
                    Text("Task Analytics")
                        .font(.largeTitle.bold())
                        .padding(.top)

                    // Completion Rate Summary
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Completion Rate")
                                .font(.headline)
                            Text("\(Int(completionRate * 100))%")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.green)
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Overdue")
                                .font(.headline)
                            Text("\(overdueTasks.count)")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.red)
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
                            ForEach(overdueTasks.prefix(5)) { task in
                                HStack {
                                    Text(task.title)
                                    Spacer()
                                    Text(task.dueDate, style: .date)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
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
        }
    }
}

// MARK: - CompletionTrendChart

struct CompletionTrendChart: View {
    let tasks: [RecurringTask]
    let period: AnalyticsPeriod

    var chartData: [Date: Int] {
        // Group completed tasks by period (day/week/month)
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
                }
            }
            .chartXAxis {
                AxisMarks(values: sortedDates)
            }
        } else {
            Text("Charts require iOS 16+")
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

// MARK: - Preview

#Preview {
    TaskAnalyticsView()
}
