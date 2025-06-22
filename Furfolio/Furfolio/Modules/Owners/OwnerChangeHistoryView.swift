//
//  OwnerChangeHistoryView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct OwnerChangeHistoryEntry: Identifiable {
    let id = UUID()
    let date: Date
    let fieldChanged: String
    let oldValue: String
    let newValue: String
    let changedBy: String
}

struct OwnerChangeHistoryView: View {
    let changes: [OwnerChangeHistoryEntry]

    var body: some View {
        NavigationStack {
            List {
                if changes.isEmpty {
                    ContentUnavailableView("No change history.", systemImage: "clock.arrow.circlepath")
                        .padding(.top, 40)
                } else {
                    ForEach(changes) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.fieldChanged)
                                    .font(.headline)
                                Spacer()
                                Text(entry.date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 8) {
                                Text("From:")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.secondary)
                                Text(entry.oldValue)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("→")
                                    .font(.caption2)
                                Text(entry.newValue)
                                    .font(.caption2.bold())
                            }
                            Text("Changed by \(entry.changedBy)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle("Change History")
            .background(Color(.systemGroupedBackground))
        }
    }
}

#if DEBUG
struct OwnerChangeHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        OwnerChangeHistoryView(
            changes: [
                OwnerChangeHistoryEntry(date: Date().addingTimeInterval(-3600 * 2), fieldChanged: "Phone Number", oldValue: "555-123-4567", newValue: "555-987-6543", changedBy: "Admin"),
                OwnerChangeHistoryEntry(date: Date().addingTimeInterval(-3600 * 24 * 1), fieldChanged: "Address", oldValue: "123 Main St", newValue: "321 Bark Ave", changedBy: "Staff1"),
                OwnerChangeHistoryEntry(date: Date().addingTimeInterval(-3600 * 24 * 3), fieldChanged: "Email", oldValue: "jane@old.com", newValue: "jane@new.com", changedBy: "Admin")
            ]
        )
    }
}
#endif
