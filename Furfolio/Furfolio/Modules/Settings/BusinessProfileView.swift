//
//  BusinessProfileView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Business Profile
//

import SwiftUI

struct BusinessProfileView: View {
    @State private var businessName: String = "Your Grooming Business"
    @State private var ownerName: String = "Business Owner"
    @State private var phoneNumber: String = ""
    @State private var email: String = ""
    @State private var address: String = ""
    @State private var description: String = "We care for your pets like family!"
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var appearedOnce: Bool = false
    @State private var showAuditLog: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Logo/avatar
                Image(systemName: "pawprint.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 108, height: 108)
                    .foregroundStyle(.accent)
                    .padding(.top, 28)
                    .accessibilityIdentifier("BusinessProfileView-Logo")

                SectionCard {
                    VStack(alignment: .leading, spacing: 14) {
                        LabeledTextField(
                            label: "Business Name",
                            text: $businessName,
                            systemImage: "building.2.fill"
                        )
                        .accessibilityIdentifier("BusinessProfileView-BusinessName")

                        LabeledTextField(
                            label: "Owner Name",
                            text: $ownerName,
                            systemImage: "person.fill"
                        )
                        .accessibilityIdentifier("BusinessProfileView-OwnerName")
                    }
                }

                SectionCard {
                    VStack(alignment: .leading, spacing: 14) {
                        LabeledTextField(
                            label: "Phone Number",
                            text: $phoneNumber,
                            systemImage: "phone.fill",
                            keyboardType: .phonePad
                        )
                        .accessibilityIdentifier("BusinessProfileView-Phone")

                        LabeledTextField(
                            label: "Email",
                            text: $email,
                            systemImage: "envelope.fill",
                            keyboardType: .emailAddress
                        )
                        .accessibilityIdentifier("BusinessProfileView-Email")

                        LabeledTextField(
                            label: "Address",
                            text: $address,
                            systemImage: "map.fill"
                        )
                        .accessibilityIdentifier("BusinessProfileView-Address")
                    }
                }

                SectionCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Business Description", systemImage: "quote.bubble")
                            .font(.headline)
                            .accessibilityIdentifier("BusinessProfileView-DescriptionLabel")
                        TextEditor(text: $description)
                            .frame(height: 100)
                            .padding(6)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .accessibilityIdentifier("BusinessProfileView-Description")
                    }
                }

                HStack {
                    Spacer()
                    Button {
                        if businessName.trimmingCharacters(in: .whitespaces).isEmpty {
                            alertMessage = "Business name is required."
                            showAlert = true
                            BusinessProfileAudit.record(action: "SaveFailed", detail: "No business name")
                        } else if !phoneNumber.isEmpty && !isValidPhone(phoneNumber) {
                            alertMessage = "Please enter a valid phone number."
                            showAlert = true
                            BusinessProfileAudit.record(action: "SaveFailed", detail: "Invalid phone")
                        } else if !email.isEmpty && !isValidEmail(email) {
                            alertMessage = "Please enter a valid email address."
                            showAlert = true
                            BusinessProfileAudit.record(action: "SaveFailed", detail: "Invalid email")
                        } else {
                            alertMessage = "Business profile saved successfully."
                            showAlert = true
                            BusinessProfileAudit.record(action: "Save", detail: "Profile updated")
                        }
                    } label: {
                        Label("Save Profile", systemImage: "checkmark.seal.fill")
                            .fontWeight(.semibold)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 26)
                            .background(Color.accentColor.opacity(0.21))
                            .clipShape(Capsule())
                    }
                    .accessibilityIdentifier("BusinessProfileView-SaveButton")

                    Button {
                        showAuditLog = true
                    } label: {
                        Label("Audit Log", systemImage: "doc.text.magnifyingglass")
                            .font(.caption)
                    }
                    .accessibilityIdentifier("BusinessProfileView-AuditLogButton")
                }
                .padding(.top, 6)
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Business Profile")
        .navigationBarTitleDisplayMode(.inline)
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        }
        .sheet(isPresented: $showAuditLog) {
            NavigationStack {
                List {
                    ForEach(BusinessProfileAuditAdmin.recentEvents(limit: 20), id: \.self) { summary in
                        Text(summary)
                            .font(.caption)
                            .padding(.vertical, 2)
                    }
                }
                .navigationTitle("Audit Log")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Copy") {
                            UIPasteboard.general.string = BusinessProfileAuditAdmin.recentEvents(limit: 20).joined(separator: "\n")
                        }
                        .accessibilityIdentifier("BusinessProfileView-CopyAuditLogButton")
                    }
                }
            }
        }
        .onAppear {
            if !appearedOnce {
                BusinessProfileAudit.record(action: "Appear", detail: "View loaded")
                appearedOnce = true
            }
        }
    }

    // MARK: - Validation Helpers
    private func isValidPhone(_ value: String) -> Bool {
        let digits = value.filter("0123456789".contains)
        return digits.count >= 7 && digits.count <= 15
    }
    private func isValidEmail(_ value: String) -> Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return value.range(of: emailRegex, options: .regularExpression) != nil
    }
}

// MARK: - Section Card Helper

fileprivate struct SectionCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: Color(.black).opacity(0.04), radius: 3, x: 0, y: 1)
            )
            .padding(.horizontal)
            .padding(.vertical, 2)
    }
}

// MARK: - LabeledTextField for Clean UX

fileprivate struct LabeledTextField: View {
    let label: String
    @Binding var text: String
    var systemImage: String? = nil
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .foregroundColor(.accentColor)
            }
            TextField(label, text: $text)
                .keyboardType(keyboardType)
                .textContentType(.name)
                .padding(8)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Audit/Event Logging

fileprivate struct BusinessProfileAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let detail: String
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[BusinessProfileView] \(action): \(detail) at \(df.string(from: timestamp))"
    }
}
fileprivate final class BusinessProfileAudit {
    static private(set) var log: [BusinessProfileAuditEvent] = []
    static func record(action: String, detail: String) {
        let event = BusinessProfileAuditEvent(timestamp: Date(), action: action, detail: detail)
        log.append(event)
        if log.count > 24 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 8) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum BusinessProfileAuditAdmin {
    public static func recentEvents(limit: Int = 8) -> [String] { BusinessProfileAudit.recentSummaries(limit: limit) }
}

#Preview {
    NavigationStack {
        BusinessProfileView()
    }
}
