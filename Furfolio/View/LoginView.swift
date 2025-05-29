//
//  LoginView.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on 2025-05-07 with enhanced animations, haptic feedback, asynchronous login simulation, biometric authentication, and new business tips.

import SwiftUI
import LocalAuthentication
import os

@MainActor
final class LoginViewModel: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "LoginViewModel")
  @Published var username: String = ""
  @Published var password: String = ""
  @Published var isAuthenticated: Bool = false
  @Published var authenticationError: String? = nil
  @Published var isLoading: Bool = false

  private let feedbackGenerator = UINotificationFeedbackGenerator()
  private static let storedCredentials: [String: String] = [
    "lvconcepcion": "jesus2024"
  ]

  func login() async {
      logger.log("login() called for username: \(username)")
    isLoading = true
    authenticationError = nil
    // Simulate network delay
    try? await Task.sleep(nanoseconds: 1_500_000_000)
    authenticateUser()
    isLoading = false
  }

  private func authenticateUser() {
      logger.log("Authenticating user: \(username)")
    if let storedPassword = Self.storedCredentials[username], storedPassword == password {
        logger.log("Authentication successful for user: \(username)")
      withAnimation {
        isAuthenticated = true
        authenticationError = nil
      }
      feedbackGenerator.notificationOccurred(.success)
    } else {
        logger.log("Authentication failed for user: \(username)")
      withAnimation {
        isAuthenticated = false
        authenticationError = NSLocalizedString("Invalid username or password. Please try again.", comment: "Error message for invalid login credentials")
      }
      feedbackGenerator.notificationOccurred(.error)
    }
  }

  func biometricLogin() {
      logger.log("biometricLogin() called")
    let context = LAContext()
    var error: NSError?
    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
        logger.log("Biometric available, evaluating policy")
      let reason = NSLocalizedString("Authenticate with Face ID to access your account.", comment: "Biometric authentication reason")
      context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, evaluateError in
        DispatchQueue.main.async {
          if success {
              self.logger.log("Biometric authentication succeeded")
            withAnimation {
              self.isAuthenticated = true
              self.authenticationError = nil
            }
            self.feedbackGenerator.notificationOccurred(.success)
          } else {
              self.logger.log("Biometric authentication failed: \(evaluateError?.localizedDescription ?? "unknown error")")
            withAnimation {
              self.isAuthenticated = false
              self.authenticationError = evaluateError?.localizedDescription ?? NSLocalizedString("Biometric authentication failed. Please try again.", comment: "Error message for failed biometric authentication")
            }
            self.feedbackGenerator.notificationOccurred(.error)
          }
        }
      }
    } else {
        logger.log("Biometric authentication not available: \(error?.localizedDescription ?? "unknown")")
      withAnimation {
        authenticationError = NSLocalizedString("Biometric authentication is not available on this device.", comment: "Error message for unavailable biometrics")
      }
      feedbackGenerator.notificationOccurred(.error)
    }
  }
}

// TODO: Move authentication and error handling into LoginViewModel; use secure storage (Keychain) for credentials.

@MainActor
/// View for user authentication: handles username/password login, biometric authentication, and displays business tips.
struct LoginView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "LoginView")
  @StateObject private var viewModel = LoginViewModel()

  var body: some View {
    VStack(spacing: 16) {
      // Title
      Text(NSLocalizedString("Welcome to Furfolio", comment: "Welcome message on login screen"))
        .font(.largeTitle)
        .fontWeight(.bold)
        .padding(.bottom, 20)
        .accessibilityAddTraits(.isHeader)
        .transition(.opacity)
      
      // Username Input
      TextField(NSLocalizedString("Username", comment: "Placeholder for username input"), text: $viewModel.username)
        .padding()
        .autocapitalization(.none)
        .disableAutocorrection(true)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
        .accessibilityLabel(NSLocalizedString("Username", comment: "Accessibility label for username field"))
        .transition(.move(edge: .leading))
      
      // Password Input
      SecureField(NSLocalizedString("Password", comment: "Placeholder for password input"), text: $viewModel.password)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
        .accessibilityLabel(NSLocalizedString("Password", comment: "Accessibility label for password field"))
        .transition(.move(edge: .trailing))
      
      // Login Button
      Button(action: {
          logger.log("Login button tapped")
        Task { await viewModel.login() }
      }) {
        if viewModel.isLoading {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
            .frame(maxWidth: .infinity)
            .padding()
        } else {
          Text(NSLocalizedString("Login", comment: "Button label for logging in"))
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
        }
      }
      .buttonStyle(FurfolioButtonStyle())
      .accessibilityLabel(NSLocalizedString("Login Button", comment: "Accessibility label for login button"))
      .disabled(viewModel.isLoading)
      .transition(.scale)
      
      // Biometric Login Button
      Button(action: {
          logger.log("Biometric login button tapped")
        viewModel.biometricLogin()
      }) {
        HStack {
          Image(systemName: "faceid")
          Text(NSLocalizedString("Login with Face ID", comment: "Button label for biometric login"))
        }
        .font(.headline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding()
      }
      .buttonStyle(FurfolioButtonStyle())
      .accessibilityLabel(NSLocalizedString("Biometric Login Button", comment: "Accessibility label for biometric login button"))
      .disabled(viewModel.isLoading)
      .transition(.scale)
      
      Button(action: {
          logger.log("Skip Login tapped")
        withAnimation {
          viewModel.isAuthenticated = true
          viewModel.authenticationError = nil
        }
        // Haptic feedback handled in ViewModel, but here we can create a local generator for success
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.notificationOccurred(.success)
      }) {
        Text("Skip Login")
          .font(.subheadline)
          .foregroundColor(.blue)
          .padding(.top, 8)
      }
      .accessibilityLabel("Skip Login Button")
      .buttonStyle(FurfolioButtonStyle())
      
      // Authentication Error Message
      if let error = viewModel.authenticationError {
        Text(error)
          .foregroundColor(AppTheme.warning)
          .font(.footnote)
          .padding(.top, 10)
          .accessibilityLabel(NSLocalizedString("Error Message", comment: "Accessibility label for error message"))
          .transition(.opacity)
      }
      
      // Successful Authentication Message
      if viewModel.isAuthenticated {
        Text(NSLocalizedString("Successfully Authenticated!", comment: "Message for successful login"))
          .foregroundColor(AppTheme.accent)
          .font(.headline)
          .accessibilityLabel(NSLocalizedString("Success Message", comment: "Accessibility label for success message"))
          .transition(.opacity)
      }
      
      if !viewModel.isAuthenticated {
        businessTipsSection()
      }
    }
    .padding()
    .accessibilityElement(children: .combine)
    .animation(.easeInOut, value: viewModel.isAuthenticated)
    .onAppear {
        logger.log("LoginView appeared")
    }
  }
  
  /// Shows business-owner tips when not authenticated.
  @ViewBuilder
  private func businessTipsSection() -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("💡 Furfolio Tips")
        .font(.headline)
      Text("• Track 🐾 loyalty rewards for returning clients.")
      Text("• Log 🧠 pet behavior like calmness or anxiety.")
      Text("• See 📅 appointment trends and revenue snapshots.")
      Text("• 🕒 View peak booking hours to optimize staff scheduling.")
      Text("• 💤 Follow up with clients who haven’t visited in 90+ days.")
    }
    .padding()
    .background(Color(UIColor.tertiarySystemBackground))
    .cornerRadius(10)
    .transition(.opacity)
  }
}
