//
//  LoginView.swift
//  Furfolio
//
//  Merged 2025: Unified, Auditable, Tokenized Login UI with Biometric Support
//


import SwiftUI
import LocalAuthentication

// MARK: - Analytics & Audit Protocols

public protocol LoginAnalyticsLogger {
    /// Log a login event asynchronously.
    func log(event: String, email: String?, role: String?, rememberMe: Bool?, tags: [String]) async
}

public protocol LoginAuditLogger {
    /// Record a login audit entry asynchronously.
    func record(event: String, email: String?, role: String?, rememberMe: Bool?, tags: [String], detail: String?) async
}

public struct NullLoginAnalyticsLogger: LoginAnalyticsLogger {
    public init() {}
    public func log(event: String, email: String?, role: String?, rememberMe: Bool?, tags: [String]) async {}
}

public struct NullLoginAuditLogger: LoginAuditLogger {
    public init() {}
    public func record(event: String, email: String?, role: String?, rememberMe: Bool?, tags: [String], detail: String?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a login flow audit event.
public struct LoginAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let email: String?
    public let role: String?
    public let rememberMe: Bool?
    public let tags: [String]
    public let detail: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        event: String,
        email: String? = nil,
        role: String? = nil,
        rememberMe: Bool? = nil,
        tags: [String] = [],
        detail: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.email = email
        self.role = role
        self.rememberMe = rememberMe
        self.tags = tags
        self.detail = detail
    }
}

/// Concurrency-safe actor for logging login events.
public actor LoginAuditManager {
    private var buffer: [LoginAuditEntry] = []
    private let maxEntries = 1000
    public static let shared = LoginAuditManager()

    public func add(_ entry: LoginAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 20) -> [LoginAuditEntry] {
        Array(buffer.suffix(limit))
    }

    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(buffer),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

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

    // Analytics & Audit
    let analytics: LoginAnalyticsLogger
    let audit: LoginAuditLogger

    public init(
        analytics: LoginAnalyticsLogger = NullLoginAnalyticsLogger(),
        audit: LoginAuditLogger = NullLoginAuditLogger(),
        onLoginSuccess: (() -> Void)? = nil
    ) {
        self.analytics = analytics
        self.audit = audit
        self.onLoginSuccess = onLoginSuccess
    }

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
                        Task {
                            await analytics.log(event: "roleChange", email: email, role: $0.rawValue, rememberMe: rememberMe, tags: ["role"])
                            await audit.record(event: "roleChange", email: email, role: $0.rawValue, rememberMe: rememberMe, tags: ["role"], detail: nil)
                            await LoginAuditManager.shared.add(
                                LoginAuditEntry(event: "roleChange", email: email, role: $0.rawValue, rememberMe: rememberMe, tags: ["role"])
                            )
                        }
                    }

                    Toggle("Remember Me", isOn: $rememberMe)
                        .onChange(of: rememberMe) {
                            Task {
                                await analytics.log(event: "rememberToggle", email: email, role: selectedRole.rawValue, rememberMe: $0, tags: ["rememberMe"])
                                await audit.record(event: "rememberToggle", email: email, role: selectedRole.rawValue, rememberMe: $0, tags: ["rememberMe"], detail: nil)
                                await LoginAuditManager.shared.add(
                                    LoginAuditEntry(event: "rememberToggle", email: email, role: selectedRole.rawValue, rememberMe: $0, tags: ["rememberMe"])
                                )
                            }
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
                    Task {
                        await analytics.log(event: "forgotPassword", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["forgot"])
                        await audit.record(event: "forgotPassword", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["forgot"], detail: nil)
                        await LoginAuditManager.shared.add(
                            LoginAuditEntry(event: "forgotPassword", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["forgot"])
                        )
                    }
                }
                .font(AppFonts.footnote)

                Spacer()

                HStack {
                    Button("App Info") {
                        Task {
                            await analytics.log(event: "openAppInfo", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["info"])
                            await audit.record(event: "openAppInfo", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["info"], detail: nil)
                            await LoginAuditManager.shared.add(
                                LoginAuditEntry(event: "openAppInfo", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["info"])
                            )
                        }
                    }
                    Spacer()
                    Button("Privacy") {
                        Task {
                            await analytics.log(event: "openPrivacy", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["privacy"])
                            await audit.record(event: "openPrivacy", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["privacy"], detail: nil)
                            await LoginAuditManager.shared.add(
                                LoginAuditEntry(event: "openPrivacy", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["privacy"])
                            )
                        }
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
            Task {
                await analytics.log(event: "loginFailure", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["failure", "invalid"])
                await audit.record(event: "loginFailure", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["failure", "invalid"], detail: loginError)
                await LoginAuditManager.shared.add(
                    LoginAuditEntry(event: "loginFailure", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["failure", "invalid"], detail: loginError)
                )
            }
            return
        }

        isLoggingIn = true
        Task {
            await analytics.log(event: "loginAttempt", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["login"])
            await audit.record(event: "loginAttempt", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["login"], detail: nil)
            await LoginAuditManager.shared.add(
                LoginAuditEntry(event: "loginAttempt", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["login"])
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isLoggingIn = false
            if email.lowercased() == "owner@furfolio.com" && password == "demo" {
                Task {
                    await analytics.log(event: "loginSuccess", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["success"])
                    await audit.record(event: "loginSuccess", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["success"], detail: nil)
                    await LoginAuditManager.shared.add(
                        LoginAuditEntry(event: "loginSuccess", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["success"])
                    )
                }
                onLoginSuccess?()
            } else {
                loginError = "Incorrect email or password."
                Task {
                    await analytics.log(event: "loginFailure", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["authFailed"])
                    await audit.record(event: "loginFailure", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["authFailed"], detail: loginError)
                    await LoginAuditManager.shared.add(
                        LoginAuditEntry(event: "loginFailure", email: email, role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["authFailed"], detail: loginError)
                    )
                }
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
                    Task {
                        await analytics.log(event: "loginSuccess", email: "(biometric)", role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["biometric", "success"])
                        await audit.record(event: "loginSuccess", email: "(biometric)", role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["biometric", "success"], detail: nil)
                        await LoginAuditManager.shared.add(
                            LoginAuditEntry(event: "loginSuccess", email: "(biometric)", role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["biometric", "success"])
                        )
                    }
                    onLoginSuccess?()
                } else {
                    loginError = "Biometric login failed."
                    Task {
                        await analytics.log(event: "loginFailure", email: "(biometric)", role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["biometric", "failure"])
                        await audit.record(event: "loginFailure", email: "(biometric)", role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["biometric", "failure"], detail: loginError)
                        await LoginAuditManager.shared.add(
                            LoginAuditEntry(event: "loginFailure", email: "(biometric)", role: selectedRole.rawValue, rememberMe: rememberMe, tags: ["biometric", "failure"], detail: loginError)
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    LoginView()
}

