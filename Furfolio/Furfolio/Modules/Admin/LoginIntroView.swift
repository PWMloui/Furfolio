
import SwiftUI

// MARK: - Analytics & Audit Protocols

public protocol LoginIntroAnalyticsLogger {
    /// Log a login intro event asynchronously.
    func log(event: String) async
}

public protocol LoginIntroAuditLogger {
    /// Record a login intro audit entry asynchronously.
    func record(_ event: String) async
}

public struct NullLoginIntroAnalyticsLogger: LoginIntroAnalyticsLogger {
    public init() {}
    public func log(event: String) async {}
}

public struct NullLoginIntroAuditLogger: LoginIntroAuditLogger {
    public init() {}
    public func record(_ event: String) async {}
}

/// A record of a login intro audit event.
public struct LoginIntroAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
    }
}

/// Concurrency-safe actor for logging login intro events.
public actor LoginIntroAuditManager {
    private var buffer: [LoginIntroAuditEntry] = []
    private let maxEntries = 100
    public static let shared = LoginIntroAuditManager()

    public func add(_ entry: LoginIntroAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 20) -> [LoginIntroAuditEntry] {
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

struct LoginIntroView: View {
    // Analytics & Audit
    let analytics: LoginIntroAnalyticsLogger
    let audit: LoginIntroAuditLogger
    var onContinue: () -> Void

    public init(
        analytics: LoginIntroAnalyticsLogger = NullLoginIntroAnalyticsLogger(),
        audit: LoginIntroAuditLogger = NullLoginIntroAuditLogger(),
        onContinue: @escaping () -> Void
    ) {
        self.analytics = analytics
        self.audit = audit
        self.onContinue = onContinue
    }

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
                Task {
                    await analytics.log(event: "continue_tapped")
                    await audit.record("continue_tapped")
                    await LoginIntroAuditManager.shared.add(
                        LoginIntroAuditEntry(event: "continue_tapped")
                    )
                }
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
