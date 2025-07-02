import SwiftUI

// MARK: - Analytics & Audit Protocols

public protocol LoginFlowAnalyticsLogger {
    /// Log a login flow event asynchronously.
    func log(event: String) async
}
public protocol LoginFlowAuditLogger {
    /// Record a login flow audit entry asynchronously.
    func record(_ event: String) async
}
public struct NullLoginFlowAnalyticsLogger: LoginFlowAnalyticsLogger {
    public init() {}
    public func log(event: String) async {}
}
public struct NullLoginFlowAuditLogger: LoginFlowAuditLogger {
    public init() {}
    public func record(_ event: String) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a login flow audit event.
public struct LoginFlowAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let detail: String?
    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String, detail: String? = nil) {
        self.id = id; self.timestamp = timestamp; self.event = event; self.detail = detail
    }
}
public actor LoginFlowAuditManager {
    private var buffer: [LoginFlowAuditEntry] = []
    private let maxEntries = 100
    public static let shared = LoginFlowAuditManager()
    public func add(_ entry: LoginFlowAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }
    public func recent(limit: Int = 20) -> [LoginFlowAuditEntry] {
        Array(buffer.suffix(limit))
    }
}

struct LoginFlowCoordinator: View {
    // Analytics & Audit
    let analytics: LoginFlowAnalyticsLogger
    let audit: LoginFlowAuditLogger

    @State private var showIntro: Bool = true
    @State private var showSplash: Bool = true

    public init(
        analytics: LoginFlowAnalyticsLogger = NullLoginFlowAnalyticsLogger(),
        audit: LoginFlowAuditLogger = NullLoginFlowAuditLogger()
    ) {
        self.analytics = analytics
        self.audit = audit
        _showIntro = State(initialValue: true)
        _showSplash = State(initialValue: true)
    }

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
                    Task {
                        await analytics.log(event: "splash_shown")
                        await audit.record("splash_shown")
                        await LoginFlowAuditManager.shared.add(
                            LoginFlowAuditEntry(event: "splash_shown")
                        )
                    }
                    withAnimation(.easeOut(duration: 1.2)) {
                        showSplash = false
                    }
                }
            }

            // Main Login Stack
            if showIntro {
                LoginIntroView {
                    Task {
                        await analytics.log(event: "intro_completed")
                        await audit.record("intro_completed")
                        await LoginFlowAuditManager.shared.add(
                            LoginFlowAuditEntry(event: "intro_completed")
                        )
                    }
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showIntro = false
                    }
                }
                .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
                    .accessibilityIdentifier("LoginView")
                    .task {
                        await analytics.log(event: "login_view_displayed")
                        await audit.record("login_view_displayed")
                        await LoginFlowAuditManager.shared.add(
                            LoginFlowAuditEntry(event: "login_view_displayed")
                        )
                    }
            }
        }
        .accessibilityIdentifier("LoginFlowCoordinatorStack")
    }
}

#Preview {
    LoginFlowCoordinator()
}
