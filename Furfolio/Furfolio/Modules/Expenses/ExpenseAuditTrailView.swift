//
//  ExpenseAuditTrailView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//


//
//  ExpenseAuditTrailView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct ExpenseAuditEntry: Identifiable {
    let id = UUID()
    let date: Date
    let user: String
    let actionDescription: String
    let expenseAmount: Double?
    let expenseCategory: String?
}

struct ExpenseAuditTrailView: View {
    @State private var auditEntries: [ExpenseAuditEntry] = []
    
    var body: some View {
        NavigationStack {
            List {
                if auditEntries.isEmpty {
                    Text("No audit entries available.")
                        .foregroundColor(.secondary)
                        .accessibilityLabel("No audit entries available")
                } else {
                    ForEach(auditEntries.sorted(by: { $0.date > $1.date })) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(entry.user)
                                    .font(.headline)
                                Spacer()
                                Text(entry.date, style: .date)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Text(entry.actionDescription)
                                .font(.body)
                            if let amount = entry.expenseAmount,
                               let category = entry.expenseCategory {
                                Text(String(format: "Amount: $%.2f, Category: %@", amount, category))
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(entry.user) performed action: \(entry.actionDescription) on \(entry.date.formatted(date: .abbreviated, time: .shortened)). \(entry.expenseAmount != nil ? "Amount: $\(String(format: "%.2f", entry.expenseAmount!))." : "") \(entry.expenseCategory != nil ? "Category: \(entry.expenseCategory!)." : "")")
                    }
                }
            }
            .navigationTitle("Expense Audit Trail")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        loadAuditEntries()
                    } label: {
                        Image(systemName: "arrow.clockwise.circle")
                    }
                    .accessibilityLabel("Refresh audit trail")
                }
            }
            .onAppear {
                loadAuditEntries()
            }
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
