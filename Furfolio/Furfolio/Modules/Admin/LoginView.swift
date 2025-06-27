//
//  LoginView.swift
//  Furfolio
//
//  Merged 2025: Unified, Auditable, Tokenized Login UI with Biometric Support
//

import SwiftUI
import LocalAuthentication

// MARK: - Roles

enum FurfolioRole: String, CaseIterable, Identifiable {
    case owner = "Owner"
    case assistant = "Assistant"
    var id: String { rawValue }
}

// MARK: - ViewModel (placeholder)

class LoginViewModel: ObservableObject {
    // Future implementation: bind to auth service
}

// MARK: - Audit Event

fileprivate struct LoginAuditEvent: Codable {
    let timestamp: Date
    let operation: String
    let email: String?
    let role: String?
    let rememberMe: Bool?
    let tags: [String]
    let actor: String?
    let context: String?
    let detail: String?

    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let roleStr = role ?? ""
        let remember = rememberMe == nil ? "" : (rememberMe! ? "Remembered" : "Not remembered")
        return "[\(operation.capitalized)] \(email ?? "") \(roleStr) \(remember) at \(dateStr)"
    }
}

fileprivate final class LoginAudit {
    static private(set) var log: [LoginAuditEvent] = []

    static func record(operation: String, email: String? = nil, role: String? = nil, rememberMe: Bool? = nil, tags: [String] = [], actor: String? = "user", context: String? = nil, detail: String? = nil) {
        let event = LoginAuditEvent(timestamp: Date(), operation: operation, email: email, role: role, rememberMe: rememberMe, tags: tags, actor: actor, context: context, detail: detail)
        log.append(event)
        if log.count > 1000 { log.removeFirst() }
    }

    static var lastSummary: String {
        log.last?.accessibilityLabel ?? "No login events recorded."
    }
}

// MARK: - Login View

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var rememberMe = false
    @State private var isLoggingIn = false
    @State private var loginError: String?
    @State private var selectedRole: FurfolioRole = .owner
    @FocusState private var focusedField: Field?
    @State private var biometricEnabled: Bool = false

    enum Field { case email, password }
    @StateObject var viewModel = LoginViewModel()
    var onLoginSuccess: (() -> Void)?

    var body: some View {
        NavigationView {
            VStack(spacing: AppSpacing.medium) {
                Spacer()

                Image(systemName: "pawprint.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)
                    .foregroundStyle(AppColors.primaryText)
                    .accessibilityLabel("Furfolio Logo")

                Text("Furfolio Login")
                    .font(AppFonts.largeTitle)
                    .foregroundColor(AppColors.primaryText)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: AppSpacing.small) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textContentType(.emailAddress)
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        .padding(AppSpacing.small)
                        .background(AppColors.secondaryBackground)
                        .cornerRadius(BorderRadius.medium)
                        .font(AppFonts.body)
                        .accessibilityLabel("Email")

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { attemptLogin() }
                        .padding(AppSpacing.small)
                        .background(AppColors.secondaryBackground)
                        .cornerRadius(BorderRadius.medium)
                        .font(AppFonts.body)
                        .accessibilityLabel("Password")

                    Picker("Role", selection: $selectedRole) {
                        ForEach(FurfolioRole.allCases) { role in
                            Text(role.rawValue).tag(role)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedRole) {
                        LoginAudit.record(operation: "roleChange", email: email, role: $0.rawValue, rememberMe: rememberMe, tags: ["role"], context: "LoginView")
                    }

                    Toggle("Remember Me", isOn: $rememberMe)
                        .onChange(of: rememberMe) {
                            LoginAudit.record(operation: "rememberToggle", email: email, role: selectedRole.rawValue, rememberMe: $0, tags: ["rememberMe"], context: "LoginView")
                        }

                    if biometricEnabled {
                        Button("Login with Face ID") {
                            performBiometricLogin()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if let error = loginError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(AppColors.error)
                        .padding()
                        .background(AppColors.errorBackground)
                        .cornerRadius(BorderRadius.small)
                }

                Button(action: attemptLogin) {
                    HStack {
                        if isLoggingIn { ProgressView().padding(.trailing) }
                        Text("Login").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoggingIn || !isValid)

                Button("Forgot Password?") {
                    LoginAudit.record(operation: "forgotPassword", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["forgot"], context: "LoginView")
                }
                .font(AppFonts.footnote)

                Spacer()

                HStack {
                    Button("App Info") {
                        LoginAudit.record(operation: "openAppInfo", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["info"], context: "LoginView")
                    }
                    Spacer()
                    Button("Privacy") {
                        LoginAudit.record(operation: "openPrivacy", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["privacy"], context: "LoginView")
                    }
                }
                .font(AppFonts.footnote)
                .padding(.horizontal)
            }
            .padding()
            .background(
                LinearGradient(gradient: Gradient(colors: [AppColors.background, AppColors.secondaryBackground]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .onAppear { checkBiometricAvailability() }
        }
    }

    var isValid: Bool {
        !email.isEmpty && password.count >= 4 && email.contains("@")
    }

    func attemptLogin() {
        loginError = nil
        guard isValid else {
            loginError = "Enter a valid email and password."
            LoginAudit.record(operation: "loginFailure", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["failure", "invalid"], context: "LoginView", detail: loginError)
            return
        }

        isLoggingIn = true
        LoginAudit.record(operation: "loginAttempt", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["login"], context: "LoginView")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isLoggingIn = false
            if email.lowercased() == "owner@furfolio.com" && password == "demo" {
                LoginAudit.record(operation: "loginSuccess", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["success"], context: "LoginView")
                onLoginSuccess?()
            } else {
                loginError = "Incorrect email or password."
                LoginAudit.record(operation: "loginFailure", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["authFailed"], context: "LoginView", detail: loginError)
            }
        }
    }

    func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricEnabled = true
        }
    }

    func performBiometricLogin() {
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Login with Face ID") { success, error in
            DispatchQueue.main.async {
                if success {
                    LoginAudit.record(operation: "loginSuccess", email: "(biometric)", role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["biometric", "success"], context: "LoginView")
                    onLoginSuccess?()
                } else {
                    loginError = "Biometric login failed."
                    LoginAudit.record(operation: "loginFailure", email: "(biometric)", role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["biometric", "failure"], context: "LoginView", detail: loginError)
                }
            }
        }
    }
}

#Preview {
    LoginView()
}

