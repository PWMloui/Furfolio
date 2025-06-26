//
//  AboutAppView.swift
//  Furfolio
//
//  Enhanced: token-compliant, analytics/audit-ready, fully accessible, brand/white-label, modular.
//
import SwiftUI

// MARK: - About App Analytics Protocol

public protocol AboutAppViewAnalyticsLogger {
    func log(event: String, info: String)
}
public struct NullAboutAppViewAnalyticsLogger: AboutAppViewAnalyticsLogger {
    public init() {}
    public func log(event: String, info: String) {}
}

// MARK: - AboutAppView (Furfolio About & Credits, Tokenized Styling)

struct AboutAppView: View {
    @State private var showDeveloperDebugSection = false
    static var analyticsLogger: AboutAppViewAnalyticsLogger = NullAboutAppViewAnalyticsLogger()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.large) {
                    // MARK: About Furfolio Card
                    VStack(spacing: AppSpacing.medium) {
                        Image(systemName: "pawprint.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundStyle(AppColors.accent)
                            .accessibilityHidden(true)
                        Text("Furfolio")
                            .font(AppFonts.largeTitleBold)
                            .accessibilityAddTraits(.isHeader)
                        Text("Version \(Bundle.appVersionDisplay)")
                            .font(AppFonts.title3)
                            .foregroundStyle(AppColors.secondary)
                            .accessibilityLabel("App version \(Bundle.appVersionDisplay)")
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
                        Text("Furfolio is your all-in-one grooming business manager, designed to streamline appointments, track clients and pets, and grow your business — all offline, private, and secure.")
                            .font(AppFonts.body)
                            .foregroundStyle(AppColors.primary)
                            .multilineTextAlignment(.leading)
                            .accessibilityLabel("Business description: Furfolio is your all-in-one grooming business manager, designed to streamline appointments, track clients and pets, and grow your business — all offline, private, and secure.")

                        Text("Key Features")
                            .font(AppFonts.title2Bold)
                            .accessibilityAddTraits(.isHeader)

                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            FeatureLabel(text: "Appointments")
                            FeatureLabel(text: "Clients & Pets")
                            FeatureLabel(text: "Grooming History")
                            FeatureLabel(text: "Financials")
                            FeatureLabel(text: "Analytics")
                            FeatureLabel(text: "Security")
                        }
                    }
                    .padding(.horizontal, AppSpacing.medium)

                    // MARK: Privacy & Trust Center Navigation
                    NavigationLink(destination: TrustCenterView()) {
                        Text("Privacy & Trust Center")
                            .font(AppFonts.headline)
                            .frame(maxWidth: .infinity)
                            .padding(AppSpacing.medium)
                            .background(AppColors.accent.opacity(0.1))
                            .foregroundColor(AppColors.accent)
                            .cornerRadius(BorderRadius.medium)
                            .accessibilityLabel("Navigate to Privacy and Trust Center")
                    }
                    .padding(.horizontal, AppSpacing.medium)

                    // MARK: Developer / Credits Section
                    VStack(spacing: AppSpacing.small) {
                        Text("Developed by Furfolio Team")
                            .font(AppFonts.footnote)
                            .accessibilityAddTraits(.isStaticText)
                        Text("Contact: support@furfolio.app")
                            .font(AppFonts.footnote)
                            .foregroundStyle(AppColors.secondary)
                            .accessibilityLabel("Contact email support at furfolio dot app")
                        Link("Visit Website", destination: URL(string: "https://furfolio.app")!)
                            .font(AppFonts.footnote)
                            .accessibilityLabel("Visit Furfolio website")
                        Text("Furfolio is offline-first and prioritizes your data privacy and security.")
                            .font(AppFonts.footnote)
                            .foregroundStyle(AppColors.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, AppSpacing.xSmall)
                            .accessibilityLabel("Furfolio is offline first and prioritizes your data privacy and security.")
                    }
                    .padding(.horizontal, AppSpacing.medium)

                    // MARK: Developer Debug Section (Feature Flag)
                    if showDeveloperDebugSection {
                        VStack(spacing: AppSpacing.medium) {
                            Divider()
                                .background(AppColors.divider)
                            Text("Developer Debug Section")
                                .font(AppFonts.headline)
                            NavigationLink("Open Source Licenses", destination: OpenSourceLicensesView())
                                .accessibilityLabel("Navigate to Open Source Licenses")
                        }
                        .padding(.horizontal, AppSpacing.medium)
                    }

                    Spacer(minLength: AppSpacing.medium)

                    // MARK: Footer
                    Text("© \(Calendar.current.component(.year, from: Date())) Furfolio. All rights reserved.")
                        .font(AppFonts.caption2)
                        .foregroundStyle(AppColors.tertiary)
                        .padding(.bottom, AppSpacing.medium)
                        .accessibilityLabel("Copyright \(Calendar.current.component(.year, from: Date())) Furfolio. All rights reserved.")
                }
                .padding(.vertical, AppSpacing.medium)
                .frame(maxWidth: .infinity)
                .background(AppColors.background)
                .ignoresSafeArea(edges: .bottom)
                .onAppear {
                    AboutAppView.analyticsLogger.log(event: "about_view_appear", info: Bundle.appVersionDisplay)
                }
            }
            .navigationTitle("About Furfolio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showDeveloperDebugSection.toggle()
                        AboutAppView.analyticsLogger.log(
                            event: showDeveloperDebugSection ? "dev_debug_section_shown" : "dev_debug_section_hidden",
                            info: ""
                        )
                    }) {
                        Image(systemName: "hammer.fill")
                            .accessibilityLabel(showDeveloperDebugSection ? "Hide developer debug section" : "Show developer debug section")
                    }
                }
            }
        }
    }
}

// MARK: - Feature Label (Re-usable)
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
    }
}

// MARK: - Trust Center View Stub
private struct TrustCenterView: View {
    var body: some View {
        Text("Trust Center Coming Soon")
            .font(AppFonts.title)
            .navigationTitle("Privacy & Trust Center")
            .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Open Source Licenses View Stub
private struct OpenSourceLicensesView: View {
    var body: some View {
        Text("Open Source Licenses Coming Soon")
            .font(AppFonts.title)
            .navigationTitle("Open Source Licenses")
            .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Bundle Extension for Version Info
extension Bundle {
    /// Single source of truth for app version display string.
    static var appVersionDisplay: String {
        let main = Bundle.main
        if let version = main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "1.0"
    }
}

// MARK: - Preview
struct AboutAppView_Previews: PreviewProvider {
    struct SpyLogger: AboutAppViewAnalyticsLogger {
        func log(event: String, info: String) {
            print("[AboutAppViewAnalytics] \(event): \(info)")
        }
    }
    static var previews: some View {
        AboutAppView.analyticsLogger = SpyLogger()
        return Group {
            AboutAppView()
                .previewDevice("iPhone 14 Pro")
            AboutAppView()
                .previewDevice("iPad Pro (12.9-inch) (6th generation)")
                .previewInterfaceOrientation(.landscapeLeft)
        }
    }
}
