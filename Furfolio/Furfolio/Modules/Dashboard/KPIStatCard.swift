//
//  KPIStatCard.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  ENHANCED: Refactored to use AppTheme for consistent styling.

import SwiftUI

struct KPIStatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let systemIconName: String
    let iconBackgroundColor: Color

    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) { // BEFORE: 16
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 50, height: 50)
                Image(systemName: systemIconName)
                    .foregroundColor(.white)
                    .font(.system(size: 24, weight: .medium))
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) { // BEFORE: 4
                Text(title)
                    .font(AppTheme.Fonts.headline) // BEFORE: .headline
                    .foregroundColor(AppTheme.Colors.textPrimary) // BEFORE: .primary

                Text(value)
                    .font(AppTheme.Fonts.title) // BEFORE: .title2.bold()
                    .foregroundColor(AppTheme.Colors.textPrimary) // BEFORE: .primary

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppTheme.Fonts.caption) // BEFORE: .subheadline
                        .foregroundColor(AppTheme.Colors.textSecondary) // BEFORE: .secondary
                }
            }
            Spacer()
        }
        .padding(AppTheme.Spacing.card) // BEFORE: padding()
        .background(
            RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large) // BEFORE: 18
                .fill(AppTheme.Colors.card) // BEFORE: Color(.secondarySystemBackground)
                .appShadow(AppTheme.Shadows.card) // BEFORE: .shadow(...)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), value \(value)\(subtitle != nil ? ", \(subtitle!)" : "")")
    }
}

#if DEBUG
struct KPIStatCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            KPIStatCard(
                title: "Total Revenue",
                value: "$12,345",
                subtitle: "This month",
                systemIconName: "dollarsign.circle.fill",
                iconBackgroundColor: .green
            )
            KPIStatCard(
                title: "Upcoming Appointments",
                value: "5",
                subtitle: "Next 7 days",
                systemIconName: "calendar",
                iconBackgroundColor: .blue
            )
            KPIStatCard(
                title: "Inactive Customers",
                value: "3",
                subtitle: nil,
                systemIconName: "person.fill.xmark",
                iconBackgroundColor: .red
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
