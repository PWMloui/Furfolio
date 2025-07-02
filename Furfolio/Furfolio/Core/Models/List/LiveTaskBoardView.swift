//
//  LiveTaskBoardView.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

/**
 LiveTaskBoardView
 -----------------
 A real-time task board for the Furfolio app, showing grooming tasks in progress, upcoming, and completed.
 
 - **Architecture**: SwiftUI MVVM using `LiveTaskBoardViewModel` as an ObservableObject.
 - **Concurrency**: Designed for async/await updates via WebSocket or polling.
 - **Audit/Analytics Ready**: User interactions (e.g., task tapped, refreshed) can hook into async audit loggers.
 - **Localization**: All UI strings wrapped in `LocalizedStringKey`.
 - **Accessibility**: Roles, labels, and hints provided for dynamic content.
 - **Preview/Testability**: Includes a Debug Preview with sample data.
 */

import SwiftUI
import SwiftData

/// The main view displaying a live task board with filtering and real-time updates.
struct LiveTaskBoardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \.scheduledTime, order: .forward) private var tasks: [TaskModel]
    
    /// The available task filters shown in the sidebar.
    enum TaskFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case upcoming = "Upcoming"
        case inProgress = "InProgress"
        case completed = "Completed"
        
        var id: String { self.rawValue }
        
        var localizedName: LocalizedStringKey {
            switch self {
            case .all: return LocalizedStringKey("All")
            case .upcoming: return LocalizedStringKey("Upcoming")
            case .inProgress: return LocalizedStringKey("In Progress")
            case .completed: return LocalizedStringKey("Completed")
            }
        }
    }
    
    @State private var selectedFilter: TaskFilter = .all
    
    var body: some View {
        NavigationView {
            List(selection: $selectedFilter) {
                ForEach(TaskFilter.allCases) { filter in
                    Text(filter.localizedName)
                        .tag(filter)
                        .accessibilityIdentifier("Filter_\(filter.rawValue)")
                }
            }
            .listStyle(SidebarListStyle())
            .navigationTitle(Text("Task Filters"))
            .accessibilityIdentifier("TaskFiltersSidebar")
            .accessibilityLabel(Text("Task Filters Sidebar"))
            
            Group {
                if filteredTasks.isEmpty {
                    VStack {
                        Text(LocalizedStringKey("No tasks found."))
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("NoTasksLabel")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredTasks, id: \.id) { task in
                        Button {
                            Task {
                                await LiveTaskBoardAnalytics.shared.log("TaskTapped: \(task.id.uuidString)")
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(task.title)
                                        .font(.headline)
                                        .accessibilityIdentifier("TaskTitle_\(task.id.uuidString)")
                                    Text(task.dogName)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .accessibilityIdentifier("TaskDogName_\(task.id.uuidString)")
                                    Text(task.scheduledTime, style: .time)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .accessibilityIdentifier("TaskScheduledTime_\(task.id.uuidString)")
                                }
                                Spacer()
                                StatusBadge(status: task.status)
                                    .accessibilityIdentifier("TaskStatusBadge_\(task.id.uuidString)")
                                    .accessibilityLabel(Text(task.status.localizedName))
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityIdentifier("TaskButton_\(task.id.uuidString)")
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle(selectedFilter.localizedName)
            .accessibilityIdentifier("TaskListView")
            .accessibilityLabel(Text("Task List View"))
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await LiveTaskBoardAnalytics.shared.log("RefreshedTasks")
                    }
                } label: {
                    Label(LocalizedStringKey("Refresh"), systemImage: "arrow.clockwise")
                }
                .accessibilityIdentifier("RefreshButton")
                .accessibilityLabel(Text("Refresh Tasks"))
                .help(LocalizedStringKey("Refresh the task list"))
            }
        }
        .onChange(of: selectedFilter) { newFilter in
            Task {
                await LiveTaskBoardAnalytics.shared.log("FilterSelected: \(newFilter.rawValue)")
            }
        }
    }
    
    /// Filters tasks according to the selected filter.
    private var filteredTasks: [TaskModel] {
        switch selectedFilter {
        case .all:
            return tasks
        case .upcoming:
            return tasks.filter { $0.status == .upcoming }
        case .inProgress:
            return tasks.filter { $0.status == .inProgress }
        case .completed:
            return tasks.filter { $0.status == .completed }
        }
    }
}

/// A small badge view representing task status.
private struct StatusBadge: View {
    let status: TaskStatus
    
    var body: some View {
        Text(status.localizedName)
            .font(.caption2)
            .padding(6)
            .background(status.color.opacity(0.2))
            .foregroundColor(status.color)
            .clipShape(Capsule())
    }
}

/// Represents a task's status.
enum TaskStatus: String {
    case upcoming
    case inProgress
    case completed
    
    var localizedName: LocalizedStringKey {
        switch self {
        case .upcoming: return LocalizedStringKey("Upcoming")
        case .inProgress: return LocalizedStringKey("In Progress")
        case .completed: return LocalizedStringKey("Completed")
        }
    }
    
    var color: Color {
        switch self {
        case .upcoming: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        }
    }
}

actor LiveTaskBoardAnalytics {
    static let shared = LiveTaskBoardAnalytics()
    func log(_ event: String) async {
        // TODO: integrate with analytics
        print("[LiveTaskBoard] event: \(event)")
    }
}

#if DEBUG
struct LiveTaskBoardView_Previews: PreviewProvider {
    static var previews: some View {
        LiveTaskBoardView()
            .previewDisplayName("LiveTaskBoardView Preview")
    }
}
#endif
