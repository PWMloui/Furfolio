//
//  DogAnalyticsView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Dog Analytics
//

import SwiftUI
import Charts

// MARK: - Data Model

struct BehaviorTrendPoint: Identifiable {
    let id = UUID()
    let behavior: String
    let date: Date
    let rating: Int
}

// MARK: - Audit/Event Logging

fileprivate struct DogAnalyticsAuditEvent: Codable {
    let timestamp: Date
    let section: String
    let action: String
    let details: String
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[\(section)] \(action): \(details) at \(dateStr)"
    }
}
fileprivate final class DogAnalyticsAudit {
    static private(set) var log: [DogAnalyticsAuditEvent] = []
    static func record(section: String, action: String, details: String) {
        let event = DogAnalyticsAuditEvent(timestamp: Date(), section: section, action: action, details: details)
        log.append(event)
        if log.count > 30 { log.removeFirst() }
    }
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func recentSummaries(limit: Int = 6) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}

// MARK: - Enhanced BehaviorTrendChart

struct BehaviorTrendChart: View {
    let data: [BehaviorTrendPoint]

    private var behaviors: [String] { Array(Set(data.map { $0.behavior })).sorted() }
    private let colors: [Color] = [.green, .orange, .blue, .red, .purple, .pink]
    private var dateRange: String {
        guard let minDate = data.map({ $0.date }).min(),
              let maxDate = data.map({ $0.date }).max() else { return "n/a" }
        let f = DateFormatter(); f.dateFormat = "MMM yyyy"
        return "\(f.string(from: minDate)) – \(f.string(from: maxDate))"
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Behavior Trends")
                    .font(.title2.bold())
                Spacer()
            }
            .accessibilityIdentifier("DogAnalyticsView-BehaviorHeader")

            Chart {
                ForEach(behaviors.indices, id: \.self) { idx in
                    let behavior = behaviors[idx]
                    let points = data.filter { $0.behavior == behavior }
                    ForEach(points) { pt in
                        LineMark(
                            x: .value("Date", pt.date),
                            y: .value("Rating", pt.rating)
                        )
                        .foregroundStyle(colors[idx % colors.count])
                        .interpolationMethod(.catmullRom)
                        .symbol(Circle())
                        .symbolSize(28)
                        .accessibilityLabel("\(behavior), \(pt.rating), \(pt.date.formatted(.dateTime.month().year()))")
                        .accessibilityIdentifier("DogAnalyticsView-ChartLine-\(behavior)-\(pt.id)")
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 230)
            .padding(.top, 2)
            .accessibilityIdentifier("DogAnalyticsView-BehaviorChart")
            
            // Legend
            HStack(spacing: 12) {
                ForEach(behaviors.indices, id: \.self) { idx in
                    HStack(spacing: 6) {
                        Circle().fill(colors[idx % colors.count]).frame(width: 14, height: 14)
                        Text(behaviors[idx]).font(.footnote)
                    }
                    .accessibilityIdentifier("DogAnalyticsView-BehaviorLegend-\(behaviors[idx])")
                }
            }
            .padding(.top, 6)
            .accessibilityIdentifier("DogAnalyticsView-BehaviorLegend")
        }
        .padding(.vertical)
        .onAppear {
            DogAnalyticsAudit.record(
                section: "Behavior",
                action: "Appear",
                details: "Chart, \(behaviors.count) behaviors, range \(dateRange)"
            )
        }
    }
}

// MARK: - Main Analytics View

struct DogAnalyticsView: View {
    let behaviorData: [BehaviorTrendPoint]
    let totalVisits: Int
    let lastVisitDate: Date
    let vaccinationsUpToDate: Bool
    let allergies: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Section: Behavior Trends
                Section {
                    BehaviorTrendChart(data: behaviorData)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.secondarySystemBackground))
                                .shadow(radius: 2)
                        )
                        .padding(.horizontal)
                }

                // Section: Grooming History
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Grooming History")
                            .font(.title3.bold())
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("DogAnalyticsView-GroomingHeader")
                        HStack {
                            Text("Total Visits:").font(.headline)
                            Spacer()
                            Text("\(totalVisits)")
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Total grooming visits: \(totalVisits)")
                        .accessibilityIdentifier("DogAnalyticsView-TotalVisits")
                        HStack {
                            Text("Last Visit:").font(.headline)
                            Spacer()
                            Text(lastVisitDate, formatter: DateFormatter.shortDate)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Last grooming visit date: \(lastVisitDate, formatter: DateFormatter.shortDate)")
                        .accessibilityIdentifier("DogAnalyticsView-LastVisit")
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.secondarySystemBackground))
                            .shadow(radius: 1)
                    )
                    .padding(.horizontal)
                    .onAppear {
                        DogAnalyticsAudit.record(
                            section: "Grooming",
                            action: "Appear",
                            details: "Visits: \(totalVisits), Last: \(DateFormatter.shortDate.string(from: lastVisitDate))"
                        )
                    }
                }

                // Section: Health Summary
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Health Summary")
                            .font(.title3.bold())
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("DogAnalyticsView-HealthHeader")
                        HStack {
                            Text("Vaccinations Up to Date:").font(.headline)
                            Spacer()
                            Image(systemName: vaccinationsUpToDate ? "checkmark.seal.fill" : "xmark.seal.fill")
                                .foregroundColor(vaccinationsUpToDate ? .green : .red)
                                .accessibilityLabel(vaccinationsUpToDate ? "Vaccinations up to date" : "Vaccinations overdue")
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("DogAnalyticsView-Vaccination")
                        if allergies.isEmpty {
                            Text("No known allergies")
                                .foregroundColor(.secondary)
                                .accessibilityLabel("No known allergies")
                                .accessibilityIdentifier("DogAnalyticsView-NoAllergies")
                        } else {
                            VStack(alignment: .leading) {
                                Text("Allergies:").font(.headline)
                                ForEach(allergies, id: \.self) { allergy in
                                    Text("• \(allergy)")
                                        .accessibilityLabel("Allergy: \(allergy)")
                                        .accessibilityIdentifier("DogAnalyticsView-Allergy-\(allergy)")
                                }
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.secondarySystemBackground))
                            .shadow(radius: 1)
                    )
                    .padding(.horizontal)
                    .onAppear {
                        DogAnalyticsAudit.record(
                            section: "Health",
                            action: "Appear",
                            details: "Vaccines: \(vaccinationsUpToDate ? "Up to date" : "Overdue"), Allergies: \(allergies.joined(separator: ", "))"
                        )
                    }
                }

                Spacer()
            }
            .padding(.vertical)
        }
        .navigationTitle("Dog Analytics")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            DogAnalyticsAudit.record(
                section: "AnalyticsView",
                action: "Appear",
                details: "Dog analytics loaded"
            )
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum DogAnalyticsAuditAdmin {
    public static func lastSummary() -> String { DogAnalyticsAudit.log.last?.summary ?? "No events yet." }
    public static func lastJSON() -> String? { DogAnalyticsAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 6) -> [String] { DogAnalyticsAudit.recentSummaries(limit: limit) }
}

// MARK: - DateFormatter

extension DateFormatter {
    static var shortDate: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }
}

// MARK: - Preview

#if DEBUG
struct DogAnalyticsView_Previews: PreviewProvider {
    static var previews: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let behaviors = ["Calm", "Anxious", "Playful"]

        var sampleBehaviorData: [BehaviorTrendPoint] = []

        for behavior in behaviors {
            for monthOffset in 0..<6 {
                if let date = calendar.date(byAdding: .month, value: -monthOffset, to: today) {
                    let rating = Int.random(in: 1...5)
                    sampleBehaviorData.append(BehaviorTrendPoint(behavior: behavior, date: date, rating: rating))
                }
            }
        }

        NavigationView {
            DogAnalyticsView(
                behaviorData: sampleBehaviorData,
                totalVisits: 12,
                lastVisitDate: today.addingTimeInterval(-86400 * 30),
                vaccinationsUpToDate: true,
                allergies: ["Pollen", "Dust"]
            )
        }
    }
}
#endif
