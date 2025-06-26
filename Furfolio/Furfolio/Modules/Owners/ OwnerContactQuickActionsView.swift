//
//  OwnerContactQuickActionsView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Owner Quick Actions
//

import SwiftUI

struct OwnerContactQuickActionsView: View {
    let phoneNumber: String?
    let email: String?
    let address: String?

    // Configurable message template (make this user-customizable if needed)
    let messageTemplate = "Hi! This is a friendly reminder about your upcoming appointment with Furfolio."

    @State private var showErrorAlert: Bool = false
    @State private var errorText: String = ""

    var body: some View {
        HStack(spacing: 28) {
            // --- Call Button ---
            if let phone = phoneNumber, !phone.isEmpty, let url = URL(string: "tel://\(phone.onlyDigits)") {
                Link(destination: url) {
                    VStack(spacing: 5) {
                        Image(systemName: "phone.fill")
                            .font(.title)
                            .foregroundColor(.green)
                        Text("Call")
                            .font(.caption)
                    }
                }
                .accessibilityLabel("Call \(phone)")
                .accessibilityIdentifier("OwnerContactQuickActionsView-Call")
                .onTapGesture {
                    OwnerQuickActionAudit.record(action: "Call", value: phone)
                }
            }

            // --- Message Button ---
            if let phone = phoneNumber, !phone.isEmpty {
                Button(action: {
                    let success = openMessages(with: phone, body: messageTemplate)
                    OwnerQuickActionAudit.record(action: "Message", value: phone, result: success ? nil : "fail")
                    if !success {
                        errorText = "This device cannot send SMS messages."
                        showErrorAlert = true
                    }
                }) {
                    VStack(spacing: 5) {
                        Image(systemName: "message.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                        Text("Message")
                            .font(.caption)
                    }
                }
                .accessibilityLabel("Send a message to \(phone)")
                .accessibilityIdentifier("OwnerContactQuickActionsView-Message")
            }

            // --- Email Button ---
            if let mail = email, !mail.isEmpty,
               let url = URL(string: "mailto:\(mail)") {
                Link(destination: url) {
                    VStack(spacing: 5) {
                        Image(systemName: "envelope.fill")
                            .font(.title)
                            .foregroundColor(.purple)
                        Text("Email")
                            .font(.caption)
                    }
                }
                .accessibilityLabel("Send an email to \(mail)")
                .accessibilityIdentifier("OwnerContactQuickActionsView-Email")
                .onTapGesture {
                    OwnerQuickActionAudit.record(action: "Email", value: mail)
                }
            }

            // --- Address Button ---
            if let addr = address, !addr.isEmpty,
               let encoded = addr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: "http://maps.apple.com/?q=\(encoded)") {
                Link(destination: url) {
                    VStack(spacing: 5) {
                        Image(systemName: "map.fill")
                            .font(.title)
                            .foregroundColor(.orange)
                        Text("Map")
                            .font(.caption)
                    }
                }
                .accessibilityLabel("Show \(addr) in Maps")
                .accessibilityIdentifier("OwnerContactQuickActionsView-Map")
                .onTapGesture {
                    OwnerQuickActionAudit.record(action: "Map", value: addr)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 1)
        )
        .alert("Cannot Send Message", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { showErrorAlert = false }
        } message: {
            Text(errorText)
        }
    }
    
    // --- Helper function to open the Messages app with a template ---
    private func openMessages(with recipient: String, body: String) -> Bool {
        let cleanPhoneNumber = recipient.onlyDigits
        guard let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let smsUrl = URL(string: "sms:\(cleanPhoneNumber)&body=\(encodedBody)") else {
            return false
        }
        if UIApplication.shared.canOpenURL(smsUrl) {
            UIApplication.shared.open(smsUrl)
            return true
        } else {
            return false
        }
    }
}

// Helper extension to strip non-digit characters from phone number
extension String {
    var onlyDigits: String {
        filter("0123456789".contains)
    }
}

// MARK: - Audit/Event Logging

fileprivate struct OwnerQuickActionAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let value: String
    let result: String?
    var summary: String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        let r = result != nil ? " (\(result!))" : ""
        return "[OwnerContactQuickActions] \(action): \(value)\(r) at \(df.string(from: timestamp))"
    }
}
fileprivate final class OwnerQuickActionAudit {
    static private(set) var log: [OwnerQuickActionAuditEvent] = []
    static func record(action: String, value: String, result: String? = nil) {
        let event = OwnerQuickActionAuditEvent(timestamp: Date(), action: action, value: value, result: result)
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
public enum OwnerQuickActionAuditAdmin {
    public static func lastSummary() -> String { OwnerQuickActionAudit.log.last?.summary ?? "No events yet." }
    public static func lastJSON() -> String? { OwnerQuickActionAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 8) -> [String] { OwnerQuickActionAudit.recentSummaries(limit: limit) }
}

#Preview {
    OwnerContactQuickActionsView(
        phoneNumber: "555-123-4567",
        email: "demo@example.com",
        address: "123 Main St, Anytown, USA"
    )
}
