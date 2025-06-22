//
//  OwnerPreferencesView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct OwnerPreferencesView: View {
    @Binding var favoriteGroomingStyle: String
    @Binding var preferredShampoo: String
    @Binding var specialRequests: String

    var body: some View {
        Form {
            Section(header: Text("Grooming Preferences")) {
                TextField("Favorite Grooming Style", text: $favoriteGroomingStyle)
                    .autocapitalization(.words)
                    .disableAutocorrection(true)

                TextField("Preferred Shampoo", text: $preferredShampoo)
                    .autocapitalization(.words)
                    .disableAutocorrection(true)
            }

            Section(header: Text("Special Requests")) {
                TextEditor(text: $specialRequests)
                    .frame(height: 80)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .navigationTitle("Owner Preferences")
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
