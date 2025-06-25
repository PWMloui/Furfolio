//
//  SectionHeaderView.swift
//  Furfolio
//
//  Enhanced: analytics/audit–ready, token-compliant, accessible, preview/test–injectable.
//

import SwiftUI

// MARK: - Analytics/Audit Protocol

public protocol SectionHeaderAnalyticsLogger {
    func log(event: String, info: [String: Any]?)
}
public struct NullSectionHeaderAnalyticsLogger: SectionHeaderAnalyticsLogger {
    public init() {}
    public func log(event: String, info: [String: Any]?) {}
}

// MARK: - SectionHeaderView (Enterprise Enhanced)

struct SectionHeaderView: View {
    /// The title to be displayed.
    let title: LocalizedStringKey

    /// The optional label for a trailing action button (e.g., "See All").
    var actionLabel: LocalizedStringKey? = nil

    /// The optional closure to be executed when the action button is tapped.
    var action: (() -> Void)? = nil

    /// Analytics logger (swap in QA/print/Trust Center/test)
    static var analyticsLogger: SectionHeaderAnalyticsLogger = NullSectionHeaderAnalyticsLogger()

    var body: some View {
        HStack {
            Text(title)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
                .textCase(.uppercase)
                .accessibilityLabel(Text("\(title) section header"))
                .accessibilityAddTraits(.isHeader)

            Spacer()

            if let actionLabel = actionLabel, let action = action {
                Button(action: {
                    Self.analyticsLogger.log(event: "section_action_tapped", info: [
                        "title": "\(title)",
                        "actionLabel": "\(actionLabel)"
                    ])
                    action()
                }) {
                    Text(actionLabel)
                        .font(AppFonts.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primary)
                        .padding(.leading, AppSpacing.small)
                }
                .accessibilityLabel(Text(actionLabel))
                .accessibilityHint(Text("Tap to \(actionLabel)."))
            }
        }
        .padding(.bottom, AppSpacing.small)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("SectionHeaderView_\(title)")
        .onAppear {
            Self.analyticsLogger.log(event: "section_header_rendered", info: [
                "title": "\(title)",
                "actionLabel": actionLabel != nil ? "\(actionLabel!)" : nil
            ])
        }
    }
}

// MARK: - Preview with analytics logger

#if DEBUG
struct SectionHeaderView_Previews: PreviewProvider {
    struct SpyLogger: SectionHeaderAnalyticsLogger {
        func log(event: String, info: [String : Any]?) {
            print("[SectionHeaderAnalytics] \(event): \(info ?? [:])")
        }
    }
    static var previews: some View {
        SectionHeaderView.analyticsLogger = SpyLogger()
        return Form {
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
