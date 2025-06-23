//
//  OwnerRetentionTagView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//
//  ENHANCED: Refactored to be a 'dumb' view that relies on the
//  CustomerRetentionAnalyzer for all business logic, ensuring a single
//  source of truth for retention status.
//

import SwiftUI

/// A view that displays a retention status tag for a DogOwner.
/// It determines the appropriate tag by using the centralized CustomerRetentionAnalyzer.
struct OwnerRetentionTagView: View {
    let owner: DogOwner

    /// The single source of truth for retention logic.
    private let analyzer = CustomerRetentionAnalyzer.shared

    var body: some View {
        // Calculate the retention tag using the centralized analyzer.
        let tag = analyzer.retentionTag(for: owner)

        // The view now simply renders the tag provided by the analyzer.
        // All styling uses design system tokens.
        Label {
            Text(tag.label)
                .font(AppFonts.caption)
        } icon: {
            Image(systemName: tag.icon.symbol)
        }
        .foregroundColor(tag.color)
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, AppSpacing.small)
        .background(tag.color.opacity(0.13))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Retention Status: \(tag.label)")
    }
}


// MARK: - Preview

#if DEBUG
@available(iOS 18.0, *)
struct OwnerRetentionTagView_Previews: PreviewProvider {
    static var previews: some View {
        // Sample owners representing each retention status for the preview.
        let newOwner = DogOwner(ownerName: "New Owner")
        
        let activeOwner = DogOwner(ownerName: "Active Owner")
        activeOwner.appointments = [Appointment(date: Date().addingTimeInterval(-20 * 86400), serviceType: .fullGroom)]
        
        let returningOwner = DogOwner(ownerName: "Returning Owner")
        returningOwner.appointments = [
            Appointment(date: Date().addingTimeInterval(-100 * 86400), serviceType: .fullGroom),
            Appointment(date: Date().addingTimeInterval(-45 * 86400), serviceType: .fullGroom)
        ]
        
        let riskOwner = DogOwner(ownerName: "Risk Owner")
        riskOwner.appointments = [Appointment(date: Date().addingTimeInterval(-75 * 86400), serviceType: .nailTrim)]
        
        let inactiveOwner = DogOwner(ownerName: "Inactive Owner")
        inactiveOwner.appointments = [Appointment(date: Date().addingTimeInterval(-200 * 86400), serviceType: .fullGroom)]
        
        return VStack(alignment: .leading, spacing: 18) {
            OwnerRetentionTagView(owner: newOwner)
            OwnerRetentionTagView(owner: activeOwner)
            OwnerRetentionTagView(owner: returningOwner)
            OwnerRetentionTagView(owner: riskOwner)
            OwnerRetentionTagView(owner: inactiveOwner)
        }
        .padding()
        .background(AppColors.background)
        .previewLayout(.sizeThatFits)
    }
}
#endif

