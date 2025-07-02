//
//  MultiSelectMenu.swift
//  Furfolio
//
//  Enhanced: analytics/audit–ready, Trust Center–ready, test/preview-injectable, robust accessibility.
//

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct MultiSelectMenuAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "MultiSelectMenu"
}

// MARK: - Analytics/Audit Protocol
/// Protocol for analytics/audit logging. Implementations can log events to any backend or buffer.
public protocol MultiSelectMenuAnalyticsLogger: AnyObject {
    var testMode: Bool { get set }
    func log(
        event: String,
        info: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}
/// Null logger for tests/previews: no-op, but conforms to protocol.
public final class NullMultiSelectMenuAnalyticsLogger: MultiSelectMenuAnalyticsLogger {
    public init() {}
    public var testMode: Bool = false
    public func log(
        event: String,
        info: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("[MultiSelectMenuAnalytics][null logger] \(event) info:\(info ?? [:]) role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
        }
    }
}

// MARK: - Trust Center Permission Protocol

/// Protocol for Trust Center permission checks. Implement to enforce business logic or compliance.
public protocol MultiSelectMenuTrustCenterDelegate: AnyObject {
    func permission(for action: String, option: String?, context: [String: Any]?) -> Bool
}
public final class NullMultiSelectMenuTrustCenterDelegate: MultiSelectMenuTrustCenterDelegate {
    public init() {}
    public func permission(for action: String, option: String?, context: [String: Any]?) -> Bool { true }
}

// MARK: - OptionBadgeType (Unchanged)
public enum OptionBadgeType {
    case info
    case warning
    case success
    case critical
}

// MARK: - OptionBadge (Unchanged)
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
            .accessibilityLabel(Text(
                String(format: NSLocalizedString("option_badge_accessibility_label", value: "%@ badge", comment: "Accessibility label for option badge"), text)
            ))
    }

    private var backgroundColor: Color {
        switch type {
        case .info:     return AppColors.info
        case .warning:  return AppColors.warning
        case .success:  return AppColors.success
        case .critical: return AppColors.critical
        }
    }
}

// MARK: - MultiSelectMenu (Enhanced)

public struct MultiSelectMenu: View {
    public let title: String
    public let options: [String]
    @Binding public var selection: Set<String>
    public var icon: String = "checkmark.circle.fill"
    public var showsClearAll: Bool = true
    public var helperText: AttributedString? = nil
    public var maxSelection: Int? = nil
    public var optionSubtitles: [String: String]? = nil
    public var optionBadges: [String: OptionBadgeType]? = nil
    public var onSelectionChange: ((Set<String>) -> Void)? = nil

    public static var analyticsLogger: MultiSelectMenuAnalyticsLogger = NullMultiSelectMenuAnalyticsLogger()
    public static var trustCenterDelegate: MultiSelectMenuTrustCenterDelegate = NullMultiSelectMenuTrustCenterDelegate()

    private static var analyticsEventBuffer: [(date: Date, event: String, info: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
    private static let bufferQueue = DispatchQueue(label: "MultiSelectMenu.analyticsBufferQueue")

    public static func recentAnalyticsEvents() -> [(date: Date, event: String, info: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] {
        bufferQueue.sync { analyticsEventBuffer }
    }

    @State private var showSheet = false
    @State private var bannerMessage: AttributedString? = nil
    @State private var bannerType: BannerType = .info
    @State private var diagnosticsEvents: [(Date, String, [String: Any]?, String?, String?, String?, Bool)] = []

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
                logAndBuffer(event: NSLocalizedString("msm_event_open_menu", value: "open_menu", comment: "Analytics event: open menu"), info: ["title": title])
                updateDiagnosticsBuffer()
            } label: {
                VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                    Text(NSLocalizedString("msm_title", value: title, comment: "MultiSelectMenu title"))
                        .font(AppFonts.title)
                        .foregroundColor(AppColors.primary)
                        .accessibilityLabel(Text(NSLocalizedString("msm_title_accessibility", value: title, comment: "Accessibility label for menu title")))
                    if let helper = helperText {
                        Text(helper)
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondary)
                            .accessibilityHint(Text(helper.description))
                    }
                    HStack(spacing: AppSpacing.small) {
                        if !selection.isEmpty {
                            let countString = String.localizedStringWithFormat(
                                NSLocalizedString("msm_selected_count", value: "%d selected", comment: "X items selected"), selection.count)
                            Text(countString)
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondary)
                                .accessibilityValue(Text(countString))
                        } else {
                            let noneString = NSLocalizedString("msm_none_selected", value: "None selected", comment: "No items selected")
                            Text(noneString)
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondary)
                                .accessibilityValue(Text(
                                    NSLocalizedString("msm_no_selections", value: "No selections", comment: "Accessibility value for no selections")
                                ))
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
            // Diagnostics: Show recent analytics events if in testMode
            if let logger = Self.analyticsLogger as? MultiSelectMenuAnalyticsLogger, logger.testMode {
                DiagnosticsBufferView(events: diagnosticsEvents)
                    .onAppear { updateDiagnosticsBuffer() }
                    .onChange(of: showSheet) { _ in updateDiagnosticsBuffer() }
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
                .navigationTitle(NSLocalizedString("msm_nav_title", value: title, comment: "Navigation title for menu"))
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if showsClearAll && !selection.isEmpty {
                            Button(NSLocalizedString("msm_clear_all", value: "Clear All", comment: "Clear all selections")) {
                                guard Self.trustCenterDelegate.permission(for: "clear_all", option: nil, context: ["title": title]) else {
                                    showBanner(NSLocalizedString("msm_clear_all_denied", value: "You do not have permission to clear all.", comment: "Clear all denied message"), .error)
                                    logAndBuffer(event: NSLocalizedString("msm_event_clear_all_denied", value: "clear_all_denied", comment: "Analytics event: clear all denied"), info: ["title": title])
                                    updateDiagnosticsBuffer()
                                    return
                                }
                                selection.removeAll()
                                onSelectionChange?(selection)
                                logAndBuffer(event: NSLocalizedString("msm_event_clear_all", value: "clear_all", comment: "Analytics event: clear all"), info: ["title": title])
                                showBanner(NSLocalizedString("msm_all_cleared", value: "All selections cleared.", comment: "All selections cleared banner"), .info)
                                updateDiagnosticsBuffer()
                            }
                            .accessibilityLabel(Text(NSLocalizedString("msm_clear_all_accessibility", value: "Clear all selections", comment: "Accessibility label for clear all")))
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(NSLocalizedString("msm_done", value: "Done", comment: "Done button")) {
                            showSheet = false
                            logAndBuffer(event: NSLocalizedString("msm_event_close_menu", value: "close_menu", comment: "Analytics event: close menu"), info: ["title": title])
                            updateDiagnosticsBuffer()
                        }
                        .bold()
                        .accessibilityLabel(Text(NSLocalizedString("msm_done_accessibility", value: "Done", comment: "Accessibility label for done button")))
                    }
                }
            }
            .onAppear {
                bannerMessage = nil
            }
        }
        .animation(.default, value: bannerMessage)
    }

    /// Toggle the selection state of an option, with permission and analytics hooks.
    private func toggle(_ option: String) {
        guard Self.trustCenterDelegate.permission(for: "toggle", option: option, context: ["title": title]) else {
            let deniedMsg = String(format: NSLocalizedString("msm_toggle_denied", value: "You do not have permission to modify \"%@\".", comment: "Toggle denied message"), option)
            showBanner(deniedMsg, .error)
            logAndBuffer(event: NSLocalizedString("msm_event_toggle_denied", value: "toggle_denied", comment: "Analytics event: toggle denied"), info: ["option": option, "title": title])
            updateDiagnosticsBuffer()
            return
        }
        if selection.contains(option) {
            selection.remove(option)
            onSelectionChange?(selection)
            bannerMessage = nil
            logAndBuffer(event: NSLocalizedString("msm_event_deselect_option", value: "deselect_option", comment: "Analytics event: deselect option"), info: ["option": option, "title": title])
            updateDiagnosticsBuffer()
        } else {
            if let max = maxSelection, selection.count >= max {
                let maxMsg = String(format: NSLocalizedString("msm_max_selection", value: "You can select up to %d items.", comment: "Max selection banner"), max)
                showBanner(maxMsg, .warning)
                logAndBuffer(event: NSLocalizedString("msm_event_max_selection", value: "max_selection", comment: "Analytics event: max selection"), info: ["option": option, "title": title, "max": max])
                updateDiagnosticsBuffer()
            } else {
                selection.insert(option)
                onSelectionChange?(selection)
                bannerMessage = nil
                logAndBuffer(event: NSLocalizedString("msm_event_select_option", value: "select_option", comment: "Analytics event: select option"), info: ["option": option, "title": title])
                updateDiagnosticsBuffer()
            }
        }
    }

    /// Shows a banner with a localized message and type.
    private func showBanner(_ message: String, _ type: BannerType) {
        bannerMessage = AttributedString(message)
        bannerType = type
    }

    /// Logs an analytics event and appends to diagnostics buffer, with full audit context.
    private func logAndBuffer(event: String, info: [String: Any]?) {
        Task {
            let escalate = event.lowercased().contains("danger") || event.lowercased().contains("critical") || event.lowercased().contains("delete") ||
                (info?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)
            await Self.analyticsLogger.log(
                event: event,
                info: info,
                role: MultiSelectMenuAuditContext.role,
                staffID: MultiSelectMenuAuditContext.staffID,
                context: MultiSelectMenuAuditContext.context,
                escalate: escalate
            )
            Self.bufferQueue.sync {
                Self.analyticsEventBuffer.append((Date(), event, info, MultiSelectMenuAuditContext.role, MultiSelectMenuAuditContext.staffID, MultiSelectMenuAuditContext.context, escalate))
                if Self.analyticsEventBuffer.count > 20 {
                    Self.analyticsEventBuffer.removeFirst(Self.analyticsEventBuffer.count - 20)
                }
            }
        }
    }

    /// Updates the diagnosticsEvents state for diagnostics buffer rendering.
    private func updateDiagnosticsBuffer() {
        diagnosticsEvents = Self.recentAnalyticsEvents()
    }
}

// MARK: - MultipleSelectionRow (Unchanged except for analytics, accessibility, and audit hooks)

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
                    Text(NSLocalizedString("msm_option_\(option)", value: option, comment: "Menu option"))
                        .foregroundColor(AppColors.primary)
                        .font(AppFonts.body)
                        .lineLimit(1)
                        .accessibilityLabel(Text(NSLocalizedString("msm_option_accessibility_\(option)", value: option, comment: "Accessibility label for option")))
                    if let badgeType = badgeType {
                        OptionBadge(type: badgeType, text: badgeText(for: option))
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: icon)
                            .foregroundColor(AppColors.accent)
                            .accessibilityLabel(Text(NSLocalizedString("msm_selected", value: "Selected", comment: "Accessibility label for selected")))
                    }
                }
                if let subtitle = subtitle {
                    Text(NSLocalizedString("msm_option_subtitle_\(option)", value: subtitle, comment: "Option subtitle"))
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
        .accessibilityValue(Text(isSelected
            ? NSLocalizedString("msm_selected", value: "Selected", comment: "Accessibility value for selected")
            : NSLocalizedString("msm_not_selected", value: "Not selected", comment: "Accessibility value for not selected")
        ))
        .accessibilityAddTraits(.isButton)
    }

    private func badgeText(for option: String) -> String {
        switch option.lowercased() {
        case "vip":
            return NSLocalizedString("msm_badge_vip", value: "VIP", comment: "VIP badge")
        case "allergic":
            return NSLocalizedString("msm_badge_allergic", value: "Allergic", comment: "Allergic badge")
        case "aggressive":
            return NSLocalizedString("msm_badge_aggressive", value: "Aggressive", comment: "Aggressive badge")
        default:
            switch badgeType {
            case .info:     return NSLocalizedString("msm_badge_info", value: "Info", comment: "Info badge")
            case .warning:  return NSLocalizedString("msm_badge_warning", value: "Warning", comment: "Warning badge")
            case .success:  return NSLocalizedString("msm_badge_success", value: "Success", comment: "Success badge")
            case .critical: return NSLocalizedString("msm_badge_critical", value: "Critical", comment: "Critical badge")
            case .none:     return ""
            }
        }
    }
}

// MARK: - BannerType/BannerView (Unchanged)
enum BannerType {
    case info
    case warning
    case error

    var backgroundColor: Color {
        switch self {
        case .info:    return AppColors.infoBackground
        case .warning: return AppColors.warningBackground
        case .error:   return AppColors.criticalBackground
        }
    }
    var foregroundColor: Color {
        switch self {
        case .info:    return AppColors.info
        case .warning: return AppColors.warning
        case .error:   return AppColors.critical
        }
    }
}

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
        case .info:    return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error:   return "xmark.octagon"
        }
    }
}

// MARK: - Diagnostics Buffer View
struct DiagnosticsBufferView: View {
    let events: [(Date, String, [String: Any]?, String?, String?, String?, Bool)]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Diagnostics Buffer (last \(events.count) events):")
                .font(.caption).bold()
            ForEach(Array(events.enumerated()), id: \.offset) { idx, event in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(event.0, formatter: diagnosticsDateFormatter) • \(event.1)")
                        .font(.caption2)
                    if let info = event.2 {
                        Text(info.map { "\($0): \($1)" }.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("role: \(event.3 ?? "-")")
                        Text("staffID: \(event.4 ?? "-")")
                        Text("context: \(event.5 ?? "-")")
                        Text("escalate: \(event.6 ? "YES" : "NO")")
                    }
                    .font(.caption2)
                    .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Diagnostics buffer"))
    }
    private var diagnosticsDateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .none
        df.timeStyle = .medium
        return df
    }
}

// MARK: - Preview
#Preview {
    final class SpyLogger: MultiSelectMenuAnalyticsLogger {
        var testMode: Bool = true
        private(set) var events: [(String, [String: Any]?, String?, String?, String?, Bool)] = []
        func log(
            event: String,
            info: [String : Any]?,
            role: String?,
            staffID: String?,
            context: String?,
            escalate: Bool
        ) async {
            if testMode {
                print("[MultiSelectMenuAnalytics][testMode] \(event): \(info ?? [:]) role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
            }
            events.append((event, info, role, staffID, context, escalate))
        }
    }
    final class SpyTrustCenter: MultiSelectMenuTrustCenterDelegate {
        func permission(for action: String, option: String?, context: [String : Any]?) -> Bool {
            if action == "toggle", option == "VIP" { return false }
            return true
        }
    }
    @State var selected: Set<String> = ["Sensitive Skin", "VIP"]

    var helperText: AttributedString {
        var attr = AttributedString(NSLocalizedString("msm_helper_text", value: "Select all applicable tags for your profile.", comment: "Helper text for menu"))
        attr.foregroundColor = AppColors.secondary
        attr.font = AppFonts.caption
        return attr
    }

    let optionSubtitles = [
        "Sensitive Skin": NSLocalizedString("msm_subtitle_sensitive_skin", value: "Requires gentle products", comment: "Subtitle for Sensitive Skin"),
        "Aggressive": NSLocalizedString("msm_subtitle_aggressive", value: "Handle with care", comment: "Subtitle for Aggressive"),
        "Timid": NSLocalizedString("msm_subtitle_timid", value: "Easily startled", comment: "Subtitle for Timid"),
        "Needs Special Shampoo": NSLocalizedString("msm_subtitle_special_shampoo", value: "Use hypoallergenic shampoo", comment: "Subtitle for Special Shampoo"),
        "Allergic": NSLocalizedString("msm_subtitle_allergic", value: "Avoid certain allergens", comment: "Subtitle for Allergic"),
        "VIP": NSLocalizedString("msm_subtitle_vip", value: "High priority client", comment: "Subtitle for VIP")
    ]
    let optionBadges: [String: OptionBadgeType] = [
        "VIP": .critical,
        "Allergic": .critical,
        "Aggressive": .warning,
        "Needs Special Shampoo": .info,
        "Sensitive Skin": .success
    ]

    let logger = SpyLogger()
    let trust = SpyTrustCenter()
    MultiSelectMenu.analyticsLogger = logger
    MultiSelectMenu.trustCenterDelegate = trust
    return VStack(spacing: 16) {
        MultiSelectMenu(
            title: NSLocalizedString("msm_tags_title", value: "Tags", comment: "Menu title"),
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("MultiSelectMenu Preview"))
        Text("Test Mode: \(logger.testMode ? "ON" : "OFF")")
            .font(.caption)
            .foregroundColor(.secondary)
        DiagnosticsBufferView(events: MultiSelectMenu.recentAnalyticsEvents())
    }
    .padding()
}
