/// Represents a logged crash, fatal error, or serious exception within the Furfolio app.
///
/// This model captures critical error information for diagnostics and user support.
/// It is essential that all user-facing strings, especially the `type` values, are localized appropriately.
/// Additionally, this class should integrate with audit and analytics systems to ensure compliance
/// with Trust Center policies and business intelligence requirements.
/// 
/// TODO: Extend with more device/environment data (e.g., app version, OS version) in future versions.
/// TODO: Consider an extension or protocol for automatic audit logging when a new `CrashReport` is created.
@Model
final class CrashReport: Identifiable, ObservableObject {

    // MARK: - Constants

    static let typeCrash = "Crash" // TODO: Localize before display in UI
    static let typeFatalError = "Fatal Error" // TODO: Localize before display in UI
    static let typeDataCorruption = "Data Corruption" // TODO: Localize before display in UI

    // MARK: - Properties

    /// Unique identifier for the report.
    @Attribute(.unique)
    var id: UUID

    /// The date and time when the issue occurred.
    var date: Date

    /// The classification of the crash (e.g., Crash, Fatal Error).
    var type: String

    /// A brief summary or message describing the error.
    var message: String

    /// The call stack at the time of the crash (if available).
    var stackTrace: String?

    /// Summary of the device environment at the time.
    var deviceInfo: String?

    /// Whether the issue has been resolved or acknowledged by the user or system.
    var resolved: Bool

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        type: String,
        message: String,
        stackTrace: String? = nil,
        deviceInfo: String? = nil,
        resolved: Bool = false
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.message = message
        self.stackTrace = stackTrace
        self.deviceInfo = deviceInfo
        self.resolved = resolved
    }

    // MARK: - Computed Properties

    /// A human-readable timestamp for UI display.
    ///
    /// NOTE: Any display of this date in the UI must use `AppFonts.caption` and `AppColors.textSecondary`
    /// to comply with design token standards, rather than system defaults.
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
