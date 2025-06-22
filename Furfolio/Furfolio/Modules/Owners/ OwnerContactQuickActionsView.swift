//
//   OwnerContactQuickActionsView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct OwnerContactQuickActionsView: View {
    let phoneNumber: String?
    let email: String?
    let address: String?

    var body: some View {
        HStack(spacing: 24) {
            // Call Button
            if let phone = phoneNumber, !phone.isEmpty {
                Button(action: {
                    if let url = URL(string: "tel://\(phone.onlyDigits)") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    VStack {
                        Image(systemName: "phone.fill")
                            .font(.title)
                        Text("Call")
                            .font(.caption)
                    }
                }
                .accessibilityLabel("Call \(phone)")
            }

            // Email Button
            if let email = email, !email.isEmpty {
                Button(action: {
                    if let url = URL(string: "mailto:\(email)") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    VStack {
                        Image(systemName: "envelope.fill")
                            .font(.title)
                        Text("Email")
                            .font(.caption)
                    }
                }
                .accessibilityLabel("Email \(email)")
            }

            // Address Button (opens in Maps)
            if let address = address, !address.isEmpty {
                Button(action: {
                    let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if let url = URL(string: "http://maps.apple.com/?q=\(encoded)") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    VStack {
                        Image(systemName: "map.fill")
                            .font(.title)
                        Text("Map")
                            .font(.caption)
                    }
                }
                .accessibilityLabel("Open address in Maps")
            }
        }
        .padding(.vertical, 8)
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
