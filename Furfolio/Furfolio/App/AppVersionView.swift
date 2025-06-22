//
//  AppVersionView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

// MARK: - AppVersionView (App Version Info, Modular Token Styling)

// MARK: - Reusable InfoCard Component for consistent design
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

struct AppVersionView: View {
    // Optional user role for role-based info section (multi-user context)
    var userRole: String? = nil
    
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
                
                // Version Info Section
                InfoCard(title: "App Version") {
                    Text(Bundle.appVersionDisplay)
                        .accessibilityLabel(Text("App version \(Bundle.appVersionDisplay)"))
                }
                
                // Role-based Info Section (conditionally shown)
                if let role = userRole, !role.isEmpty {
                    InfoCard(title: "User Role") {
                        Text(role)
                            .accessibilityLabel(Text("User role: \(role)"))
                    }
                }
                
                // Release Notes Section Placeholder with future link
                InfoCard(title: "Release Notes") {
                    // Accessibility: Button with descriptive label
                    Button {
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
                    .accessibilityHint(Text("Opens the release notes"))
                }
                
                Spacer(minLength: AppSpacing.xLarge)
            }
            .padding(.horizontal, AppSpacing.medium)
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

// MARK: - Preview with multiple scenarios including dark mode and user roles
#Preview {
    Group {
        NavigationStack {
            AppVersionView(userRole: "Owner")
        }
        .previewDisplayName("Light Mode - Owner")
        
        NavigationStack {
            AppVersionView(userRole: "Assistant")
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode - Assistant")
        
        NavigationStack {
            AppVersionView()
        }
        .previewDisplayName("Light Mode - No Role")
    }
}
