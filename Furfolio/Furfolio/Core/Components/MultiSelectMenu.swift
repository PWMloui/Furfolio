//
//  MultiSelectMenu.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

// MARK: - MultiSelectMenu (Tokenized, Accessible, Modular Multi-Select)

import SwiftUI

/// Represents the type of badge to display for an option.
/// MultiSelectMenu and all related components use ONLY design tokens: AppColors, AppFonts, AppSpacing, BorderRadius, AppShadows,
/// ensuring consistency, accessibility, and modularity.
public enum OptionBadgeType {
    case info
    case warning
    case success
    case critical
}

/// A visual badge view for option tags, color-coded by badge type.
struct OptionBadge: View {
    let type: OptionBadgeType
    let text: String

    var body: some View {
        Text(text)
            .font(AppFonts.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, AppSpacing.small)
            .padding(.vertical, AppSpacing.xsmall)
            .background(backgroundColor)
            .foregroundColor(AppColors.onPrimary)
            .clipShape(RoundedRectangle(cornerRadius: BorderRadius.medium))
            .accessibilityLabel(Text("\(text) badge"))
    }

    private var backgroundColor: Color {
        switch type {
        case .info:
            return AppColors.info
        case .warning:
            return AppColors.warning
        case .success:
            return AppColors.success
        case .critical:
            return AppColors.critical
        }
    }
}

/// Generic Multi-Select Menu for any list of String options, supporting role-based badges,
/// context-aware subtitles, inline banners, and enterprise-grade UX patterns.
/// Selection is two-way-bound to the caller, with a callback for selection changes.
/// Uses design tokens exclusively for styling and layout.
public struct MultiSelectMenu: View {
    /// The title of the multi-select menu.
    public let title: String
    /// The list of options to display.
    public let options: [String]
    /// Binding to the current selection set.
    @Binding public var selection: Set<String>
    /// The system icon name to display for selected options.
    public var icon: String = "checkmark.circle.fill"
    /// Whether to show the "Clear All" button in the sheet toolbar.
    public var showsClearAll: Bool = true
    /// Optional attributed helper text displayed below the title.
    public var helperText: AttributedString? = nil
    /// Optional maximum number of selections allowed.
    public var maxSelection: Int? = nil
    /// Optional dictionary mapping options to subtitles for context-aware display.
    public var optionSubtitles: [String: String]? = nil
    /// Optional dictionary mapping options to badge types for role-based visual badges.
    public var optionBadges: [String: OptionBadgeType]? = nil
    /// Callback invoked whenever the selection changes.
    public var onSelectionChange: ((Set<String>) -> Void)? = nil

    @State private var showSheet = false
    @State private var bannerMessage: AttributedString? = nil
    @State private var bannerType: BannerType = .info

    public init(
        title: String,
        options: [String],
        selection: Binding<Set<String>>,
        icon: String = "checkmark.circle.fill",
        showsClearAll: Bool = true,
        helperText: AttributedString? = nil,
        maxSelection: Int? = nil,
        optionSubtitles: [String: String]? = nil,
        optionBadges: [String: OptionBadgeType]? = nil,
        onSelectionChange: ((Set<String>) -> Void)? = nil
    ) {
        self.title = title
        self.options = options
        self._selection = selection
        self.icon = icon
        self.showsClearAll = showsClearAll
        self.helperText = helperText
        self.maxSelection = maxSelection
        self.optionSubtitles = optionSubtitles
        self.optionBadges = optionBadges
        self.onSelectionChange = onSelectionChange
    }

    public var body: some View {
        VStack(spacing: AppSpacing.xsmall) {
            Button {
                bannerMessage = nil
                showSheet = true
            } label: {
                VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                    Text(title)
                        .font(AppFonts.title)
                        .foregroundColor(AppColors.primary)
                        .accessibilityLabel(Text(title))
                    if let helper = helperText {
                        Text(helper)
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondary)
                            .accessibilityHint(Text(helper.description))
                    }
                    HStack(spacing: AppSpacing.small) {
                        if !selection.isEmpty {
                            Text("\(selection.count) selected")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondary)
                                .accessibilityValue(Text("\(selection.count) selected"))
                        } else {
                            Text("None selected")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondary)
                                .accessibilityValue(Text("No selections"))
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .imageScale(.small)
                            .foregroundColor(AppColors.accent)
                    }
                }
                .padding(.vertical, AppSpacing.medium)
                .padding(.horizontal, AppSpacing.medium)
                .background(AppColors.backgroundSecondary)
                .cornerRadius(BorderRadius.medium)
                .contentShape(Rectangle())
                .accessibilityAddTraits(.isButton)
            }
            .accessibilityElement(children: .combine)

            if let bannerMessage = bannerMessage {
                BannerView(message: bannerMessage, type: bannerType)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .accessibilityLiveRegion(.polite)
            }
        }
        .sheet(isPresented: $showSheet) {
            NavigationView {
                List {
                    ForEach(options, id: \.self) { option in
                        MultipleSelectionRow(
                            option: option,
                            subtitle: optionSubtitles?[option],
                            badgeType: optionBadges?[option],
                            isSelected: selection.contains(option),
                            icon: icon,
                            action: {
                                toggle(option)
                            }
                        )
                        .padding(.vertical, AppSpacing.medium)
                        .contentShape(Rectangle())
                        .accessibilityElement(children: .combine)
                    }
                }
                .formStyle(.grouped)
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if showsClearAll && !selection.isEmpty {
                            Button("Clear All") {
                                selection.removeAll()
                                onSelectionChange?(selection)
                            }
                            .accessibilityLabel(Text("Clear all selections"))
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showSheet = false
                        }
                        .bold()
                        .accessibilityLabel(Text("Done"))
                    }
                }
            }
            .onAppear {
                bannerMessage = nil
            }
        }
        .animation(.default, value: bannerMessage)
    }

    private func toggle(_ option: String) {
        if selection.contains(option) {
            selection.remove(option)
            onSelectionChange?(selection)
            bannerMessage = nil
        } else {
            if let max = maxSelection, selection.count >= max {
                bannerMessage = AttributedString("You can select up to \(max) items.")
                bannerType = .warning
            } else {
                selection.insert(option)
                onSelectionChange?(selection)
                bannerMessage = nil
            }
        }
    }
}

/// Row with a checkmark for selected options, supports subtitles and role-based badges.
/// Uses design tokens for all styling and layout.
struct MultipleSelectionRow: View {
    let option: String
    let subtitle: String?
    let badgeType: OptionBadgeType?
    let isSelected: Bool
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                HStack(spacing: AppSpacing.small) {
                    Text(option)
                        .foregroundColor(AppColors.primary)
                        .font(AppFonts.body)
                        .lineLimit(1)
                        .accessibilityLabel(Text(option))
                    if let badgeType = badgeType {
                        OptionBadge(type: badgeType, text: badgeText(for: option))
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: icon)
                            .foregroundColor(AppColors.accent)
                            .accessibilityLabel(Text("Selected"))
                    }
                }
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.secondary)
                        .lineLimit(2)
                        .accessibilityHint(Text(subtitle))
                }
            }
            .padding(.vertical, AppSpacing.medium)
            .padding(.horizontal, AppSpacing.medium)
            .contentShape(Rectangle())
        }
        .accessibilityValue(Text(isSelected ? "Selected" : "Not selected"))
        .accessibilityAddTraits(.isButton)
    }

    private func badgeText(for option: String) -> String {
        switch option.lowercased() {
        case "vip":
            return "VIP"
        case "allergic":
            return "Allergic"
        case "aggressive":
            return "Aggressive"
        default:
            switch badgeType {
            case .info:
                return "Info"
            case .warning:
                return "Warning"
            case .success:
                return "Success"
            case .critical:
                return "Critical"
            case .none:
                return ""
            }
        }
    }
}

/// Banner types for inline messages.
enum BannerType {
    case info
    case warning
    case error

    var backgroundColor: Color {
        switch self {
        case .info:
            return AppColors.infoBackground
        case .warning:
            return AppColors.warningBackground
        case .error:
            return AppColors.criticalBackground
        }
    }

    var foregroundColor: Color {
        switch self {
        case .info:
            return AppColors.info
        case .warning:
            return AppColors.warning
        case .error:
            return AppColors.critical
        }
    }
}

/// Inline banner view for displaying system error/info messages.
/// Uses design tokens exclusively for styling and layout.
struct BannerView: View {
    let message: AttributedString
    let type: BannerType

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.small) {
            Image(systemName: iconName)
                .foregroundColor(type.foregroundColor)
                .imageScale(.medium)
            Text(message)
                .font(AppFonts.caption)
                .foregroundColor(type.foregroundColor)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(AppSpacing.medium)
        .background(type.backgroundColor)
        .cornerRadius(BorderRadius.medium)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(message.description))
    }

    private var iconName: String {
        switch type {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.octagon"
        }
    }
}

// MARK: - Preview

#Preview {
    @State var selected: Set<String> = ["Sensitive Skin", "VIP"]

    var helperText: AttributedString {
        var attr = AttributedString("Select all applicable tags for your profile.")
        attr.foregroundColor = AppColors.secondary
        attr.font = AppFonts.caption
        return attr
    }

    let optionSubtitles = [
        "Sensitive Skin": "Requires gentle products",
        "Aggressive": "Handle with care",
        "Timid": "Easily startled",
        "Needs Special Shampoo": "Use hypoallergenic shampoo",
        "Allergic": "Avoid certain allergens",
        "VIP": "High priority client"
    ]

    let optionBadges: [String: OptionBadgeType] = [
        "VIP": .critical,
        "Allergic": .critical,
        "Aggressive": .warning,
        "Needs Special Shampoo": .info,
        "Sensitive Skin": .success
    ]

    return MultiSelectMenu(
        title: "Tags",
        options: ["Sensitive Skin", "Aggressive", "Timid", "Needs Special Shampoo", "Allergic", "VIP"],
        selection: $selected,
        icon: "checkmark.seal.fill",
        showsClearAll: true,
        helperText: helperText,
        maxSelection: 3,
        optionSubtitles: optionSubtitles,
        optionBadges: optionBadges,
        onSelectionChange: { newSelection in
            print("Selection changed to: \(newSelection)")
        }
    )
    .padding(AppSpacing.medium)
}
