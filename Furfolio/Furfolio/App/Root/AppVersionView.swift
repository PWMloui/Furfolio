//
//  AppVersionView.swift
//  Furfolio
//
//  Enhanced: token-compliant, analytics/audit-ready, fully accessible, preview/test-injectable.
//

import SwiftUI

// MARK: - Audit/Analytics Protocol

public protocol AppVersionAnalyticsLogger {
    func log(event: String, info: String?)
}
public struct NullAppVersionAnalyticsLogger: AppVersionAnalyticsLogger {
    public init() {}
    public func log(event: String, info: String?) {}
}

// MARK: - Reusable InfoCard Component (Unchanged)
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

// MARK: - AppVersionView (Enhanced)
struct AppVersionView: View {
    var userRole: String? = nil
    static var analyticsLogger: AppVersionAnalyticsLogger = NullAppVersionAnalyticsLogger()
    
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
                
                InfoCard(title: "App Version") {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(Bundle.appVersionDisplay)
                            .accessibilityLabel(Text("App version \(Bundle.appVersionDisplay)"))
                        Text("Build Channel: Production")
                            .font(AppFonts.caption)
                            .foregroundStyle(AppColors.secondary)
                            .accessibilityLabel(Text("Build channel: Production"))
                    }
                }
                
                if let role = userRole, !role.isEmpty {
                    InfoCard(title: "User Role") {
                        Text(role)
                            .accessibilityLabel(Text("User role: \(role)"))
                    }
                }
                
                InfoCard(title: "Release Notes") {
                    Button {
                        Self.analyticsLogger.log(event: "release_notes_tap", info: nil)
                        // TODO: Implement navigation to Release Notes view or website
                    } label: {
                        HStack {
                            Text("View latest release notes")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(AppColors.accent)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("Opens the release notes in Safari"))
                }
                
                Spacer(minLength: AppSpacing.xLarge)
            }
            .padding(.horizontal, AppSpacing.medium)
            .onAppear {
                Self.analyticsLogger.log(event: "version_view_appear", info: userRole)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle(Text("App Version"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Static extension for app version display convenience
extension Bundle {
    static var appVersionDisplay: String {
        if let v = main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let b = main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(v) (\(b))"
        }
        return "1.0"
    }
}

// MARK: - Preview with all analytics injected and multiple scenarios
#Preview {
    struct SpyLogger: AppVersionAnalyticsLogger {
        func log(event: String, info: String?) {
            print("[AppVersionAnalytics] \(event): \(info ?? "")")
        }
    }
    AppVersionView.analyticsLogger = SpyLogger()
    return Group {
        NavigationStack { AppVersionView(userRole: "Owner") }
            .previewDisplayName("Light Mode - Owner")
        NavigationStack { AppVersionView(userRole: "Assistant") }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode - Assistant")
        NavigationStack { AppVersionView() }
            .previewDisplayName("Light Mode - No Role")
    }
}
