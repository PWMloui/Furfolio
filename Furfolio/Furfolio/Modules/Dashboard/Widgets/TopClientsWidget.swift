//
//  TopClientsWidget.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Top Clients Widget
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct TopClientsWidgetAuditEvent: Codable {
    let timestamp: Date
    let clientCount: Int
    let topClient: String?
    let valueRange: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] TopClientsWidget: \(clientCount) clients, top: \(topClient ?? "n/a"), \(valueRange) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class TopClientsWidgetAudit {
    static private(set) var log: [TopClientsWidgetAuditEvent] = []

    static func record(
        clientCount: Int,
        topClient: String?,
        valueRange: String,
        tags: [String] = ["topClientsWidget"]
    ) {
        let event = TopClientsWidgetAuditEvent(
            timestamp: Date(),
            clientCount: clientCount,
            topClient: topClient,
            valueRange: valueRange,
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
        log.last?.accessibilityLabel ?? "No top clients events recorded."
    }
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
    }

    // MARK: - CSV Export
    /// Export all audit events as CSV (timestamp,clientCount,topClient,valueRange,tags)
    static func exportCSV() -> String {
        var csv = "timestamp,clientCount,topClient,valueRange,tags\n"
        let dateFormatter = ISO8601DateFormatter()
        for event in log {
            let ts = dateFormatter.string(from: event.timestamp)
            let top = event.topClient?.replacingOccurrences(of: ",", with: ";") ?? ""
            let range = event.valueRange.replacingOccurrences(of: ",", with: ";")
            let tags = event.tags.joined(separator: "|")
            csv += "\(ts),\(event.clientCount),\(top),\(range),\(tags)\n"
        }
        return csv
    }

    // MARK: - Analytics
    /// Most frequent top client across events
    static var mostFrequentTopClient: String? {
        let tops = log.compactMap { $0.topClient }
        let counts = Dictionary(grouping: tops, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    /// Average value range mid-point (business insight)
    static var averageTopClientValue: Double {
        let values = log.compactMap { event in
            // Parse max from valueRange "min $X, max $Y"
            let comps = event.valueRange.components(separatedBy: "max $")
            if comps.count == 2, let maxVal = Double(comps[1].replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "$", with: "")) {
                return maxVal
            }
            return nil
        }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
    /// Total widget displays (events)
    static var totalWidgetDisplays: Int { log.count }
}

// MARK: - Model

public struct TopClient: Identifiable {
    public let id = UUID()
    public let name: String
    public let value: Double  // e.g., revenue or visits
    public let pets: [String]

    public init(name: String, value: Double, pets: [String]) {
        self.name = name
        self.value = value
        self.pets = pets
    }
}

// MARK: - TopClientsWidget

public struct TopClientsWidget: View {
    public let clients: [TopClient]

    @State private var showAuditOverlay: Bool = false

    private var valueRange: String {
        guard let min = clients.map(\.value).min(),
              let max = clients.map(\.value).max() else { return "n/a" }
        let nf = NumberFormatter(); nf.numberStyle = .currency; nf.maximumFractionDigits = 0; nf.currencySymbol = "$"
        let minStr = nf.string(from: NSNumber(value: min)) ?? "$0"
        let maxStr = nf.string(from: NSNumber(value: max)) ?? "$0"
        return "min \(minStr), max \(maxStr)"
    }
    private var topClient: String? {
        clients.max(by: { $0.value < $1.value })?.name
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "person.3.fill")
                        .foregroundColor(.accentColor)
                        .font(.title2)
                        .accessibilityHidden(true)
                    Text("Top Clients")
                        .font(.headline)
                        .accessibilityIdentifier("TopClientsWidget-Title")
                }
                .padding(.bottom, 2)

                if clients.isEmpty {
                    Text("No client data available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("TopClientsWidget-Empty")
                        .onAppear {
                            // Accessibility: Announce empty state
                            #if os(iOS)
                            UIAccessibility.post(notification: .announcement, argument: "No top clients available.")
                            #endif
                        }
                } else {
                    ForEach(clients.prefix(5)) { client in
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(client.name)
                                    .font(.subheadline)
                                    .accessibilityIdentifier("TopClientsWidget-ClientName-\(client.name)")
                                if !client.pets.isEmpty {
                                    Text(client.pets.joined(separator: ", "))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .accessibilityIdentifier("TopClientsWidget-ClientPets-\(client.name)")
                                }
                            }
                            Spacer()
                            Text(currencyString(client.value))
                                .font(.subheadline.weight(.bold))
                                .accessibilityIdentifier("TopClientsWidget-ClientValue-\(client.name)")
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(accessibilitySummary)
            .accessibilityIdentifier("TopClientsWidget-Container")
            .onAppear {
                TopClientsWidgetAudit.record(
                    clientCount: clients.count,
                    topClient: topClient,
                    valueRange: valueRange
                )
                // Accessibility: Announce top client if present
                #if os(iOS)
                if let top = topClient {
                    UIAccessibility.post(notification: .announcement, argument: "Top client is \(top).")
                }
                #endif
            }

            #if DEBUG
            if showAuditOverlay {
                TopClientsWidgetAuditOverlay()
                    .onTapGesture { showAuditOverlay = false }
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            #endif
        }
        #if DEBUG
        .onLongPressGesture {
            withAnimation { showAuditOverlay.toggle() }
        }
        #endif
    }

    private func currencyString(_ value: Double) -> String {
        let nf = NumberFormatter(); nf.numberStyle = .currency; nf.maximumFractionDigits = 0; nf.currencySymbol = "$"
        return nf.string(from: NSNumber(value: value)) ?? "$0"
    }

    private var accessibilitySummary: String {
        if clients.isEmpty {
            return "No top clients available"
        } else {
            let top = topClient ?? "none"
            return "Top clients widget. \(clients.count) clients. Top: \(top). Value range: \(valueRange)"
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum TopClientsWidgetAuditAdmin {
    public static var lastSummary: String { TopClientsWidgetAudit.accessibilitySummary }
    public static var lastJSON: String? { TopClientsWidgetAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        TopClientsWidgetAudit.recentEvents(limit: limit)
    }
    /// Export all audit events as CSV
    public static func exportCSV() -> String { TopClientsWidgetAudit.exportCSV() }
    /// Analytics
    public static var mostFrequentTopClient: String? { TopClientsWidgetAudit.mostFrequentTopClient }
    public static var averageTopClientValue: Double { TopClientsWidgetAudit.averageTopClientValue }
    public static var totalWidgetDisplays: Int { TopClientsWidgetAudit.totalWidgetDisplays }
}

// MARK: - DEV Overlay View

#if DEBUG
struct TopClientsWidgetAuditOverlay: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TopClientsWidget Audit")
                .font(.caption.bold())
                .foregroundColor(.accentColor)
            ForEach(TopClientsWidgetAudit.log.suffix(3), id: \.timestamp) { event in
                Text(event.accessibilityLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if let top = TopClientsWidgetAudit.mostFrequentTopClient {
                Text("Most Frequent: \(top)").font(.caption2)
            }
            Text("Avg Top Value: \(Int(TopClientsWidgetAudit.averageTopClientValue))")
                .font(.caption2)
            Text("Total: \(TopClientsWidgetAudit.totalWidgetDisplays)")
                .font(.caption2)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)).opacity(0.95))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.accentColor, lineWidth: 1)
        )
        .shadow(radius: 2)
    }
}
#endif

// MARK: - Preview

#if DEBUG
struct TopClientsWidget_Previews: PreviewProvider {
    static var previews: some View {
        let sample = [
            TopClient(name: "Jane Doe", value: 2450, pets: ["Max", "Ruby"]),
            TopClient(name: "Mike Smith", value: 1940, pets: ["Charlie"]),
            TopClient(name: "Linda Wu", value: 1630, pets: ["Toby", "Daisy", "Paws"]),
            TopClient(name: "Sofia Patel", value: 1340, pets: ["Simba"]),
            TopClient(name: "Carlos Gomez", value: 1220, pets: ["Bella"]),
            TopClient(name: "Anna Lee", value: 1150, pets: ["Loki"])
        ]
        TopClientsWidget(clients: sample)
            .frame(width: 320)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif
