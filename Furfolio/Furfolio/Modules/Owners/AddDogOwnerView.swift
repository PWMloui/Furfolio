//
//  AddDogOwnerView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Add Dog Owner View
//

import SwiftUI

struct AddDogOwnerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ownerName: String = ""
    @State private var phoneNumber: String = ""
    @State private var email: String = ""
    @State private var address: String = ""
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = "Owner name is required."

    var onSave: ((String, String, String, String) -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Owner Details").fontWeight(.semibold)) {
                    TextField("Owner Name", text: $ownerName)
                        .textContentType(.name)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                        .accessibilityIdentifier("AddDogOwnerView-OwnerName")

                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .accessibilityIdentifier("AddDogOwnerView-PhoneNumber")

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .accessibilityIdentifier("AddDogOwnerView-Email")

                    TextField("Address", text: $address)
                        .textContentType(.fullStreetAddress)
                        .accessibilityIdentifier("AddDogOwnerView-Address")
                }
            }
            .navigationTitle("Add Dog Owner")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        AddDogOwnerAudit.record(action: "Cancel", ownerName: ownerName)
                        dismiss()
                    }
                    .accessibilityIdentifier("AddDogOwnerView-CancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !ownerName.trimmingCharacters(in: .whitespaces).isEmpty else {
                            alertMessage = "Owner name is required."
                            showAlert = true
                            AddDogOwnerAudit.record(action: "SaveFailed", ownerName: ownerName, phoneNumber: phoneNumber, email: email, error: "No owner name")
                            return
                        }
                        if !phoneNumber.isEmpty && !isValidPhone(phoneNumber) {
                            alertMessage = "Please enter a valid phone number."
                            showAlert = true
                            AddDogOwnerAudit.record(action: "SaveFailed", ownerName: ownerName, phoneNumber: phoneNumber, email: email, error: "Invalid phone")
                            return
                        }
                        if !email.isEmpty && !isValidEmail(email) {
                            alertMessage = "Please enter a valid email address."
                            showAlert = true
                            AddDogOwnerAudit.record(action: "SaveFailed", ownerName: ownerName, phoneNumber: phoneNumber, email: email, error: "Invalid email")
                            return
                        }
                        AddDogOwnerAudit.record(action: "Save", ownerName: ownerName, phoneNumber: phoneNumber, email: email)
                        onSave?(ownerName, phoneNumber, email, address)
                        dismiss()
                    }
                    .disabled(ownerName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("AddDogOwnerView-SaveButton")
                }
            }
            .alert(alertMessage, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            }
            .onAppear {
                AddDogOwnerAudit.record(action: "Appear")
            }
        }
    }

    // --- Validation helpers ---
    private func isValidPhone(_ value: String) -> Bool {
        let digits = value.filter("0123456789".contains)
        return digits.count >= 7 && digits.count <= 15
    }

    private func isValidEmail(_ value: String) -> Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return value.range(of: emailRegex, options: .regularExpression) != nil
    }
}

// MARK: - Audit/Event Logging

fileprivate struct AddDogOwnerAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let ownerName: String
    let phoneNumber: String?
    let email: String?
    let error: String?
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        let err = error != nil ? " [Error: \(error!)]" : ""
        return "[AddDogOwner] \(action): \(ownerName), \(phoneNumber ?? "-"), \(email ?? "-")\(err) at \(df.string(from: timestamp))"
    }
}
fileprivate final class AddDogOwnerAudit {
    static private(set) var log: [AddDogOwnerAuditEvent] = []
    static func record(action: String, ownerName: String = "", phoneNumber: String? = nil, email: String? = nil, error: String? = nil) {
        let event = AddDogOwnerAuditEvent(timestamp: Date(), action: action, ownerName: ownerName, phoneNumber: phoneNumber, email: email, error: error)
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
public enum AddDogOwnerAuditAdmin {
    public static func lastSummary() -> String { AddDogOwnerAudit.log.last?.summary ?? "No events yet." }
    public static func lastJSON() -> String? { AddDogOwnerAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 8) -> [String] { AddDogOwnerAudit.recentSummaries(limit: limit) }
}

#Preview {
    AddDogOwnerView()
}
