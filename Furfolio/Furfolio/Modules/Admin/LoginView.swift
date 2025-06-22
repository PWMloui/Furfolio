// MARK: - Furfolio LoginView (Xcode Marker)
//
//  LoginView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

// MARK: - Roles
enum FurfolioRole: String, CaseIterable, Identifiable {
    case owner = "Owner"
    case assistant = "Assistant"
    // TODO: Add more roles as needed
    var id: String { rawValue }
}

// MARK: - ViewModel Placeholder (MVVM)
class LoginViewModel: ObservableObject {
    // TODO: Integrate authentication, audit logs, encryption, etc.
    // Example properties for future use:
    //@Published var isAuthenticated: Bool = false
    //@Published var selectedRole: FurfolioRole = .owner
}

struct LoginView: View {
    // MARK: - State
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var rememberMe: Bool = false
    @State private var isLoggingIn: Bool = false
    @State private var loginError: String?
    @State private var selectedRole: FurfolioRole = .owner
    @FocusState private var focusedField: Field?

    // MARK: - ViewModel (MVVM)
    @StateObject var viewModel = LoginViewModel() // TODO: Connect to real VM logic

    // MARK: - Focus Enum
    enum Field {
        case email, password
    }

    // MARK: - Callback
    var onLoginSuccess: (() -> Void)? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: AppSpacing.medium) {
                Spacer()

                Image(systemName: "pawprint.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)
                    .foregroundStyle(AppColors.primaryText)
                    .padding(.top, AppSpacing.large)
                    .accessibilityLabel("Furfolio Logo")

                Text("Furfolio Login")
                    .font(AppFonts.largeTitle)
                    .foregroundColor(AppColors.primaryText)
                    .padding(.top, AppSpacing.small)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel("Furfolio Login Title")

                VStack(spacing: AppSpacing.small) {
                    // MARK: - Email Field
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textContentType(.emailAddress)
                        .padding(AppSpacing.small)
                        .background(AppColors.secondaryBackground)
                        .cornerRadius(8)
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.primaryText)
                        .accessibilityLabel("Email Address")
                        .accessibilityIdentifier("email")

                    // MARK: - Password Field
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .padding(AppSpacing.small)
                        .background(AppColors.secondaryBackground)
                        .cornerRadius(8)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { attemptLogin() }
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.primaryText)
                        .accessibilityLabel("Password")
                        .accessibilityIdentifier("password")

                    // MARK: - Role Picker (multi-user support)
                    Picker("Role", selection: $selectedRole) {
                        ForEach(FurfolioRole.allCases) { role in
                            Text(role.rawValue)
                                .tag(role)
                                .font(AppFonts.body)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Select Role")
                    .accessibilityIdentifier("rolePicker")
                    // TODO: Use selectedRole in authentication logic

                    // MARK: - Remember Me Toggle
                    Toggle("Remember Me", isOn: $rememberMe)
                        .toggleStyle(.switch)
                        .padding(.top, AppSpacing.xSmall)
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.primaryText)
                        .accessibilityLabel("Remember Me")
                        .accessibilityIdentifier("rememberMeToggle")
                }

                // MARK: - Error & Loading UI
                if let error = loginError {
                    HStack(spacing: AppSpacing.xSmall) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppColors.error)
                        Text(error)
                            .foregroundColor(AppColors.error)
                            .font(AppFonts.body)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.vertical, AppSpacing.xSmall)
                    .background(AppColors.errorBackground)
                    .cornerRadius(8)
                    .accessibilityLabel("Login Error: \(error)")
                }

                // MARK: - Login Button
                Button(action: attemptLogin) {
                    HStack {
                        if isLoggingIn {
                            ProgressView()
                                .padding(.trailing, AppSpacing.xSmall)
                                .accessibilityLabel("Logging In")
                        }
                        Text("Login")
                            .font(AppFonts.bodySemibold)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoggingIn || !isValid)
                .accessibilityLabel("Login Button")
                .accessibilityIdentifier("loginButton")

                // MARK: - Forgot Password Button
                Button("Forgot Password?") {
                    // TODO: Hook up forgot password/reset flow
                }
                .font(AppFonts.footnote)
                .foregroundColor(AppColors.primaryText)
                .padding(.top, AppSpacing.xSmall)
                .accessibilityLabel("Forgot Password")
                .accessibilityIdentifier("forgotPasswordButton")

                Spacer()

                // MARK: - Trust Center Links (App Info & Privacy)
                HStack {
                    Button {
                        // TODO: Show App Info/onboarding
                    } label: {
                        Label("App Info", systemImage: "info.circle")
                            .font(AppFonts.footnote)
                            .foregroundColor(AppColors.primaryText)
                    }
                    .accessibilityLabel("App Info")

                    Spacer()

                    Button {
                        // TODO: Show Privacy/Trust Center
                    } label: {
                        Label("Privacy", systemImage: "lock.shield")
                            .font(AppFonts.footnote)
                            .foregroundColor(AppColors.primaryText)
                    }
                    .accessibilityLabel("Privacy Policy")
                }
                .padding(.horizontal, AppSpacing.xSmall)
                .padding(.bottom, AppSpacing.medium)
            }
            .padding(.horizontal, AppSpacing.large)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [AppColors.background, AppColors.secondaryBackground]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationBarHidden(true) // Use for wider compatibility
            // TODO: Integrate audit logs, encryption, advanced authentication, etc.
        }
    }
    
    var isValid: Bool {
        !email.isEmpty && password.count >= 4 && email.contains("@")
    }
    
    func attemptLogin() {
        loginError = nil
        guard isValid else {
            loginError = "Enter a valid email and password."
            return
        }
        isLoggingIn = true
        // TODO: Integrate real authentication and audit logging here
        // Simulate async login (replace with your real auth logic)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isLoggingIn = false
            // TODO: Integrate role-based authentication using selectedRole
            if email.lowercased() == "owner@furfolio.com" && password == "demo" {
                onLoginSuccess?()
            } else {
                loginError = "Incorrect email or password."
            }
        }
    }
}

#Preview {
    LoginView()
}
