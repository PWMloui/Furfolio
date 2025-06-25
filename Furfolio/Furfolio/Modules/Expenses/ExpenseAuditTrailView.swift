//
//  ExpenseAuditTrailView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Extensible Expense Audit Trail View
//

import SwiftUI

struct ExpenseAuditEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let user: String
    let actionDescription: String
    let expenseAmount: Double?
    let expenseCategory: String?
    
    init(id: UUID = UUID(), date: Date, user: String, actionDescription: String, expenseAmount: Double? = nil, expenseCategory: String? = nil) {
        self.id = id
        self.date = date
        self.user = user
        self.actionDescription = actionDescription
        self.expenseAmount = expenseAmount
        self.expenseCategory = expenseCategory
    }
}

// MARK: - Audit/Event Logging

fileprivate struct ExpenseAuditTrailAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let details: String
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[AuditTrail] \(action): \(details) at \(dateStr)"
    }
}
fileprivate final class ExpenseAuditTrailAudit {
    static private(set) var log: [ExpenseAuditTrailAuditEvent] = []
    static func record(action: String, details: String) {
        let event = ExpenseAuditTrailAuditEvent(timestamp: Date(), action: action, details: details)
        log.append(event)
        if log.count > 40 { log.removeFirst() }
    }
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func recentSummaries(limit: Int = 8) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum ExpenseAuditTrailAuditAdmin {
    public static func lastSummary() -> String { ExpenseAuditTrailAudit.log.last?.summary ?? "No trail events yet." }
    public static func lastJSON() -> String? { ExpenseAuditTrailAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 8) -> [String] { ExpenseAuditTrailAudit.recentSummaries(limit: limit) }
}

// MARK: - Main View

struct ExpenseAuditTrailView: View {
    @State private var auditEntries: [ExpenseAuditEntry] = []
    @State private var filterUser: String = ""
    @State private var filterAction: String = ""
    @State private var sortDescending: Bool = true
    @State private var showExportAlert = false

    // For accessibility and test automation, gather unique users and actions
    private var uniqueUsers: [String] {
        Array(Set(auditEntries.map { $0.user })).sorted()
    }
    private var uniqueActions: [String] {
        Array(Set(auditEntries.map { $0.actionDescription })).sorted()
    }
    private var filteredEntries: [ExpenseAuditEntry] {
        auditEntries
            .filter { filterUser.isEmpty || $0.user == filterUser }
            .filter { filterAction.isEmpty || $0.actionDescription == filterAction }
            .sorted { sortDescending ? $0.date > $1.date : $0.date < $1.date }
    }
    private var footerText: String {
        filteredEntries.isEmpty
            ? "No audit entries available."
            : "\(filteredEntries.count) audit entr\(filteredEntries.count == 1 ? "y" : "ies")."
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Expense Audit Trail")
                    .font(.title2.bold())
                    .accessibilityIdentifier("ExpenseAuditTrailView-Header"),
                        footer: Text(footerText)
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .accessibilityIdentifier("ExpenseAuditTrailView-Footer")
                ) {
                    if filteredEntries.isEmpty {
                        Text("No audit entries found.")
                            .foregroundColor(.secondary)
                            .accessibilityLabel("No audit entries available")
                            .accessibilityIdentifier("ExpenseAuditTrailView-Empty")
                    } else {
                        ForEach(filteredEntries) { entry in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(entry.user)
                                        .font(.headline)
                                        .accessibilityIdentifier("ExpenseAuditTrailView-User-\(entry.user)")
                                    Spacer()
                                    Text(entry.date, style: .date)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .accessibilityIdentifier("ExpenseAuditTrailView-Date-\(entry.id)")
                                }
                                Text(entry.actionDescription)
                                    .font(.body)
                                    .accessibilityIdentifier("ExpenseAuditTrailView-Action-\(entry.id)")
                                if let amount = entry.expenseAmount,
                                   let category = entry.expenseCategory {
                                    Text(String(format: "Amount: $%.2f, Category: %@", amount, category))
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .accessibilityIdentifier("ExpenseAuditTrailView-Amount-\(entry.id)")
                                }
                            }
                            .padding(.vertical, 8)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(entry.user) performed action: \(entry.actionDescription) on \(entry.date.formatted(date: .abbreviated, time: .shortened)). \(entry.expenseAmount != nil ? "Amount: $\(String(format: "%.2f", entry.expenseAmount!))." : "") \(entry.expenseCategory != nil ? "Category: \(entry.expenseCategory!)." : "")")
                            .accessibilityIdentifier("ExpenseAuditTrailView-Entry-\(entry.id)")
                        }
                    }
                }
            }
            .navigationTitle("Expense Audit Trail")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Menu {
                        Picker("User", selection: $filterUser) {
                            Text("All Users").tag("")
                            ForEach(uniqueUsers, id: \.self) { user in
                                Text(user).tag(user)
                            }
                        }
                        Picker("Action", selection: $filterAction) {
                            Text("All Actions").tag("")
                            ForEach(uniqueActions, id: \.self) { action in
                                Text(action).tag(action)
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filter audit trail")
                    .accessibilityIdentifier("ExpenseAuditTrailView-FilterMenu")
                    Button {
                        sortDescending.toggle()
                        ExpenseAuditTrailAudit.record(action: "ToggleSort", details: sortDescending ? "Descending" : "Ascending")
                    } label: {
                        Image(systemName: sortDescending ? "arrow.down.circle" : "arrow.up.circle")
                    }
                    .accessibilityLabel("Toggle sort order")
                    .accessibilityIdentifier("ExpenseAuditTrailView-SortButton")
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        loadAuditEntries()
                        ExpenseAuditTrailAudit.record(action: "Refresh", details: "User manually refreshed")
                    } label: {
                        Image(systemName: "arrow.clockwise.circle")
                    }
                    .accessibilityLabel("Refresh audit trail")
                    .accessibilityIdentifier("ExpenseAuditTrailView-RefreshButton")
                    Button {
                        showExportAlert = true
                        ExpenseAuditTrailAudit.record(action: "Export", details: "User exported recent audit log")
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Export audit log")
                    .accessibilityIdentifier("ExpenseAuditTrailView-ExportButton")
                }
            }
            .onAppear {
                loadAuditEntries()
                ExpenseAuditTrailAudit.record(action: "Appear", details: "Audit trail viewed")
            }
            .alert("Audit Trail Export", isPresented: $showExportAlert, actions: {
                Button("Copy") {
                    let joined = ExpenseAuditTrailAuditAdmin.recentEvents(limit: 10).joined(separator: "\n")
                    UIPasteboard.general.string = joined
                }
                Button("OK", role: .cancel) { }
            }, message: {
                ScrollView {
                    Text(ExpenseAuditTrailAuditAdmin.recentEvents(limit: 10).joined(separator: "\n"))
                        .font(.caption2)
                        .multilineTextAlignment(.leading)
                }
            })
        }
    }

    private func loadAuditEntries() {
        // Simulated data fetch for demo purpose
        auditEntries = [
            ExpenseAuditEntry(date: Date(timeIntervalSinceNow: -3600), user: "Admin", actionDescription: "Added new expense", expenseAmount: 150.00, expenseCategory: "Supplies"),
            ExpenseAuditEntry(date: Date(timeIntervalSinceNow: -7200), user: "Admin", actionDescription: "Edited expense", expenseAmount: 100.00, expenseCategory: "Rent"),
            ExpenseAuditEntry(date: Date(timeIntervalSinceNow: -86400), user: "User1", actionDescription: "Deleted expense", expenseAmount: nil, expenseCategory: nil)
        ]
    }
}

#if DEBUG
struct ExpenseAuditTrailView_Previews: PreviewProvider {
    static var previews: some View {
        ExpenseAuditTrailView()
    }
}
#endif
