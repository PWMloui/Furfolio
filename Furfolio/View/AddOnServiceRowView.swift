//
//  AddOnServiceRowView.swift
//  Furfolio
//
//  Created by mac on 5/27/25.
//

import SwiftUI

struct AddOnServiceRowView: View {
    let service: AddOnService

    var body: some View {
        HStack {
            Text(service.displayName)
                .font(.body)
            Spacer()
            Text(service.priceRangeText)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct AddOnServiceRowView_Previews: PreviewProvider {
    static var previews: some View {
        // Assuming AddOnService has an initializer for previews; adjust if needed
        let sample = AddOnService(id: UUID(), displayName: "Bath", minPrice: 40, maxPrice: 85, requires: [])
        return AddOnServiceRowView(service: sample)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
