//
//  DashboardFilterBar.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Filter Bar
//

import SwiftUI

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
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
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
    public static var lastSummary: String { DashboardFilterAudit.accessibilitySummary }
    public static var lastJSON: String? { DashboardFilterAudit.exportLastJSON() }
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
