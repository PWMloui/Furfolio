//
//  BusinessProfileView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct BusinessProfileView: View {
    @State private var businessName: String = "Your Grooming Business"
    @State private var ownerName: String = "Business Owner"
    @State private var phoneNumber: String = ""
    @State private var email: String = ""
    @State private var address: String = ""
    @State private var description: String = "We care for your pets like family!"

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Logo/avatar section
                Image(systemName: "pawprint.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(.accent)
                    .padding(.top, 28)

                VStack(alignment: .leading, spacing: 12) {
                    TextField("Business Name", text: $businessName)
                        .font(.title2.bold())
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    TextField("Owner Name", text: $ownerName)
                        .font(.headline)
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    TextField("Address", text: $address)
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Business Description")
                        .font(.headline)
                        .padding(.bottom, 2)
                    TextEditor(text: $description)
                        .frame(height: 100)
                        .padding(4)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal)

                Spacer()
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Business Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        BusinessProfileView()
    }
}
