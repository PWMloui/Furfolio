//
//  ServiceTrendsChart.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Service Trends Chart
//

import SwiftUI
import Charts

// MARK: - Audit/Event Logging

fileprivate struct ServiceTrendsChartAuditEvent: Codable {
    let timestamp: Date
    let services: [String]
    let pointCount: Int
    let dateRange: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let serviceList = services.joined(separator: ", ")
        return "[Appear] Service Trends Chart: \(pointCount) points, services: [\(serviceList)], range: \(dateRange) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class ServiceTrendsChartAudit {
    static private(set) var log: [ServiceTrendsChartAuditEvent] = []

    /// Records a new audit event with given parameters
    static func record(
        services: [String],
        pointCount: Int,
        dateRange: String,
        tags: [String] = ["serviceTrendsChart"]
    ) {
        let event = ServiceTrendsChartAuditEvent(
            timestamp: Date(),
            services: services,
            pointCount: pointCount,
            dateRange: dateRange,
            tags: tags
        )
        log.append(event)
        if log.count > 40 { log.removeFirst() }
        
        // Accessibility enhancement: Post VoiceOver announcement if any event has pointCount > 30
        if pointCount > 30 {
            DispatchQueue.main.async {
                UIAccessibility.post(notification: .announcement, argument: "High volume: Over 30 service trend points.")
            }
        }
    }

    /// Exports the last audit event as pretty-printed JSON string
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    
    /// Exports all audit events as CSV string including timestamp, services, pointCount, dateRange, tags
    static func exportCSV() -> String {
        var csv = "timestamp,services,pointCount,dateRange,tags\n"
        let formatter = ISO8601DateFormatter()
        for event in log {
            let timestamp = formatter.string(from: event.timestamp)
            // Escape services and tags that might contain commas by wrapping in quotes
            let services = "\"\(event.services.joined(separator: ";"))\""
            let pointCount = "\(event.pointCount)"
            let dateRange = "\"\(event.dateRange)\""
            let tags = "\"\(event.tags.joined(separator: ";"))\""
            csv.append("\(timestamp),\(services),\(pointCount),\(dateRange),\(tags)\n")
        }
        return csv
    }
    
    /// Accessibility summary of last event or default message
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No service trends chart events recorded."
    }
    
    /// Analytics: Average point count across all audit events
    static var averagePointCount: Double {
        guard !log.isEmpty else { return 0.0 }
        let total = log.reduce(0) { $0 + $1.pointCount }
        return Double(total) / Double(log.count)
    }
    
    /// Analytics: Most frequently occurring service across all audit events
    static var mostFrequentService: String {
        var frequency: [String: Int] = [:]
        for event in log {
            for service in event.services {
                frequency[service, default: 0] += 1
            }
        }
        return frequency.max(by: { $0.value < $1.value })?.key ?? "N/A"
    }
}

// MARK: - Model

struct ServiceTrendPoint: Identifiable {
    var id = UUID()
    var service: String
    var date: Date
    var count: Int
}

// MARK: - ServiceTrendsChart

struct ServiceTrendsChart: View {
    let data: [ServiceTrendPoint]

    // Extract distinct services for color mapping
    private var services: [String] {
        Array(Set(data.map { $0.service })).sorted()
    }

    // Color palette for services
    private let colors: [Color] = [
        .blue, .green, .orange, .purple, .pink, .red, .yellow, .teal
    ]

    // Find date range for summary/audit
    private var dateRangeString: String {
        guard let minDate = data.map(\.date).min(),
              let maxDate = data.map(\.date).max() else { return "n/a" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return "\(formatter.string(from: minDate)) – \(formatter.string(from: maxDate))"
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Service Popularity Trends")
                .font(.headline)
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("ServiceTrendsChart-Header")

            Chart {
                ForEach(services.indices, id: \.self) { index in
                    let service = services[index]
                    let serviceData = data.filter { $0.service == service }
                    ForEach(serviceData) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Count", point.count)
                        )
                        .foregroundStyle(colors[index % colors.count])
                        .interpolationMethod(.catmullRom)
                        .symbol(Circle())
                        .symbolSize(30)
                        .annotation(position: .top) {
                            Text("\(point.count)")
                                .font(.caption2)
                                .foregroundColor(colors[index % colors.count])
                        }
                        .accessibilityLabel("\(service), \(point.count) on \(point.date.formatted(.dateTime.year().month()))")
                        .accessibilityIdentifier("ServiceTrendsChart-\(service)-\(point.date.timeIntervalSince1970)")
                    }
                }
            }
            .chartForegroundStyleScale(
                Dictionary(uniqueKeysWithValues: services.enumerated().map { index, service in
                    (service, colors[index % colors.count])
                })
            )
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 240)
            .accessibilityLabel("Service trends by month")
            .accessibilityIdentifier("ServiceTrendsChart-MainChart")

            // Legend
            HStack(spacing: 12) {
                ForEach(services.indices, id: \.self) { index in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(colors[index % colors.count])
                            .frame(width: 14, height: 14)
                            .accessibilityHidden(true)
                        Text(services[index])
                            .font(.footnote)
                            .accessibilityIdentifier("ServiceTrendsChart-Legend-\(services[index])")
                    }
                }
            }
            .padding(.top, 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Chart legend: " + services.joined(separator: ", "))
            .accessibilityIdentifier("ServiceTrendsChart-Legend")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 6)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Service popularity trends chart, showing trends for \(services.joined(separator: ", ")), over \(dateRangeString)")
        .accessibilityIdentifier("ServiceTrendsChart-Container")
        .onAppear {
            ServiceTrendsChartAudit.record(
                services: services,
                pointCount: data.count,
                dateRange: dateRangeString
            )
        }
        #if DEBUG
        // DEV overlay showing last 3 audit events and analytics
        .overlay(
            VStack(alignment: .leading, spacing: 4) {
                Text("Audit Events (last 3):")
                    .font(.caption)
                    .bold()
                ForEach(ServiceTrendsChartAudit.log.suffix(3).reversed(), id: \.timestamp) { event in
                    Text(event.accessibilityLabel)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Divider()
                Text(String(format: "Average Point Count: %.2f", ServiceTrendsChartAudit.averagePointCount))
                    .font(.caption2)
                Text("Most Frequent Service: \(ServiceTrendsChartAudit.mostFrequentService)")
                    .font(.caption2)
            }
            .padding(8)
            .background(Color.black.opacity(0.75))
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(),
            alignment: .bottom
        )
        #endif
    }
}

// MARK: - Audit/Admin Accessors

public enum ServiceTrendsChartAuditAdmin {
    public static var lastSummary: String { ServiceTrendsChartAudit.accessibilitySummary }
    public static var lastJSON: String? { ServiceTrendsChartAudit.exportLastJSON() }
    
    /// Exposes CSV export of all audit events
    public static var exportCSV: String { ServiceTrendsChartAudit.exportCSV() }
    
    /// Exposes average point count analytics
    public static var averagePointCount: Double { ServiceTrendsChartAudit.averagePointCount }
    
    /// Exposes most frequent service analytics
    public static var mostFrequentService: String { ServiceTrendsChartAudit.mostFrequentService }
    
    /// Returns recent audit event accessibility labels, limited by parameter
    public static func recentEvents(limit: Int = 5) -> [String] {
        ServiceTrendsChartAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Preview

#if DEBUG
struct ServiceTrendsChart_Previews: PreviewProvider {
    static var previews: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let services = ["Full Groom", "Bath Only", "Nail Trim"]

        var sampleData: [ServiceTrendPoint] = []

        for service in services {
            for monthOffset in 0..<6 {
                if let date = calendar.date(byAdding: .month, value: -monthOffset, to: today) {
                    let count = Int.random(in: 5...25)
                    sampleData.append(ServiceTrendPoint(service: service, date: date, count: count))
                }
            }
        }

        ServiceTrendsChart(data: sampleData)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
#endif
