//
//  SectionHeaderView.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//
//  ENHANCED: A reusable, theme-aware section header with an optional action button.
//

import SwiftUI

// MARK: - SectionHeaderView (Tokenized, Reusable, Accessible Section Header)

/// A standardized header view for use in `List` or `Form` sections.
/// It displays a title and an optional trailing action button.
/// All styling uses ONLY modular tokens (`AppColors`, `AppFonts`, `AppSpacing`).
/// This is a universal, accessible section header for lists/forms with optional trailing action.
struct SectionHeaderView: View {
    /// The title to be displayed.
    let title: LocalizedStringKey
    
    /// The optional label for a trailing action button (e.g., "See All").
    var actionLabel: LocalizedStringKey? = nil
    
    /// The optional closure to be executed when the action button is tapped.
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
                .textCase(.uppercase) // A common style for section headers

            Spacer()

            // Only show the button if both an action and a label are provided
            if let actionLabel = actionLabel, let action = action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(AppFonts.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primary)
                        .padding(.leading, AppSpacing.small)
                }
            }
        }
        .padding(.bottom, AppSpacing.small)
        .accessibilityElement(children: .combine)
    }
}


// MARK: - Preview

#if DEBUG
struct SectionHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        Form {
            Section(
                header: SectionHeaderView(title: "Upcoming Appointments")
            ) {
                Text("Appointment 1 Row")
                Text("Appointment 2 Row")
            }

            Section(
                header: SectionHeaderView(title: "Recent Activity", actionLabel: "See All") {
                    print("See All tapped!")
                }
            ) {
                Text("Activity 1 Row")
                Text("Activity 2 Row")
            }
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
