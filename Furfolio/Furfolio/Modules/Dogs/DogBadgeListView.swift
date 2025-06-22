//
//  DogBadgeListView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct DogBadgeListView: View {
    let badges: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(badges, id: \.self) { badge in
                    Text(badge)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.accentColor.opacity(0.2))
                        )
                        .foregroundColor(Color.accentColor)
                        .accessibilityLabel("Badge: \(badge)")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

#if DEBUG
struct DogBadgeListView_Previews: PreviewProvider {
    static var previews: some View {
        DogBadgeListView(badges: ["Calm", "Friendly", "Needs Shampoo", "Allergic"])
            .previewLayout(.sizeThatFits)
    }
}
#endif
