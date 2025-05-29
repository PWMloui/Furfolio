//
//  AddOnServiceRowView.swift
//  Furfolio
//
//  Created by mac on 5/27/25.
//

import SwiftUI
import os

struct AddOnServiceRowView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "AddOnServiceRowView")
    let service: AddOnService

    var body: some View {
        HStack {
            Text(service.displayName)
                .font(AppTheme.body)
                .foregroundColor(AppTheme.primaryText)
            Spacer()
            Text(service.priceRangeText)
                .font(AppTheme.caption)
                .foregroundColor(AppTheme.secondaryText)
        }
        .padding(.vertical, 8)
        .onAppear {
            logger.log("AddOnServiceRowView appeared for service id: \(service.id), name: \(service.displayName)")
        }
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
