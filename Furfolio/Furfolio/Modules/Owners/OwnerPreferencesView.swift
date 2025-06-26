//
//  OwnerPreferencesView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Owner Preferences
//

import SwiftUI

struct OwnerPreferencesView: View {
    @Binding var favoriteGroomingStyle: String
    @Binding var preferredShampoo: String
    @Binding var specialRequests: String

    let specialRequestsLimit = 250
    @State private var showLimitError: Bool = false
    @State private var appearedOnce: Bool = false

    var body: some View {
        Form {
            Section(header: Text("Grooming Preferences").fontWeight(.semibold)) {
                TextField("Favorite Grooming Style", text: $favoriteGroomingStyle)
                    .autocapitalization(.words)
                    .disableAutocorrection(true)
                    .accessibilityIdentifier("OwnerPreferencesView-FavoriteGroomingStyle")
                    .onChange(of: favoriteGroomingStyle) { value in
                        OwnerPreferencesAudit.record(field: "Favorite Grooming Style", value: value)
                    }

                TextField("Preferred Shampoo", text: $preferredShampoo)
                    .autocapitalization(.words)
                    .disableAutocorrection(true)
                    .accessibilityIdentifier("OwnerPreferencesView-PreferredShampoo")
                    .onChange(of: preferredShampoo) { value in
                        OwnerPreferencesAudit.record(field: "Preferred Shampoo", value: value)
                    }
            }

            Section(header: Text("Special Requests").fontWeight(.semibold)) {
                ZStack(alignment: .topLeading) {
                    if specialRequests.isEmpty {
                        Text("Enter any special requests or care notes...")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 7)
                            .accessibilityIdentifier("OwnerPreferencesView-SpecialRequestsPlaceholder")
                    }
                    TextEditor(text: $specialRequests)
                        .frame(height: 90)
                        .padding(4)
                        .background(showLimitError ? Color.red.opacity(0.07) : Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityIdentifier("OwnerPreferencesView-SpecialRequests")
                        .onChange(of: specialRequests) { value in
                            if value.count > specialRequestsLimit {
                                specialRequests = String(value.prefix(specialRequestsLimit))
                                showLimitError = true
                                OwnerPreferencesAudit.record(field: "Special Requests", value: "Limit reached")
                            } else {
                                showLimitError = false
                                OwnerPreferencesAudit.record(field: "Special Requests", value: value)
                            }
                        }
                }
                HStack {
                    Spacer()
                    Text("\(specialRequests.count)/\(specialRequestsLimit)")
                        .font(.caption2)
                        .foregroundStyle(showLimitError ? .red : .secondary)
                        .accessibilityIdentifier("OwnerPreferencesView-SpecialRequestsCharCount")
                }
                if showLimitError {
                    Text("Maximum special requests length reached.")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("OwnerPreferencesView-SpecialRequestsLimitError")
                }
            }
        }
        .navigationTitle("Owner Preferences")
        .onAppear {
            if !appearedOnce {
                OwnerPreferencesAudit.record(field: "ViewAppear", value: "")
                appearedOnce = true
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    OwnerPreferencesAudit.export()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Export Preferences Audit Log")
                .accessibilityIdentifier("OwnerPreferencesView-ExportButton")
            }
        }
    }
}

// MARK: - Audit/Event Logging

fileprivate struct OwnerPreferencesAuditEvent: Codable {
    let timestamp: Date
    let field: String
    let value: String
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[OwnerPreferences] \(field): '\(value.prefix(30))' at \(df.string(from: timestamp))"
    }
}
fileprivate final class OwnerPreferencesAudit {
    static private(set) var log: [OwnerPreferencesAuditEvent] = []
    static func record(field: String, value: String) {
        let event = OwnerPreferencesAuditEvent(timestamp: Date(), field: field, value: value)
        log.append(event)
        if log.count > 30 { log.removeFirst() }
    }
    static func export() {
        let summaries = log.suffix(10).map { $0.summary }.joined(separator: "\n")
        UIPasteboard.general.string = summaries
    }
}

#Preview {
    @State var style = ""
    @State var shampoo = ""
    @State var special = ""
    return OwnerPreferencesView(
        favoriteGroomingStyle: $style,
        preferredShampoo: $shampoo,
        specialRequests: $special
    )
}
