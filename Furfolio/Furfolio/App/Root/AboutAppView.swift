//
//  AboutAppView.swift
//  Furfolio
//
//  ENHANCED 2025-06-30: Role-aware, analytics/audit-trail, compliance, business branding, future-proof.
//
import SwiftUI

// MARK: - Analytics Protocol (Role/Staff/Context-Aware)

public protocol AboutAppViewAnalyticsLogger {
    func log(event: String, info: String, role: String?, staffID: String?, context: String?) async
    var testMode: Bool { get set }
}
public struct NullAboutAppViewAnalyticsLogger: AboutAppViewAnalyticsLogger {
    public init() {}
    public var testMode: Bool = false
    public func log(event: String, info: String, role: String?, staffID: String?, context: String?) async {}
}

// MARK: - AboutAppView

struct AboutAppView: View {
    @State private var showDeveloperDebugSection = false
    @State private var lastAnalyticsEvent: String = ""
    @State private var currentRole: FurfolioRole = .owner
    @State private var staffID: String? = nil
    @State private var businessContext: String? = "AboutAppView"
    @Environment(\.colorScheme) private var colorScheme

    // Analytics logger (swappable)
    static var analyticsLogger: AboutAppViewAnalyticsLogger = NullAboutAppViewAnalyticsLogger()

    // For role-based diagnostics section
    private var canShowDevSection: Bool {
        currentRole == .owner || currentRole == .admin || currentRole == .developer
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.large) {

                    // MARK: Brand Card
                    VStack(spacing: AppSpacing.medium) {
                        Image(systemName: "pawprint.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundStyle(AppColors.accent)
                            .accessibilityHidden(true)
                        Text(NSLocalizedString("about_app_title", value: "Furfolio", comment: "App name"))
                            .font(AppFonts.largeTitleBold)
                            .accessibilityAddTraits(.isHeader)
                        Text(String(format: NSLocalizedString("about_app_version_fmt", value: "Version %@", comment: "App version label"), Bundle.appVersionDisplay))
                            .font(AppFonts.title3)
                            .foregroundStyle(AppColors.secondary)
                            .accessibilityLabel(String(format: NSLocalizedString("about_app_version_accessibility_fmt", value: "App version %@", comment: "Accessibility: app version"), Bundle.appVersionDisplay))
                    }
                    .padding(AppSpacing.medium)
                    .frame(maxWidth: .infinity)
                    .background(AppColors.card)
                    .containerShape(RoundedRectangle(cornerRadius: BorderRadius.large, style: .continuous))
                    .appShadow(AppShadows.card)
                    .padding(.horizontal, AppSpacing.medium)
                    .accessibilityElement(children: .combine)

                    // MARK: Business Description & Features
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        Text(NSLocalizedString("about_app_description", value: "Furfolio is your all-in-one grooming business manager, designed to streamline appointments, track clients and pets, and grow your business — all offline, private, and secure.", comment: "App business description"))
                            .font(AppFonts.body)
                            .foregroundStyle(AppColors.primary)
                            .multilineTextAlignment(.leading)
                            .accessibilityLabel(NSLocalizedString("about_app_description_accessibility", value: "Business description: Furfolio is your all-in-one grooming business manager, designed to streamline appointments, track clients and pets, and grow your business — all offline, private, and secure.", comment: "Accessibility: business description"))

                        Text(NSLocalizedString("about_app_features_header", value: "Key Features", comment: "Key features header"))
                            .font(AppFonts.title2Bold)
                            .accessibilityAddTraits(.isHeader)

                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            FeatureLabel(text: NSLocalizedString("about_feature_appointments", value: "Appointments", comment: "Feature: Appointments"))
                            FeatureLabel(text: NSLocalizedString("about_feature_clients_pets", value: "Clients & Pets", comment: "Feature: Clients & Pets"))
                            FeatureLabel(text: NSLocalizedString("about_feature_grooming_history", value: "Grooming History", comment: "Feature: Grooming History"))
                            FeatureLabel(text: NSLocalizedString("about_feature_financials", value: "Financials", comment: "Feature: Financials"))
                            FeatureLabel(text: NSLocalizedString("about_feature_analytics", value: "Analytics", comment: "Feature: Analytics"))
                            FeatureLabel(text: NSLocalizedString("about_feature_security", value: "Security", comment: "Feature: Security"))
                        }
                    }
                    .padding(.horizontal, AppSpacing.medium)

                    // MARK: Privacy & Trust Center Navigation
                    NavigationLink(destination: TrustCenterView()) {
                        Text(NSLocalizedString("about_nav_trust_center", value: "Privacy & Trust Center", comment: "Navigation link: Privacy & Trust Center"))
                            .font(AppFonts.headline)
                            .frame(maxWidth: .infinity)
                            .padding(AppSpacing.medium)
                            .background(AppColors.accent.opacity(0.1))
                            .foregroundColor(AppColors.accent)
                            .cornerRadius(BorderRadius.medium)
                    }
                    .padding(.horizontal, AppSpacing.medium)
                    .accessibilityLabel(NSLocalizedString("about_nav_trust_center_accessibility", value: "Navigate to Privacy and Trust Center", comment: "Accessibility: nav to privacy center"))
                    .accessibilityHint(NSLocalizedString("about_nav_trust_center_hint", value: "Opens Furfolio privacy and trust information.", comment: "Accessibility hint: privacy center"))

                    // MARK: Credits/Team Section
                    VStack(spacing: AppSpacing.small) {
                        Text(NSLocalizedString("about_credits_developed_by", value: "Developed by Furfolio Team", comment: "Credits: developed by"))
                            .font(AppFonts.footnote)
                            .accessibilityAddTraits(.isStaticText)
                        Text(NSLocalizedString("about_credits_contact", value: "Contact: support@furfolio.app", comment: "Credits: contact email"))
                            .font(AppFonts.footnote)
                            .foregroundStyle(AppColors.secondary)
                            .accessibilityLabel(NSLocalizedString("about_credits_contact_accessibility", value: "Contact email support at furfolio dot app", comment: "Accessibility: contact email"))
                        Link(NSLocalizedString("about_credits_website", value: "Visit Website", comment: "Credits: website link"), destination: URL(string: "https://furfolio.app")!)
                            .font(AppFonts.footnote)
                            .accessibilityLabel(NSLocalizedString("about_credits_website_accessibility", value: "Visit Furfolio website", comment: "Accessibility: visit website"))
                            .accessibilityHint(NSLocalizedString("about_credits_website_hint", value: "Opens the Furfolio website in your browser.", comment: "Accessibility hint: website"))
                        Text(NSLocalizedString("about_credits_privacy", value: "Furfolio is offline-first and prioritizes your data privacy and security.", comment: "Credits: privacy statement"))
                            .font(AppFonts.footnote)
                            .foregroundStyle(AppColors.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, AppSpacing.xSmall)
                            .accessibilityLabel(NSLocalizedString("about_credits_privacy_accessibility", value: "Furfolio is offline first and prioritizes your data privacy and security.", comment: "Accessibility: privacy statement"))
                    }
                    .padding(.horizontal, AppSpacing.medium)

                    // MARK: Developer / Debug Section (Role-aware)
                    if canShowDevSection && showDeveloperDebugSection {
                        VStack(spacing: AppSpacing.medium) {
                            Divider()
                                .background(AppColors.divider)
                            Text(NSLocalizedString("about_debug_section_header", value: "Developer Debug Section", comment: "Debug section header"))
                                .font(AppFonts.headline)
                            NavigationLink(NSLocalizedString("about_debug_nav_licenses", value: "Open Source Licenses", comment: "Debug: open source licenses"), destination: OpenSourceLicensesView())
                                .accessibilityLabel(NSLocalizedString("about_debug_nav_licenses_accessibility", value: "Navigate to Open Source Licenses", comment: "Accessibility: open source licenses"))
                                .accessibilityHint(NSLocalizedString("about_debug_nav_licenses_hint", value: "Shows open source license information.", comment: "Accessibility hint: open source licenses"))
                        }
                        .padding(.horizontal, AppSpacing.medium)
                    }

                    Spacer(minLength: AppSpacing.medium)

                    // MARK: Footer
                    Text(String(format: NSLocalizedString("about_footer_copyright_fmt", value: "© %d Furfolio. All rights reserved.", comment: "Footer copyright"), Calendar.current.component(.year, from: Date())))
                        .font(AppFonts.caption2)
                        .foregroundStyle(AppColors.tertiary)
                        .padding(.bottom, AppSpacing.medium)
                        .accessibilityLabel(String(format: NSLocalizedString("about_footer_copyright_accessibility_fmt", value: "Copyright %d Furfolio. All rights reserved.", comment: "Accessibility: copyright footer"), Calendar.current.component(.year, from: Date())))
                }
                .padding(.vertical, AppSpacing.medium)
                .frame(maxWidth: .infinity)
                .background(AppColors.background)
                .ignoresSafeArea(edges: .bottom)
                .onAppear {
                    Task {
                        await AboutAppView.analyticsLogger.log(
                            event: "about_view_appear",
                            info: Bundle.appVersionDisplay,
                            role: currentRole.rawValue,
                            staffID: staffID,
                            context: businessContext
                        )
                    }
                }
            }
            .navigationTitle(NSLocalizedString("about_nav_title", value: "About Furfolio", comment: "Navigation title: about"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showDeveloperDebugSection.toggle()
                        Task {
                            await AboutAppView.analyticsLogger.log(
                                event: showDeveloperDebugSection ? "dev_debug_section_shown" : "dev_debug_section_hidden",
                                info: "",
                                role: currentRole.rawValue,
                                staffID: staffID,
                                context: businessContext
                            )
                        }
                    }) {
                        Image(systemName: "hammer.fill")
                            .accessibilityLabel(showDeveloperDebugSection
                                ? NSLocalizedString("about_dev_debug_hide_label", value: "Hide developer debug section", comment: "Accessibility: hide debug section")
                                : NSLocalizedString("about_dev_debug_show_label", value: "Show developer debug section", comment: "Accessibility: show debug section"))
                            .accessibilityHint(NSLocalizedString("about_dev_debug_hint", value: "Toggles developer debug section visibility.", comment: "Accessibility: debug toggle hint"))
                    }
                    .disabled(!canShowDevSection)
                    .opacity(canShowDevSection ? 1 : 0.25)
                }
            }
        }
    }
}

// MARK: - FeatureLabel (Tokenized/Reusable)
private struct FeatureLabel: View {
    let text: String
    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(AppColors.accent)
        }
        .font(AppFonts.body)
        .accessibilityLabel(text)
        .accessibilityHint(NSLocalizedString("about_feature_label_hint", value: "Feature available in Furfolio.", comment: "Accessibility hint: feature label"))
    }
}

// MARK: - Trust Center & Licenses (Stubs)

private struct TrustCenterView: View {
    var body: some View {
        Text(NSLocalizedString("about_trust_center_coming_soon", value: "Trust Center Coming Soon", comment: "Trust center coming soon"))
            .font(AppFonts.title)
            .navigationTitle(NSLocalizedString("about_nav_trust_center", value: "Privacy & Trust Center", comment: "Navigation title: trust center"))
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityLabel(NSLocalizedString("about_trust_center_coming_soon_accessibility", value: "Trust Center Coming Soon", comment: "Accessibility: trust center coming soon"))
    }
}
private struct OpenSourceLicensesView: View {
    var body: some View {
        Text(NSLocalizedString("about_licenses_coming_soon", value: "Open Source Licenses Coming Soon", comment: "Licenses coming soon"))
            .font(AppFonts.title)
            .navigationTitle(NSLocalizedString("about_debug_nav_licenses", value: "Open Source Licenses", comment: "Navigation title: open source licenses"))
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityLabel(NSLocalizedString("about_licenses_coming_soon_accessibility", value: "Open Source Licenses Coming Soon", comment: "Accessibility: licenses coming soon"))
    }
}

// MARK: - Bundle Extension for Version Info

extension Bundle {
    static var appVersionDisplay: String {
        let main = Bundle.main
        if let version = main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "1.0"
    }
}

// MARK: - PREVIEW / QA Diagnostics

struct AboutAppView_Previews: PreviewProvider {
    struct AnalyticsPreviewWrapper: View {
        @State private var testMode: Bool = false
        @State private var lastEvent: String = ""
        @State private var logger: PreviewLogger = PreviewLogger()
        @State private var currentRole: FurfolioRole = .owner

        var body: some View {
            VStack(spacing: 12) {
                HStack {
                    Toggle(isOn: $testMode) {
                        Text("Test Analytics Mode (Console Only)")
                    }
                    .onChange(of: testMode) { newValue in
                        logger.testMode = newValue
                        AboutAppView.analyticsLogger = logger
                    }
                    .accessibilityLabel("Toggle test analytics mode")
                    .accessibilityHint("When enabled, analytics events are logged to the console only for QA.")
                    Picker("Role", selection: $currentRole) {
                        ForEach(FurfolioRole.allCases, id: \.self) { role in
                            Text(role.rawValue.capitalized)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: currentRole) { _ in
                        AboutAppView.analyticsLogger = logger
                    }
                }
                .padding(.horizontal)

                AboutAppView.analyticsLogger = logger
                AboutAppView()
                    .onAppear {
                        var loggerCopy = logger
                        loggerCopy.onEvent = { event, info, role, staffID, context in
                            DispatchQueue.main.async {
                                lastEvent = "\(event): \(info) (\(role ?? ""))"
                            }
                        }
                        logger = loggerCopy
                        AboutAppView.analyticsLogger = logger
                    }
                Divider()
                Text("Last Analytics Event: \(lastEvent)")
                    .font(.caption)
                    .padding(.bottom, 10)
                    .accessibilityLabel("Last Analytics Event")
                    .accessibilityHint("Displays the most recent analytics event for diagnostics.")
                Button("Simulate Analytics Event") {
                    Task {
                        await AboutAppView.analyticsLogger.log(event: "preview_simulated_event", info: "Simulated from Preview", role: currentRole.rawValue, staffID: nil, context: "Preview")
                    }
                }
                .accessibilityLabel("Simulate analytics event")
                .accessibilityHint("Sends a test analytics event to logger.")
                .padding(.bottom, 10)
            }
        }
    }
    static var previews: some View {
        Group {
            AnalyticsPreviewWrapper()
                .previewDevice("iPhone 14 Pro")
            AnalyticsPreviewWrapper()
                .previewDevice("iPad Pro (12.9-inch) (6th generation)")
                .previewInterfaceOrientation(.landscapeLeft)
        }
    }
}

// MARK: - Role Enum Example (should be defined elsewhere in your app)

enum FurfolioRole: String, CaseIterable {
    case owner, admin, receptionist, groomer, staff, guest, developer, unknown
}

struct PreviewLogger: AboutAppViewAnalyticsLogger {
    var testMode: Bool = false
    var onEvent: ((String, String, String?, String?, String?) -> Void)? = nil
    mutating func setTestMode(_ enabled: Bool) { self.testMode = enabled }
    func log(event: String, info: String, role: String?, staffID: String?, context: String?) async {
        let msg = "[AboutAppViewAnalytics]\(testMode ? "[TESTMODE]" : "") \(event): \(info) [role:\(role ?? "-") staff:\(staffID ?? "-") ctx:\(context ?? "-")]"
        if testMode {
            print(msg)
        } else {
            print(msg)
        }
        onEvent?(event, info, role, staffID, context)
    }
}
