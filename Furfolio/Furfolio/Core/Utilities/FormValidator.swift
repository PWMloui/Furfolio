//
//  FormValidator.swift
//  Furfolio
//
//  Enhanced: Modular, Tokenized, Auditable Form Validation Utility (2025+)
//

import Foundation

// MARK: - Audit/Event Logging for Validation

fileprivate struct FormValidatorAuditEvent: Codable {
    let timestamp: Date
    let operation: String                // e.g. "validateField", "validateObject"
    let field: String?
    let value: String?
    let error: String?
    let tags: [String]
    let actor: String?
    let context: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let status = error == nil ? "✅" : "❌"
        let fieldStr = field ?? ""
        let msg = error ?? ""
        return "\(status) \(operation) \(fieldStr.isEmpty ? "" : "\"\(fieldStr)\" ")at \(dateStr)\(msg.isEmpty ? "" : ": \(msg)")"
    }
}

fileprivate final class FormValidatorAudit {
    static private(set) var log: [FormValidatorAuditEvent] = []

    static func record(
        operation: String,
        field: String? = nil,
        value: String? = nil,
        error: String? = nil,
        tags: [String] = [],
        actor: String? = nil,
        context: String? = nil
    ) {
        let event = FormValidatorAuditEvent(
            timestamp: Date(),
            operation: operation,
            field: field,
            value: value,
            error: error,
            tags: tags,
            actor: actor,
            context: context
        )
        log.append(event)
        if log.count > 1000 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No validation events recorded."
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
            FormValidatorAudit.record(operation: "validateField", field: field, value: value, error: error, tags: ["required"], actor: actor, context: context)
            return .invalid(error)
        }
        FormValidatorAudit.record(operation: "validateField", field: field, value: value, tags: ["required"], actor: actor, context: context)
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
            FormValidatorAudit.record(operation: "validateField", field: field, value: value, error: msg, tags: ["length", "min"], actor: actor, context: context)
            return .invalid(msg)
        }
        if count > max {
            let msg = error ?? String(format: Messages.lengthMax, max + 1)
            FormValidatorAudit.record(operation: "validateField", field: field, value: value, error: msg, tags: ["length", "max"], actor: actor, context: context)
            return .invalid(msg)
        }
        FormValidatorAudit.record(operation: "validateField", field: field, value: value, tags: ["length"], actor: actor, context: context)
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
                FormValidatorAudit.record(operation: "validateField", field: field, value: value, error: error, tags: ["email"], actor: actor, context: context)
                return .invalid(error)
            }
        }
        FormValidatorAudit.record(operation: "validateField", field: field, value: value, tags: ["email"], actor: actor, context: context)
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
                FormValidatorAudit.record(operation: "validateField", field: field, value: value, error: error, tags: ["phone"], actor: actor, context: context)
                return .invalid(error)
            }
        }
        FormValidatorAudit.record(operation: "validateField", field: field, value: value, tags: ["phone"], actor: actor, context: context)
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
            FormValidatorAudit.record(operation: "validateField", field: field, value: value, error: msg, tags: ["range"], actor: actor, context: context)
            return .invalid(msg)
        }
        if num < min || num > max {
            let msg = error ?? String(format: Messages.rangeError, String(describing: min), String(describing: max))
            FormValidatorAudit.record(operation: "validateField", field: field, value: value, error: msg, tags: ["range"], actor: actor, context: context)
            return .invalid(msg)
        }
        FormValidatorAudit.record(operation: "validateField", field: field, value: value, tags: ["range"], actor: actor, context: context)
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
        FormValidatorAudit.record(operation: "validateObject", field: "DogOwner", tags: ["object", "DogOwner"], actor: actor, context: context, error: results.first?.message)
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
        FormValidatorAudit.record(operation: "validateObject", field: "Dog", tags: ["object", "Dog"], actor: actor, context: context, error: results.first?.message)
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
        FormValidatorAudit.record(operation: "validateObject", field: "Appointment", tags: ["object", "Appointment"], actor: actor, context: context, error: err)
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
        FormValidatorAudit.record(operation: "validateObject", field: "Charge", tags: ["object", "Charge"], actor: actor, context: context, error: results.first?.message)
        return results
    }

    // MARK: - Future Validation Stubs

    static func validateBusiness(actor: String? = nil, context: String? = nil) -> [ValidationResult] {
        // TODO: Implement business validations
        FormValidatorAudit.record(operation: "validateObject", field: "Business", tags: ["object", "Business"], actor: actor, context: context)
        return []
    }

    static func validateInventory(actor: String? = nil, context: String? = nil) -> [ValidationResult] {
        // TODO: Implement inventory validations
        FormValidatorAudit.record(operation: "validateObject", field: "Inventory", tags: ["object", "Inventory"], actor: actor, context: context)
        return []
    }

    static func validateExpense(actor: String? = nil, context: String? = nil) -> [ValidationResult] {
        // TODO: Implement expense validations
        FormValidatorAudit.record(operation: "validateObject", field: "Expense", tags: ["object", "Expense"], actor: actor, context: context)
        return []
    }

    // MARK: - Audit/Admin Accessors

    static var lastAuditSummary: String { FormValidatorAudit.accessibilitySummary }
    static var lastAuditJSON: String? { FormValidatorAudit.exportLastJSON() }
    static func recentAuditEvents(limit: Int = 5) -> [String] {
        FormValidatorAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

/// Represents the result of validating a field or form.
enum ValidationResult: Equatable {
    case valid
    case invalid(String)
    var isValid: Bool { if case .valid = self { return true } else { return false } }
    var message: String? { if case .invalid(let m) = self { return m } else { return nil } }
}
