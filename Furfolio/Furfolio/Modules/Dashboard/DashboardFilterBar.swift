//
//  DashboardFilterBar.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Filter Bar
//

import SwiftUI
import Combine

// MARK: - Audit/Event Logging

fileprivate struct DashboardFilterAuditEvent: Codable {
    let timestamp: Date
    let filterType: String
    let value: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Filter] \(filterType): \(value) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class DashboardFilterAudit {
    static private(set) var log: [DashboardFilterAuditEvent] = []

    /// Records a new filter event with timestamp, type, value, and tags.
    /// Also trims the log to keep last 40 events.
    static func record(
        filterType: String,
        value: String,
        tags: [String] = []
    ) {
        let event = DashboardFilterAuditEvent(
            timestamp: Date(),
            filterType: filterType,
            value: value,
            tags: tags
        )
        log.append(event)
        if log.count > 40 { log.removeFirst() }
        
        // Accessibility: Post VoiceOver announcement on filter change
        let announcement = "Filter set to \(filterType): \(value)."
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }

    /// Exports the last audit event as a pretty-printed JSON string.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    
    /// Exports all audit events as a CSV string with columns: timestamp,filterType,value,tags
    static func exportCSV() -> String {
        let header = "timestamp,filterType,value,tags"
        let rows = log.map { event -> String in
            let timestampStr = ISO8601DateFormatter().string(from: event.timestamp)
            let tagsStr = event.tags.joined(separator: "|")
            // Escape commas in value and filterType by wrapping with quotes if needed
            let filterTypeEscaped = event.filterType.contains(",") ? "\"\(event.filterType)\"" : event.filterType
            let valueEscaped = event.value.contains(",") ? "\"\(event.value)\"" : event.value
            return "\(timestampStr),\(filterTypeEscaped),\(valueEscaped),\(tagsStr)"
        }
        return ([header] + rows).joined(separator: "\n")
    }
    
    /// Returns the filterType that appears most frequently in the log.
    static var mostFrequentFilterType: String? {
        guard !log.isEmpty else { return nil }
        let freq = Dictionary(grouping: log, by: { $0.filterType })
            .mapValues { $0.count }
        return freq.max(by: { $0.value < $1.value })?.key
    }
    
    /// Returns the value that appears most frequently in the log.
    static var mostFrequentValue: String? {
        guard !log.isEmpty else { return nil }
        let freq = Dictionary(grouping: log, by: { $0.value })
            .mapValues { $0.count }
        return freq.max(by: { $0.value < $1.value })?.key
    }
    
    /// Returns the total number of filter events recorded.
    static var totalFilterEvents: Int {
        log.count
    }

    /// Accessibility summary string describing the last event or fallback message.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No dashboard filter events recorded."
    }
}

// MARK: - DashboardFilterBar

struct DashboardFilterBar: View {
    @Binding var selectedPeriod: TimePeriod
    @Binding var selectedDataType: DataType

    var onPeriodChange: ((TimePeriod) -> Void)?
    var onDataTypeChange: ((DataType) -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            filterSection(
                title: "Time Period",
                options: TimePeriod.allCases,
                selected: selectedPeriod
            ) { newPeriod in
                selectedPeriod = newPeriod
                DashboardFilterAudit.record(
                    filterType: "TimePeriod",
                    value: newPeriod.rawValue,
                    tags: ["period"]
                )
                onPeriodChange?(newPeriod)
            }

            filterSection(
                title: "Data Type",
                options: DataType.allCases,
                selected: selectedDataType
            ) { newDataType in
                selectedDataType = newDataType
                DashboardFilterAudit.record(
                    filterType: "DataType",
                    value: newDataType.rawValue,
                    tags: ["dataType"]
                )
                onDataTypeChange?(newDataType)
            }
        }
        .padding(.vertical, 8)
        #if DEBUG
        // DEV overlay showing last 3 audit events and analytics
        .overlay(
            VStack(alignment: .leading, spacing: 4) {
                Text("Audit Events (last 3):")
                    .font(.caption).bold()
                ForEach(DashboardFilterAudit.log.suffix(3).reversed(), id: \.timestamp) { event in
                    Text(event.accessibilityLabel)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Divider()
                Text("Most Frequent Filter Type: \(DashboardFilterAudit.mostFrequentFilterType ?? "N/A")")
                    .font(.caption2)
                Text("Most Frequent Value: \(DashboardFilterAudit.mostFrequentValue ?? "N/A")")
                    .font(.caption2)
                Text("Total Filter Events: \(DashboardFilterAudit.totalFilterEvents)")
                    .font(.caption2)
            }
            .padding(8)
            .background(Color(.systemBackground).opacity(0.9))
            .cornerRadius(8)
            .shadow(radius: 4)
            .padding()
            , alignment: .bottom
        )
        #endif
    }

    private func filterSection<T: Hashable & RawRepresentable>(
        title: String,
        options: [T],
        selected: T,
        action: @escaping (T) -> Void
    ) -> some View where T.RawValue == String {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(options, id: \.self) { option in
                    Button(action: {
                        action(option)
                    }) {
                        Text(option.rawValue)
                            .fontWeight(selected == option ? .bold : .regular)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 14)
                            .background(selected == option ? Color.accentColor.opacity(0.25) : Color.clear)
                            .foregroundColor(selected == option ? .accentColor : .primary)
                            .clipShape(Capsule())
                    }
                    .accessibilityLabel("Filter by \(option.rawValue)")
                    .accessibilityIdentifier("DashboardFilterBar-\(title)-\(option.rawValue)")
                }
            }
            .padding(.horizontal)
        }
        .accessibilityIdentifier("DashboardFilterBar-Section-\(title)")
    }
}

// MARK: - Audit/Admin Accessors

public enum DashboardFilterAuditAdmin {
    /// Returns a summary string of the last filter event for accessibility.
    public static var lastSummary: String { DashboardFilterAudit.accessibilitySummary }
    
    /// Returns the last audit event as a JSON string.
    public static var lastJSON: String? { DashboardFilterAudit.exportLastJSON() }
    
    /// Returns the audit log as a CSV string.
    public static func exportCSV() -> String { DashboardFilterAudit.exportCSV() }
    
    /// Returns the most frequent filterType in the audit log.
    public static var mostFrequentFilterType: String? { DashboardFilterAudit.mostFrequentFilterType }
    
    /// Returns the most frequent value in the audit log.
    public static var mostFrequentValue: String? { DashboardFilterAudit.mostFrequentValue }
    
    /// Returns the total number of filter events recorded.
    public static var totalFilterEvents: Int { DashboardFilterAudit.totalFilterEvents }
    
    /// Returns a list of recent audit event accessibility labels, limited by the specified count.
    public static func recentEvents(limit: Int = 5) -> [String] {
        DashboardFilterAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Supporting Enums

enum TimePeriod: String, CaseIterable {
    case today = "Today"
    case week = "Week"
    case month = "Month"
}

enum DataType: String, CaseIterable {
    case revenue = "Revenue"
    case appointments = "Appointments"
    case customers = "Customers"
}

// MARK: - Preview

#if DEBUG
struct DashboardFilterBar_Previews: PreviewProvider {
    @State static var selectedPeriod: TimePeriod = .week
    @State static var selectedDataType: DataType = .revenue

    static var previews: some View {
        DashboardFilterBar(
            selectedPeriod: $selectedPeriod,
            selectedDataType: $selectedDataType
        ) { period in
            print("Selected period: \(period.rawValue)")
        } onDataTypeChange: { dataType in
            print("Selected data type: \(dataType.rawValue)")
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
#endif
