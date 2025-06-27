import SwiftUI

struct LoginFlowCoordinator: View {
    @State private var showIntro: Bool = true
    @State private var showSplash: Bool = true

    var body: some View {
        ZStack {
            // Background Theme Gradient
            LinearGradient(
                gradient: Gradient(colors: [AppColors.background, AppColors.secondaryBackground]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Optional Splash Layer
            if showSplash {
                VStack {
                    Spacer()
                    Image(systemName: "pawprint.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .transition(.scale)
                        .padding(.bottom, 60)
                        .accessibilityHidden(true)
                    Spacer()
                }
                .onAppear {
                    withAnimation(.easeOut(duration: 1.2)) {
                        showSplash = false
                    }
                }
            }

            // Main Login Stack
            if showIntro {
                LoginIntroView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showIntro = false
                    }
                }
                .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
                    .accessibilityIdentifier("LoginView")
            }
        }
        .accessibilityIdentifier("LoginFlowCoordinatorStack")
    }
}

#Preview {
    LoginFlowCoordinator()
}
