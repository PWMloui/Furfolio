import SwiftUI

struct LoginIntroView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Text("Welcome to Furfolio")
                .font(AppFonts.largeTitle.bold())
                .foregroundColor(AppColors.primaryText)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("welcomeTitle")

            VStack(spacing: 24) {
                RoleCardView(icon: "scissors", title: "Staff", description: "Handles grooming and client interactions.")
                RoleCardView(icon: "phone.fill", title: "Receptionist", description: "Manages calls, check-ins, and appointments.")
                RoleCardView(icon: "chart.bar.fill", title: "Manager", description: "Oversees revenue, reports, and settings.")
            }
            .transition(.opacity)
            .accessibilityIdentifier("roleCards")

            Spacer()

            Button("Continue to Login") {
                withAnimation {
                    onContinue()
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, AppSpacing.medium)
            .accessibilityIdentifier("continueButton")
        }
        .padding(AppSpacing.large)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [AppColors.background, AppColors.secondaryBackground]),
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()
        )
    }
}

struct RoleCardView: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(title)
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.primaryText)
                Text(description)
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(description)")
        .accessibilityIdentifier("roleCard_\(title)")
        .padding(.vertical, AppSpacing.small)
    }
}

#Preview {
    LoginIntroView {
        print("Continue tapped")
    }
}
