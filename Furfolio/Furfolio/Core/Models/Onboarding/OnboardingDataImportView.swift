//
//  OnboardingDataImportView.swift
//  Furfolio
//
//  Enhanced: tokenized, analytics/audit–ready, modular, previewable, accessible.
//

/**
 OnboardingDataImportView
 ------------------------
 A SwiftUI view for importing sample data during onboarding in Furfolio.

 - **Architecture**: MVVM-capable, dependency-injectable AnalyticsServiceProtocol and AuditLoggerProtocol.
 - **Concurrency & Async Logging**: Uses async/await for non-blocking analytics and audit calls wrapped in Tasks.
 - **Diagnostics**: Records import start, success, failure, and user actions for diagnostics.
 - **Localization**: All user-facing strings are localized via NSLocalizedString or LocalizedStringKey.
 - **Accessibility**: Interactive elements include accessibility labels and hints.
 - **Preview/Testability**: Previews inject mock async loggers and demo data manager.
 */

import SwiftUI

/// A record of an onboarding data import audit event.
public struct OnboardingDataImportAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let message: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), message: String) {
        self.id = id
        self.timestamp = timestamp
        self.message = message
    }
}

/// Manages concurrency-safe audit logging for data import events.
public actor OnboardingDataImportAuditManager {
    private var buffer: [OnboardingDataImportAuditEntry] = []
    private let maxEntries = 100
    public static let shared = OnboardingDataImportAuditManager()

    /// Add a new audit entry, capping to `maxEntries`.
    public func add(_ entry: OnboardingDataImportAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries.
    public func recent(limit: Int = 20) -> [OnboardingDataImportAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export audit log as JSON.
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

// MARK: - Analytics/Audit Logger Protocols

public protocol AnalyticsServiceProtocol {
    /// Log an analytics event asynchronously.
    func log(event: String, parameters: [String: Any]?) async
    /// Track a screen view asynchronously.
    func screenView(_ name: String) async
}

public protocol AuditLoggerProtocol {
    /// Record an audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
    /// Record a sensitive audit action asynchronously.
    func recordSensitive(_ action: String, userId: String) async
}

// MARK: - View

struct OnboardingDataImportView: View {
    // MARK: - Analytics / Audit (DI-ready)
    let analytics: AnalyticsServiceProtocol
    let audit: AuditLoggerProtocol
    let demoDataManager: DemoDataManagerProtocol

    // MARK: - Tokens
    let accent: Color
    let secondary: Color
    let success: Color
    let error: Color
    let background: Color
    let titleFont: Font
    let bodyFont: Font
    let buttonFont: Font
    let spacingL: CGFloat
    let spacingM: CGFloat
    let spacingS: CGFloat
    let spacingXL: CGFloat

    // MARK: - State
    enum ImportState {
        case idle, loading, success, failed(String)
    }
    @State private var importState: ImportState = .idle
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - DI/Token init (prod, preview, or test)
    init(
        analytics: AnalyticsServiceProtocol = AnalyticsService.shared,
        audit: AuditLoggerProtocol = AuditLogger.shared,
        demoDataManager: DemoDataManagerProtocol = DemoDataManager.shared,
        accent: Color = AppColors.accent ?? .accentColor,
        secondary: Color = AppColors.secondary ?? .secondary,
        success: Color = AppColors.success ?? .green,
        error: Color = AppColors.error ?? .red,
        background: Color = AppColors.background ?? Color(.systemBackground),
        titleFont: Font = AppFonts.title.bold() ?? .title.bold(),
        bodyFont: Font = AppFonts.body ?? .body,
        buttonFont: Font = AppFonts.headline ?? .headline,
        spacingL: CGFloat = AppSpacing.large ?? 24,
        spacingM: CGFloat = AppSpacing.medium ?? 16,
        spacingS: CGFloat = AppSpacing.small ?? 8,
        spacingXL: CGFloat = AppSpacing.extraLarge ?? 36
    ) {
        self.analytics = analytics
        self.audit = audit
        self.demoDataManager = demoDataManager
        self.accent = accent
        self.secondary = secondary
        self.success = success
        self.error = error
        self.background = background
        self.titleFont = titleFont
        self.bodyFont = bodyFont
        self.buttonFont = buttonFont
        self.spacingL = spacingL
        self.spacingM = spacingM
        self.spacingS = spacingS
        self.spacingXL = spacingXL
    }

    var body: some View {
        VStack(spacing: spacingL) {
            header
            description
            statusIndicator
            importButtons
        }
        .padding(spacingM)
        .background(background.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .onAppear {
            Task {
                await analytics.screenView("ImportView")
                await audit.record("Import view appeared", metadata: nil)
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: spacingM) {
            Image(systemName: "tray.and.arrow.down.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 64)
                .foregroundColor(accent)
                .accessibilityLabel(Text(NSLocalizedString("Import Icon", comment: "Accessibility label for import icon")))

            Text(LocalizedStringKey("Import Sample Data"))
                .font(titleFont)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(LocalizedStringKey("Get started faster by importing demo clients, appointments, and charge history. Or skip and add your own data later!"))
                .font(bodyFont)
                .multilineTextAlignment(.center)
                .foregroundColor(secondary)
        }
        .padding(.top, spacingXL)
        .padding(.horizontal)
    }

    private var description: some View {
        EmptyView() // Future description content
    }

    private var statusIndicator: some View {
        VStack(spacing: spacingS) {
            switch importState {
            case .loading:
                ProgressView(Text(NSLocalizedString("Importing…", comment: "Progress view label while importing")))
                    .progressViewStyle(CircularProgressViewStyle())
            case .success:
                Label {
                    Text(LocalizedStringKey("Demo data imported!"))
                        .font(buttonFont)
                } icon: {
                    Image(systemName: "checkmark.seal.fill")
                }
                .foregroundColor(success)
                .accessibilityLabel(Text(NSLocalizedString("Demo data successfully imported", comment: "Success state accessibility label")))
            case .failed(let message):
                Text(message)
                    .foregroundColor(error)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel(Text(NSLocalizedString("Import failed", comment: "Import failed accessibility label")))
            default:
                EmptyView()
            }
        }
        .padding(.horizontal)
    }

    private var importButtons: some View {
        VStack(spacing: spacingS) {
            Button {
                importDemoData()
            } label: {
                Label {
                    Text(LocalizedStringKey("Import Demo Data"))
                } icon: {
                    Image(systemName: "square.and.arrow.down")
                }
            }
            .buttonStyle(.borderedProminent)
            .font(buttonFont)
            .tint(accent)
            .disabled(importState == .loading || importState == .success)
            .accessibilityLabel(Text(NSLocalizedString("Import Demo Data", comment: "Button label for importing demo data")))
            .accessibilityHint(Text(NSLocalizedString("Starts importing demo data into the app", comment: "Accessibility hint for import demo data button")))

            Button {
                Task {
                    await analytics.log(event: "import_file_tap", parameters: nil)
                    await audit.record("User tapped import from file", metadata: nil)
                    await OnboardingDataImportAuditManager.shared.add(
                      OnboardingDataImportAuditEntry(message: "Tapped import from file")
                    )
                }
            } label: {
                Label {
                    Text(LocalizedStringKey("Import from File (CSV, JSON)"))
                } icon: {
                    Image(systemName: "doc.fill.badge.plus")
                }
            }
            .buttonStyle(.bordered)
            .font(buttonFont)
            .tint(secondary)
            .disabled(true)
            .accessibilityLabel(Text(NSLocalizedString("Import from File", comment: "Button label for importing from file")))
            .accessibilityHint(Text(NSLocalizedString("Coming soon: import data from CSV or JSON files", comment: "Accessibility hint for import from file button")))

            Button {
                Task {
                    await analytics.log(event: "import_skip_tap", parameters: nil)
                    await audit.record("User skipped import", metadata: nil)
                    await OnboardingDataImportAuditManager.shared.add(
                      OnboardingDataImportAuditEntry(message: "Skipped import")
                    )
                    dismiss()
                }
            } label: {
                Text(LocalizedStringKey("Skip"))
            }
            .font(buttonFont)
            .foregroundColor(accent)
            .padding(.top, spacingM)
            .accessibilityLabel(Text(NSLocalizedString("Skip", comment: "Button label to skip importing data")))
            .accessibilityHint(Text(NSLocalizedString("Skips data import and continues to the app", comment: "Accessibility hint for skip button")))
        }
    }

    // MARK: - Logic

    private func importDemoData() {
        importState = .loading
        Task {
            await analytics.log(event: "import_demo_data_start", parameters: nil)
            await audit.record("User started importing demo data", metadata: nil)
            await OnboardingDataImportAuditManager.shared.add(
              OnboardingDataImportAuditEntry(message: "Started demo import")
            )
        }

        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Simulated delay

            do {
                try await demoDataManager.populateDemoDataAsync(in: modelContext)
                importState = .success
                await analytics.log(event: "import_demo_data_success", parameters: nil)
                await audit.record("Demo data import succeeded", metadata: nil)
            } catch {
                importState = .failed(NSLocalizedString("Could not import demo data. Please try again.", comment: "Error message"))
                await analytics.log(event: "import_demo_data_failed", parameters: ["error": error.localizedDescription])
                await audit.record("Demo data import failed", metadata: ["error": error.localizedDescription])
            }
        }
    }
}

// MARK: - DemoDataManager Protocol for test/preview

public protocol DemoDataManagerProtocol {
    func populateDemoDataAsync(in context: ModelContext) async throws
}
extension DemoDataManager: DemoDataManagerProtocol {
    public func populateDemoDataAsync(in context: ModelContext) async throws {
        await populateDemoData(in: context)
    }
}

// MARK: - Previews

#Preview {
    struct MockAnalytics: AnalyticsServiceProtocol {
        func log(event: String, parameters: [String : Any]?) async {
            print("Mock Analytics: \(event)")
        }
        func screenView(_ name: String) async {}
    }
    struct MockAudit: AuditLoggerProtocol {
        func record(_ message: String, metadata: [String : String]?) async {
            print("Mock Audit: \(message)")
        }
        func recordSensitive(_ action: String, userId: String) async {}
    }
    struct MockDemoDataManager: DemoDataManagerProtocol {
        func populateDemoDataAsync(in context: ModelContext) async throws {}
    }

    return VStack {
        OnboardingDataImportView(
            analytics: MockAnalytics(),
            audit: MockAudit(),
            demoDataManager: MockDemoDataManager()
        )
        Button("Show Audit JSON") {
            Task {
                let json = OnboardingDataImportAuditManager.shared.exportJSON()
                print(json)
            }
        }
    }
}
