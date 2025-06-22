/// Represents a logged crash, fatal error, or serious exception within the Furfolio app.
@Model
final class CrashReport: Identifiable, ObservableObject {

    // MARK: - Constants

    static let typeCrash = "Crash"
    static let typeFatalError = "Fatal Error"
    static let typeDataCorruption = "Data Corruption"

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
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
