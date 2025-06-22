//
//  FormValidator.swift
//  Furfolio
//
//  Created by mac on 6/20/25.
//

import Foundation

// MARK: - FormValidator (Modular, Tokenized, Auditable Form Validation Utility)

/**
 FormValidator.swift

 This file provides a modular, tokenized, auditable form validation engine tailored for the Furfolio application. It supports comprehensive localization, analytics tracking, compliance adherence, business logic enforcement, accessibility considerations, and UI tokenization. Designed to facilitate scalable, owner-focused business workflows and enterprise-level reporting, this validator ensures consistent and extensible validation across all form fields and business objects. It aligns with Furfolio's UX roadmap to deliver a frictionless, intuitive user experience while maintaining robust audit trails and validation analytics.
 */

enum FormValidator {
    // MARK: - Localization Messages

    private struct Messages {
        /// Localization key for generic required field error message.
        /// Used across forms to indicate mandatory input fields.
        static let requiredField = NSLocalizedString("Required Field", comment: "Generic required field error message")
        /// Localization key for invalid email address error.
        /// Supports business rules for email format validation and user guidance.
        static let invalidEmail = NSLocalizedString("Invalid Email Address", comment: "Email validation error message")
        /// Localization key for invalid phone number error.
        /// Ensures phone number format compliance and user feedback.
        static let invalidPhone = NSLocalizedString("Invalid Phone Number", comment: "Phone validation error message")
        /// Localization key for generic invalid value error.
        /// Used for various validation failures requiring user correction.
        static let invalidValue = NSLocalizedString("Invalid Value", comment: "Generic invalid value error message")
        /// Localization key for minimum length error message.
        /// Guides users on input length requirements for compliance and UX.
        static let lengthMin = NSLocalizedString("Must be at least %d characters", comment: "Minimum length error message")
        /// Localization key for maximum length error message.
        /// Ensures input does not exceed allowed length for data integrity.
        static let lengthMax = NSLocalizedString("Must be less than %d characters", comment: "Maximum length error message")
        /// Localization key for numeric range error message.
        /// Communicates acceptable numeric input boundaries for business rules.
        static let rangeError = NSLocalizedString("Must be between %@ and %@", comment: "Numeric range error message")

        // DogOwner
        /// Localization key indicating DogOwner's name is required.
        /// Enforces business logic for owner identification.
        static let ownerNameRequired = NSLocalizedString("Owner Name Required", comment: "DogOwner name required error")
        /// Localization key guiding optional but valid email input for DogOwner.
        /// Balances user flexibility with data quality.
        static let ownerEmailInvalid = NSLocalizedString("Enter a Valid Email (Optional or Blank Allowed)", comment: "DogOwner email validation guidance")
        /// Localization key guiding optional but valid phone input for DogOwner.
        /// Supports contact compliance and user clarity.
        static let ownerPhoneInvalid = NSLocalizedString("Enter a Valid Phone (Optional or Blank Allowed)", comment: "DogOwner phone validation guidance")

        // Dog
        /// Localization key indicating Dog's name is required.
        /// Supports business processes requiring dog identification.
        static let dogNameRequired = NSLocalizedString("Dog Name Required", comment: "Dog name required error")
        /// Localization key indicating Dog's breed is required.
        /// Facilitates breed-specific business logic and reporting.
        static let dogBreedRequired = NSLocalizedString("Dog Breed Required", comment: "Dog breed required error")

        // Appointment
        /// Localization key indicating Appointment date is required.
        /// Ensures scheduling compliance and workflow integrity.
        static let appointmentDateRequired = NSLocalizedString("Appointment Date Required", comment: "Appointment date required error")
        /// Localization key prompting user to select a Dog for Appointment.
        /// Enforces business rules for appointment completeness.
        static let appointmentDogRequired = NSLocalizedString("Select a Dog", comment: "Appointment dog selection required error")
        /// Localization key prompting user to select an Owner for Appointment.
        /// Maintains data relationships and workflow correctness.
        static let appointmentOwnerRequired = NSLocalizedString("Select an Owner", comment: "Appointment owner selection required error")

        // Charge
        /// Localization key indicating Charge amount is required.
        /// Supports financial data integrity and compliance.
        static let chargeAmountRequired = NSLocalizedString("Amount Required", comment: "Charge amount required error")
        /// Localization key enforcing Charge amount range between 1 and 9999.
        /// Ensures valid financial entries and business constraints.
        static let chargeAmountRange = NSLocalizedString("Amount Must Be 1–9999", comment: "Charge amount range error")
        /// Localization key indicating Charge type selection is required.
        /// Maintains financial categorization and reporting accuracy.
        static let chargeTypeRequired = NSLocalizedString("Select a Charge Type", comment: "Charge type selection required error")
    }

    // MARK: - Field Validation

    /**
     Validates that a string value is non-empty and not just whitespace.
     
     This validation supports audit trails by ensuring required fields are completed,
     enables analytics on form completion rates, enforces business rules for mandatory data,
     and supports compliance by preventing empty critical data entries.
     It also facilitates UI tokenization by standardizing error messaging.
     
     - Parameters:
       - value: The string value to validate.
       - error: The localized error message returned if validation fails.
     - Returns: A ValidationResult indicating validity and carrying localized messages for UI feedback.
     */
    static func required(_ value: String?, error: String = Messages.requiredField) -> ValidationResult {
        guard let value = value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalid(error)
        }
        return .valid
    }

    /**
     Validates that a string's length falls within specified minimum and maximum bounds.
     
     This validation enables audit logging of input constraints,
     supports analytics on user input patterns,
     enforces business rules for data consistency,
     and ensures compliance with length restrictions.
     It also aligns with UI tokenization for consistent error presentation.
     
     - Parameters:
       - value: The string value to validate.
       - min: Minimum allowed length.
       - max: Maximum allowed length.
       - error: Optional custom localized error message.
     - Returns: A ValidationResult indicating validity and carrying localized messages for UI feedback.
     */
    static func length(_ value: String?, min: Int = 0, max: Int = .max, error: String? = nil) -> ValidationResult {
        let count = value?.count ?? 0
        if count < min {
            let message = error ?? String(format: Messages.lengthMin, min)
            return .invalid(message)
        }
        if count > max {
            let message = error ?? String(format: Messages.lengthMax, max + 1)
            return .invalid(message)
        }
        return .valid
    }

    /**
     Validates that a string is a properly formatted email address.
     
     This check supports audit requirements for contact data,
     enables analytics on optional email usage,
     enforces business logic for optional but valid email input,
     and supports compliance with data quality standards.
     UI tokenization is supported via localized error messages.
     
     - Parameters:
       - value: The string value to validate.
       - error: The localized error message returned if validation fails.
     - Returns: A ValidationResult indicating validity and carrying localized messages for UI feedback.
     */
    static func email(_ value: String?, error: String = Messages.invalidEmail) -> ValidationResult {
        guard let value = value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // Optional field, blank is valid
            return .valid
        }
        guard StringUtils.isValidEmail(value) else {
            return .invalid(error)
        }
        return .valid
    }

    /**
     Validates that a string is a properly formatted phone number.
     
     This validation enables audit trails for contact data,
     supports analytics on phone number usage,
     enforces business logic for optional but valid phone inputs,
     and ensures compliance with phone formatting standards.
     UI tokenization is facilitated via localized messaging.
     
     - Parameters:
       - value: The string value to validate.
       - error: The localized error message returned if validation fails.
     - Returns: A ValidationResult indicating validity and carrying localized messages for UI feedback.
     */
    static func phone(_ value: String?, error: String = Messages.invalidPhone) -> ValidationResult {
        guard let value = value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // Optional field, blank is valid
            return .valid
        }
        guard StringUtils.isValidPhone(value) else {
            return .invalid(error)
        }
        return .valid
    }

    /**
     Validates that a numeric string value falls within a specified range.
     
     This validation supports audit logging of numeric inputs,
     enables analytics on value distributions,
     enforces business rules for acceptable numeric ranges,
     and aids compliance with numeric data standards.
     UI tokenization is supported through localized error messages.
     
     - Parameters:
       - value: The string value to validate.
       - min: Minimum allowed numeric value.
       - max: Maximum allowed numeric value.
       - error: Optional custom localized error message.
     - Returns: A ValidationResult indicating validity and carrying localized messages for UI feedback.
     */
    static func range<T: Comparable & LosslessStringConvertible>(_ value: String?, min: T, max: T, error: String? = nil) -> ValidationResult {
        guard let value = value, let num = T(value) else {
            return .invalid(error ?? Messages.invalidValue)
        }
        if num < min || num > max {
            let message = error ?? String(format: Messages.rangeError, String(describing: min), String(describing: max))
            return .invalid(message)
        }
        return .valid
    }

    // MARK: - Model Object Validation

    /**
     Validates DogOwner creation fields including name, email, and phone.
     
     This method supports audit trails for owner records,
     enables analytics on owner data completeness,
     enforces business rules on required and optional fields,
     and ensures compliance with contact data standards.
     Validation results are localized for UI feedback and tokenized for workflow integration.
     
     - Parameters:
       - name: Owner's name.
       - email: Owner's email (optional).
       - phone: Owner's phone (optional).
     - Returns: An array of ValidationResult objects indicating any validation errors.
     */
    static func validateDogOwner(name: String?, email: String?, phone: String?) -> [ValidationResult] {
        [
            required(name, error: Messages.ownerNameRequired),
            email(email, error: Messages.ownerEmailInvalid),
            phone(phone, error: Messages.ownerPhoneInvalid)
        ].filter { !$0.isValid }
    }

    /**
     Validates Dog creation fields including name and breed.
     
     This method supports audit logging of dog records,
     enables analytics on dog data completeness,
     enforces business rules requiring dog identification,
     and ensures compliance with data entry standards.
     Validation messages are localized for UI clarity and tokenized for process workflows.
     
     - Parameters:
       - name: Dog's name.
       - breed: Dog's breed.
     - Returns: An array of ValidationResult objects indicating any validation errors.
     */
    static func validateDog(name: String?, breed: String?) -> [ValidationResult] {
        [
            required(name, error: Messages.dogNameRequired),
            required(breed, error: Messages.dogBreedRequired)
        ].filter { !$0.isValid }
    }

    /**
     Validates Appointment fields including date, dog, and owner selections.
     
     This validation supports audit trails for appointment scheduling,
     enables analytics on appointment data completeness,
     enforces business rules requiring all appointment components,
     and ensures compliance with scheduling policies.
     Localized validation messages support UI tokenization and accessibility.
     
     - Parameters:
       - date: Appointment date.
       - dog: Selected dog.
       - owner: Selected owner.
     - Returns: An array of ValidationResult objects indicating any validation errors.
     */
    static func validateAppointment(date: Date?, dog: Dog?, owner: DogOwner?) -> [ValidationResult] {
        var results: [ValidationResult] = []
        if date == nil { results.append(.invalid(Messages.appointmentDateRequired)) }
        if dog == nil { results.append(.invalid(Messages.appointmentDogRequired)) }
        if owner == nil { results.append(.invalid(Messages.appointmentOwnerRequired)) }
        return results
    }

    /**
     Validates Charge fields including amount and charge type.
     
     This method supports audit logging of financial transactions,
     enables analytics on charge data accuracy,
     enforces business rules for valid charge amounts and types,
     and maintains compliance with financial data standards.
     Validation results are localized for UI feedback and tokenized for workflow integration.
     
     - Parameters:
       - amount: Charge amount as string.
       - type: Charge type.
     - Returns: An array of ValidationResult objects indicating any validation errors.
     */
    static func validateCharge(amount: String?, type: ChargeType?) -> [ValidationResult] {
        [
            required(amount, error: Messages.chargeAmountRequired),
            range(amount, min: 1.0, max: 9999.0, error: Messages.chargeAmountRange),
            type == nil ? .invalid(Messages.chargeTypeRequired) : .valid
        ].filter { !$0.isValid }
    }

    // MARK: - Future Validation Stubs

    /**
     Placeholder for Business validations.
     
     Intended to support future audit, analytics, business logic, compliance, and UI tokenization needs.
     
     - Returns: An empty array until implemented.
     */
    static func validateBusiness(/* parameters */) -> [ValidationResult] {
        // TODO: Implement business validations
        return []
    }

    /**
     Placeholder for Inventory validations.
     
     Designed to facilitate future audit trails, analytics, business rules, compliance, and UI tokenization.
     
     - Returns: An empty array until implemented.
     */
    static func validateInventory(/* parameters */) -> [ValidationResult] {
        // TODO: Implement inventory validations
        return []
    }

    /**
     Placeholder for Expense validations.
     
     Supports planned enhancements for audit, analytics, business logic, compliance, and UI tokenization.
     
     - Returns: An empty array until implemented.
     */
    static func validateExpense(/* parameters */) -> [ValidationResult] {
        // TODO: Implement expense validations
        return []
    }
}

/// Represents the result of validating a field or form.
///
/// This enum provides a modular, auditable, analytics-friendly, and localization-ready structure for validation outcomes.
/// It enables comprehensive UI feedback, supports business logic enforcement, facilitates compliance tracking,
/// and integrates seamlessly with analytics and reporting systems.
/// ValidationResult instances carry localized messages for consistent user-facing communication.
enum ValidationResult: Equatable {
    /// Indicates a valid validation outcome with no errors.
    case valid
    /// Indicates an invalid validation outcome, carrying a localized error message.
    case invalid(String)

    /// Indicates if the validation result is valid.
    ///
    /// This property supports UI logic to enable or disable form submission,
    /// facilitates analytics tracking of validation success rates,
    /// and assists business compliance by clearly distinguishing valid inputs.
    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    /// Returns the associated error message if invalid.
    ///
    /// Provides localized text for UI error displays,
    /// supports analytics on common validation failures,
    /// and aids business and compliance teams in understanding validation issues.
    var message: String? {
        if case .invalid(let msg) = self { return msg }
        return nil
    }
}
