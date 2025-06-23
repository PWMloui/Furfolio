//
//  OwnerContactQuickActionsView.swift
//  Furfolio
//
//  (MODIFIED)
//

import SwiftUI

struct OwnerContactQuickActionsView: View {
    let phoneNumber: String?
    let email: String?
    let address: String?

    // --- NEW: A sample message template ---
    // You can make this configurable in your app's settings.
    let messageTemplate = "Hi! This is a friendly reminder about your upcoming appointment with Furfolio."

    var body: some View {
        HStack(spacing: 24) {
            // Call Button (no changes)
            if let phone = phoneNumber, !phone.isEmpty, let url = URL(string: "tel://\(phone.onlyDigits)") {
                Link(destination: url) {
                    VStack {
                        Image(systemName: "phone.fill")
                            .font(.title)
                        Text("Call")
                            .font(.caption)
                    }
                }
                .accessibilityLabel("Call \(phone)")
            }

            // --- MODIFIED: Message Button ---
            if let phone = phoneNumber, !phone.isEmpty {
                Button(action: {
                    // This action now constructs and opens the SMS URL
                    openMessages(with: phone, body: messageTemplate)
                }) {
                    VStack {
                        Image(systemName: "message.fill")
                            .font(.title)
                        Text("Message")
                            .font(.caption)
                    }
                }
                .accessibilityLabel("Send a message to \(phone)")
            }

            // Email Button (no changes)
            // ...

            // Address Button (no changes)
            // ...
        }
        .padding(.vertical, 8)
    }
    
    // --- NEW: Helper function to open the Messages app ---
    private func openMessages(with recipient: String, body: String) {
        let cleanPhoneNumber = recipient.onlyDigits
        
        // URL-encode the message body to handle spaces and special characters
        guard let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let smsUrl = URL(string: "sms:\(cleanPhoneNumber)&body=\(encodedBody)") else {
            print("Could not create SMS URL")
            return
        }
        
        // Check if the device can open the URL scheme and open it
        if UIApplication.shared.canOpenURL(smsUrl) {
            UIApplication.shared.open(smsUrl)
        } else {
            // Handle cases where SMS is not available (e.g., on an iPad without a SIM)
            print("Device cannot send SMS.")
            // You could show an alert to the user here.
        }
    }
}

// Helper extension to strip non-digit characters from phone number
extension String {
    var onlyDigits: String {
        filter("0123456789".contains)
    }
}

#Preview {
    OwnerContactQuickActionsView(
        phoneNumber: "555-123-4567",
        email: "demo@example.com",
        address: "123 Main St, Anytown, USA"
    )
}
