//
//  AppVersionView.swift
//  Furfolio
//
//  Enhanced: token-compliant, analytics/audit-ready (with role/staff/context), escalation, fully accessible, preview/test-injectable.
//  Last updated: 2025-06-30
//

import SwiftUI

// MARK: - Audit/Analytics Protocol

public protocol AppVersionAnalyticsLogger {
    var testMode: Bool { get set }
    func log(event: String, info: String?, role: String?, staffID: String?, context: String?) async
    func escalate(event: String, info: String?, role: String?, staffID: String?, context: String?) async
}

// Default no-op analytics logger
public struct NullAppVersionAnalyticsLogger: AppVersionAnalyticsLogger {
    public var testMode: Bool = false
    public init() {}
    public func log(event: String, info: String?, role: String?, staffID: String?, context: String?) async {}
    public func escalate(event: String, info: String?, role: String?, staffID: String?, context: String?) async {}
}

// MARK: - InfoCard (Unchanged, tokenized)
struct InfoCard<Content: View>: View {
    let title: LocalizedStringKey
    let content: Content

    init(title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(title)
                .font(AppFonts.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel(title)
            content
                .font(AppFonts.body)
                .foregroundColor(AppColors.primary)
        }
        .padding(AppSpacing.medium)
        .background(AppColors.card)
        .cornerRadius(BorderRadius.medium)
        .appShadow(AppShadows.card)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - AppVersionView (Now role/staff/context/audit ready)
struct AppVersionView: View {
    var userRole: String? = nil
    var staffID: String? = nil
    var context: String? = "AppVersionView"

    static var analyticsLogger: AppVersionAnalyticsLogger = NullAppVersionAnalyticsLogger()
    @State private var lastAnalyticsEvent: (String, String?)? = nil // For preview/diagnostics

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                Image(systemName: "info.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .foregroundColor(AppColors.accent)
                    .padding(.top, AppSpacing.xLarge)
                    .accessibilityHidden(true)

                InfoCard(title: LocalizedStringKey("app_version_title")) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(Bundle.appVersionDisplay)
                            .accessibilityLabel(Text(
                                String(format: NSLocalizedString("accessibility_app_version", comment: "Accessibility: App version x.y.z"), Bundle.appVersionDisplay)
                            ))
                        Text(NSLocalizedString("build_channel_production", comment: "Build channel: Production"))
                            .font(AppFonts.caption)
                            .foregroundStyle(AppColors.secondary)
                            .accessibilityLabel(Text(
                                NSLocalizedString("accessibility_build_channel_production", comment: "Accessibility: Build channel: Production")
                            ))
                    }
                }

                if let role = userRole, !role.isEmpty {
                    InfoCard(title: LocalizedStringKey("user_role_title")) {
                        Text(role)
                            .accessibilityLabel(Text(
                                String(format: NSLocalizedString("accessibility_user_role", comment: "Accessibility: User role: %@"), role)
                            ))
                    }
                }

                InfoCard(title: LocalizedStringKey("release_notes_title")) {
                    Button {
                        Task {
                            await Self.analyticsLogger.log(
                                event: NSLocalizedString("event_release_notes_tap", comment: "Event: User tapped release notes"),
                                info: nil,
                                role: userRole,
                                staffID: staffID,
                                context: context
                            )
                            lastAnalyticsEvent = (NSLocalizedString("event_release_notes_tap", comment: "Event: User tapped release notes"), nil)
                            // TODO: Implement navigation to Release Notes view or website
                        }
                    } label: {
                        HStack {
                            Text(NSLocalizedString("view_latest_release_notes", comment: "Button: View latest release notes"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(AppColors.accent)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(NSLocalizedString("accessibility_view_release_notes", comment: "Accessibility: Button to view release notes")))
                    .accessibilityHint(Text(NSLocalizedString("accessibility_hint_release_notes", comment: "Accessibility: Opens the release notes in Safari")))
                }

                Spacer(minLength: AppSpacing.xLarge)
            }
            .padding(.horizontal, AppSpacing.medium)
            .task {
                await Self.analyticsLogger.log(
                    event: NSLocalizedString("event_version_view_appear", comment: "Event: AppVersionView appeared"),
                    info: userRole,
                    role: userRole,
                    staffID: staffID,
                    context: context
                )
                lastAnalyticsEvent = (NSLocalizedString("event_version_view_appear", comment: "Event: AppVersionView appeared"), userRole)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(Text(NSLocalizedString("app_version_nav_title", comment: "Navigation title: App Version")))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Static extension for app version display
extension Bundle {
    static var appVersionDisplay: String {
        if let v = main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let b = main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(v) (\(b))"
        }
        return "1.0"
    }
}

// MARK: - Preview with analytics injection, testMode, role/staff/context demo
#Preview {
    /// SpyLogger for preview/test, supports testMode and live event capture.
    class SpyLogger: AppVersionAnalyticsLogger, ObservableObject {
        @Published var lastEvent: (String, String?)?
        var testMode: Bool = false
        func log(event: String, info: String?, role: String?, staffID: String?, context: String?) async {
            let message = "[AppVersionAnalytics] \(event): \(info ?? "") [role:\(role ?? "-")] [staff:\(staffID ?? "-")] [ctx:\(context ?? "-")]"
            if testMode {
                print("[TESTMODE] \(message)")
            } else {
                print(message)
            }
            await MainActor.run {
                self.lastEvent = (event, info)
            }
        }
        func escalate(event: String, info: String?, role: String?, staffID: String?, context: String?) async {
            let message = "[AppVersionAnalytics][ESCALATE] \(event): \(info ?? "") [role:\(role ?? "-")] [staff:\(staffID ?? "-")] [ctx:\(context ?? "-")]"
            print(message)
            await MainActor.run {
                self.lastEvent = (event, info)
            }
        }
    }
    struct AppVersionPreviewWrapper: View {
        @StateObject var logger = SpyLogger()
        @State private var testMode: Bool = false
        @State private var role: String? = "Owner"
        @State private var staffID: String? = "staff001"
        @State private var context: String = "AppVersionPreview"
        @State private var colorScheme: ColorScheme = .light
        var body: some View {
            NavigationStack {
                VStack {
                    Picker("Role", selection: $role) {
                        Text(NSLocalizedString("owner_role", comment: "Preview: Owner role")).tag(Optional("Owner"))
                        Text(NSLocalizedString("assistant_role", comment: "Preview: Assistant role")).tag(Optional("Assistant"))
                        Text(NSLocalizedString("no_role", comment: "Preview: No role")).tag(Optional<String>(nil))
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel(Text(NSLocalizedString("accessibility_picker_role", comment: "Accessibility: Select user role")))
                    .accessibilityHint(Text(NSLocalizedString("accessibility_hint_picker_role", comment: "Accessibility: Changes the user role for preview")))
                    TextField("Staff ID", text: Binding($staffID, replacingNilWith: ""))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Staff ID")
                    Toggle(NSLocalizedString("test_mode_toggle", comment: "Preview: Toggle test mode"), isOn: $testMode)
                        .onChange(of: testMode) { newValue in
                            logger.testMode = newValue
                        }
                        .accessibilityLabel(Text(NSLocalizedString("accessibility_test_mode_toggle", comment: "Accessibility: Toggle analytics test mode")))
                        .accessibilityHint(Text(NSLocalizedString("accessibility_hint_test_mode_toggle", comment: "Accessibility: Enables or disables analytics test mode")))
                    Picker("Color Scheme", selection: $colorScheme) {
                        Text(NSLocalizedString("light_mode", comment: "Preview: Light mode")).tag(ColorScheme.light)
                        Text(NSLocalizedString("dark_mode", comment: "Preview: Dark mode")).tag(ColorScheme.dark)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel(Text(NSLocalizedString("accessibility_color_scheme", comment: "Accessibility: Select color scheme")))
                    .accessibilityHint(Text(NSLocalizedString("accessibility_hint_color_scheme", comment: "Accessibility: Changes the color scheme for preview")))
                    AppVersionView.analyticsLogger = logger
                    AppVersionView(userRole: role, staffID: staffID, context: context)
                        .preferredColorScheme(colorScheme)
                    if let (event, info) = logger.lastEvent {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: NSLocalizedString("last_event", comment: "Preview: Last analytics event"), event))
                            if let info = info, !info.isEmpty {
                                Text(String(format: NSLocalizedString("last_event_info", comment: "Preview: Last analytics info"), info))
                            }
                        }
                        .font(.caption)
                        .padding(.top, 4)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Text(NSLocalizedString("accessibility_last_event", comment: "Accessibility: Last analytics event info")))
                    }
                }
                .padding()
            }
        }
    }
    return AppVersionPreviewWrapper()
}

// MARK: - TextField binding for optional string
extension Binding where Value == String? {
    init(_ source: Binding<String?>, replacingNilWith nilReplacement: String) {
        self.init(get: { source.wrappedValue ?? nilReplacement },
                  set: { newValue in source.wrappedValue = newValue.isEmpty ? nil : newValue })
    }
}
