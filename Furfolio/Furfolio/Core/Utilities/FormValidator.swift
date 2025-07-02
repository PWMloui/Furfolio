//
//  FormValidator.swift
//  Furfolio
//
//  Enhanced: Modular, Tokenized, Auditable Form Validation Utility (2025+)
//

import Foundation
import SwiftUI

// MARK: - Analytics & Audit Protocols

public protocol FormValidatorAnalyticsLogger {
    /// Log a validation event asynchronously.
    func log(event: String, field: String?, value: String?, error: String?, tags: [String]) async
}

public protocol FormValidatorAuditLogger {
    /// Record a validation audit entry asynchronously.
    func record(event: String, field: String?, value: String?, error: String?, tags: [String]) async
}

public struct NullFormValidatorAnalyticsLogger: FormValidatorAnalyticsLogger {
    public init() {}
    public func log(event: String, field: String?, value: String?, error: String?, tags: [String]) async {}
}

public struct NullFormValidatorAuditLogger: FormValidatorAuditLogger {
    public init() {}
    public func record(event: String, field: String?, value: String?, error: String?, tags: [String]) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a form validation event.
public struct FormValidatorAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let field: String?
    public let value: String?
    public let error: String?
    public let tags: [String]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        event: String,
        field: String? = nil,
        value: String? = nil,
        error: String? = nil,
        tags: [String]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.field = field
        self.value = value
        self.error = error
        self.tags = tags
    }

    public var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let status = error == nil ? "✅" : "❌"
        let fieldStr = field ?? ""
        let msg = error ?? ""
        return "\(status) \(event) \(fieldStr.isEmpty ? "" : "\"\(fieldStr)\" ")at \(dateStr)\(msg.isEmpty ? "" : ": \(msg)")"
    }
}

/// Actor for concurrency-safe logging of validation events.
public actor FormValidatorAuditManager {
    private var buffer: [FormValidatorAuditEntry] = []
    private let maxEntries = 1000
    public static let shared = FormValidatorAuditManager()

    public func add(_ entry: FormValidatorAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 20) -> [FormValidatorAuditEntry] {
        Array(buffer.suffix(limit))
    }

    public func exportLastJSON() -> String? {
        guard let last = buffer.last else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    public var accessibilitySummary: String {
        recent(limit: 1).first?.accessibilityLabel ?? "No validation events recorded."
    }
}

// MARK: - FormValidator (Modular, Tokenized, Auditable)

enum FormValidator {
    // MARK: - Localization Messages

    private struct Messages {
        static let requiredField = NSLocalizedString("Required Field", comment: "Generic required field error message")
        static let invalidEmail = NSLocalizedString("Invalid Email Address", comment: "Email validation error message")
        static let invalidPhone = NSLocalizedString("Invalid Phone Number", comment: "Phone validation error message")
        static let invalidValue = NSLocalizedString("Invalid Value", comment: "Generic invalid value error message")
        static let lengthMin = NSLocalizedString("Must be at least %d characters", comment: "Minimum length error message")
        static let lengthMax = NSLocalizedString("Must be less than %d characters", comment: "Maximum length error message")
        static let rangeError = NSLocalizedString("Must be between %@ and %@", comment: "Numeric range error message")

        // DogOwner
        static let ownerNameRequired = NSLocalizedString("Owner Name Required", comment: "DogOwner name required error")
        static let ownerEmailInvalid = NSLocalizedString("Enter a Valid Email (Optional or Blank Allowed)", comment: "DogOwner email validation guidance")
        static let ownerPhoneInvalid = NSLocalizedString("Enter a Valid Phone (Optional or Blank Allowed)", comment: "DogOwner phone validation guidance")
        // Dog
        static let dogNameRequired = NSLocalizedString("Dog Name Required", comment: "Dog name required error")
        static let dogBreedRequired = NSLocalizedString("Dog Breed Required", comment: "Dog breed required error")
        // Appointment
        static let appointmentDateRequired = NSLocalizedString("Appointment Date Required", comment: "Appointment date required error")
        static let appointmentDogRequired = NSLocalizedString("Select a Dog", comment: "Appointment dog selection required error")
        static let appointmentOwnerRequired = NSLocalizedString("Select an Owner", comment: "Appointment owner selection required error")
        // Charge
        static let chargeAmountRequired = NSLocalizedString("Amount Required", comment: "Charge amount required error")
        static let chargeAmountRange = NSLocalizedString("Amount Must Be 1–9999", comment: "Charge amount range error")
        static let chargeTypeRequired = NSLocalizedString("Select a Charge Type", comment: "Charge type selection required error")
    }

    // MARK: - Field Validation

    static func required(
        _ value: String?,
        error: String = Messages.requiredField,
        field: String? = nil,
        actor: String? = nil,
        context: String? = nil
    ) -> ValidationResult {
        let isValid = value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        if !isValid {
            Task {
                await FormValidatorAuditManager.shared.add(
                    FormValidatorAuditEntry(
                        event: "validateField",
                        field: field,
                        value: value,
                        error: error,
                        tags: ["required"]
                    )
                )
            }
            return .invalid(error)
        }
        Task {
            await FormValidatorAuditManager.shared.add(
                FormValidatorAuditEntry(
                    event: "validateField",
                    field: field,
                    value: value,
                    error: nil,
                    tags: ["required"]
                )
            )
        }
        return .valid
    }

    static func length(
        _ value: String?,
        min: Int = 0,
        max: Int = .max,
        error: String? = nil,
        field: String? = nil,
        actor: String? = nil,
        context: String? = nil
    ) -> ValidationResult {
        let count = value?.count ?? 0
        if count < min {
            let msg = error ?? String(format: Messages.lengthMin, min)
            Task {
                await FormValidatorAuditManager.shared.add(
                    FormValidatorAuditEntry(
                        event: "validateField",
                        field: field,
                        value: value,
                        error: msg,
                        tags: ["length", "min"]
                    )
                )
            }
            return .invalid(msg)
        }
        if count > max {
            let msg = error ?? String(format: Messages.lengthMax, max + 1)
            Task {
                await FormValidatorAuditManager.shared.add(
                    FormValidatorAuditEntry(
                        event: "validateField",
                        field: field,
                        value: value,
                        error: msg,
                        tags: ["length", "max"]
                    )
                )
            }
            return .invalid(msg)
        }
        Task {
            await FormValidatorAuditManager.shared.add(
                FormValidatorAuditEntry(
                    event: "validateField",
                    field: field,
                    value: value,
                    error: nil,
                    tags: ["length"]
                )
            )
        }
        return .valid
    }

    static func email(
        _ value: String?,
        error: String = Messages.invalidEmail,
        field: String? = nil,
        actor: String? = nil,
        context: String? = nil
    ) -> ValidationResult {
        if let v = value, !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if !StringUtils.isValidEmail(v) {
                Task {
                    await FormValidatorAuditManager.shared.add(
                        FormValidatorAuditEntry(
                            event: "validateField",
                            field: field,
                            value: value,
                            error: error,
                            tags: ["email"]
                        )
                    )
                }
                return .invalid(error)
            }
        }
        Task {
            await FormValidatorAuditManager.shared.add(
                FormValidatorAuditEntry(
                    event: "validateField",
                    field: field,
                    value: value,
                    error: nil,
                    tags: ["email"]
                )
            )
        }
        return .valid
    }

    static func phone(
        _ value: String?,
        error: String = Messages.invalidPhone,
        field: String? = nil,
        actor: String? = nil,
        context: String? = nil
    ) -> ValidationResult {
        if let v = value, !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if !StringUtils.isValidPhone(v) {
                Task {
                    await FormValidatorAuditManager.shared.add(
                        FormValidatorAuditEntry(
                            event: "validateField",
                            field: field,
                            value: value,
                            error: error,
                            tags: ["phone"]
                        )
                    )
                }
                return .invalid(error)
            }
        }
        Task {
            await FormValidatorAuditManager.shared.add(
                FormValidatorAuditEntry(
                    event: "validateField",
                    field: field,
                    value: value,
                    error: nil,
                    tags: ["phone"]
                )
            )
        }
        return .valid
    }

    static func range<T: Comparable & LosslessStringConvertible>(
        _ value: String?,
        min: T,
        max: T,
        error: String? = nil,
        field: String? = nil,
        actor: String? = nil,
        context: String? = nil
    ) -> ValidationResult {
        guard let v = value, let num = T(v) else {
            let msg = error ?? Messages.invalidValue
            Task {
                await FormValidatorAuditManager.shared.add(
                    FormValidatorAuditEntry(
                        event: "validateField",
                        field: field,
                        value: value,
                        error: msg,
                        tags: ["range"]
                    )
                )
            }
            return .invalid(msg)
        }
        if num < min || num > max {
            let msg = error ?? String(format: Messages.rangeError, String(describing: min), String(describing: max))
            Task {
                await FormValidatorAuditManager.shared.add(
                    FormValidatorAuditEntry(
                        event: "validateField",
                        field: field,
                        value: value,
                        error: msg,
                        tags: ["range"]
                    )
                )
            }
            return .invalid(msg)
        }
        Task {
            await FormValidatorAuditManager.shared.add(
                FormValidatorAuditEntry(
                    event: "validateField",
                    field: field,
                    value: value,
                    error: nil,
                    tags: ["range"]
                )
            )
        }
        return .valid
    }

    // MARK: - Model Object Validation

    static func validateDogOwner(
        name: String?,
        email: String?,
        phone: String?,
        actor: String? = nil,
        context: String? = nil
    ) -> [ValidationResult] {
        let results = [
            required(name, error: Messages.ownerNameRequired, field: "ownerName", actor: actor, context: context),
            email(email, error: Messages.ownerEmailInvalid, field: "ownerEmail", actor: actor, context: context),
            phone(phone, error: Messages.ownerPhoneInvalid, field: "ownerPhone", actor: actor, context: context)
        ].filter { !$0.isValid }
        Task {
            await FormValidatorAuditManager.shared.add(
                FormValidatorAuditEntry(
                    event: "validateObject",
                    field: "DogOwner",
                    value: nil,
                    error: results.first?.message,
                    tags: ["object", "DogOwner"]
                )
            )
        }
        return results
    }

    static func validateDog(
        name: String?,
        breed: String?,
        actor: String? = nil,
        context: String? = nil
    ) -> [ValidationResult] {
        let results = [
            required(name, error: Messages.dogNameRequired, field: "dogName", actor: actor, context: context),
            required(breed, error: Messages.dogBreedRequired, field: "dogBreed", actor: actor, context: context)
        ].filter { !$0.isValid }
        Task {
            await FormValidatorAuditManager.shared.add(
                FormValidatorAuditEntry(
                    event: "validateObject",
                    field: "Dog",
                    value: nil,
                    error: results.first?.message,
                    tags: ["object", "Dog"]
                )
            )
        }
        return results
    }

    static func validateAppointment(
        date: Date?,
        dog: Dog?,
        owner: DogOwner?,
        actor: String? = nil,
        context: String? = nil
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        if date == nil { results.append(.invalid(Messages.appointmentDateRequired)) }
        if dog == nil { results.append(.invalid(Messages.appointmentDogRequired)) }
        if owner == nil { results.append(.invalid(Messages.appointmentOwnerRequired)) }
        let err = results.first?.message
        Task {
            await FormValidatorAuditManager.shared.add(
                FormValidatorAuditEntry(
                    event: "validateObject",
                    field: "Appointment",
                    value: nil,
                    error: err,
                    tags: ["object", "Appointment"]
                )
            )
        }
        return results
    }

    static func validateCharge(
        amount: String?,
        type: ChargeType?,
        actor: String? = nil,
        context: String? = nil
    ) -> [ValidationResult] {
        let results = [
            required(amount, error: Messages.chargeAmountRequired, field: "chargeAmount", actor: actor, context: context),
            range(amount, min: 1.0, max: 9999.0, error: Messages.chargeAmountRange, field: "chargeAmount", actor: actor, context: context),
            type == nil ? .invalid(Messages.chargeTypeRequired) : .valid
        ].filter { !$0.isValid }
        Task {
            await FormValidatorAuditManager.shared.add(
                FormValidatorAuditEntry(
                    event: "validateObject",
                    field: "Charge",
                    value: nil,
                    error: results.first?.message,
                    tags: ["object", "Charge"]
                )
            )
        }
        return results
    }

    // MARK: - Future Validation Stubs

    static func validateBusiness(actor: String? = nil, context: String? = nil) -> [ValidationResult] {
        // TODO: Implement business validations
        Task {
            await FormValidatorAuditManager.shared.add(
                FormValidatorAuditEntry(
                    event: "validateObject",
                    field: "Business",
                    value: nil,
                    error: nil,
                    tags: ["object", "Business"]
                )
            )
        }
        return []
    }

    static func validateInventory(actor: String? = nil, context: String? = nil) -> [ValidationResult] {
        // TODO: Implement inventory validations
        Task {
            await FormValidatorAuditManager.shared.add(
                FormValidatorAuditEntry(
                    event: "validateObject",
                    field: "Inventory",
                    value: nil,
                    error: nil,
                    tags: ["object", "Inventory"]
                )
            )
        }
        return []
    }

    static func validateExpense(actor: String? = nil, context: String? = nil) -> [ValidationResult] {
        // TODO: Implement expense validations
        Task {
            await FormValidatorAuditManager.shared.add(
                FormValidatorAuditEntry(
                    event: "validateObject",
                    field: "Expense",
                    value: nil,
                    error: nil,
                    tags: ["object", "Expense"]
                )
            )
        }
        return []
    }

    // MARK: - Audit/Admin Accessors

    static var lastAuditSummary: String {
        await FormValidatorAuditManager.shared.accessibilitySummary
    }

    static func lastAuditJSON() async -> String? {
        await FormValidatorAuditManager.shared.exportLastJSON()
    }

    static func recentAuditEvents(limit: Int = 5) async -> [String] {
        await FormValidatorAuditManager.shared.recent(limit: limit)
            .map { $0.accessibilityLabel }
    }
}

/// Represents the result of validating a field or form.
enum ValidationResult: Equatable {
    case valid
    case invalid(String)
    var isValid: Bool { if case .valid = self { return true } else { return false } }
    var message: String? { if case .invalid(let m) = self { return m } else { return nil } }
}
