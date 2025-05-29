//  LocalizationKeys.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Added centralized keys for all user-facing strings.
//

import Foundation
import os
private let locLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "LocalizationKeys")

// TODO: Centralize localization lookups and support pluralization/localized formatting via a LocalizationService.
/// Centralized keys for all user-facing strings in the Furfolio app.
enum LocalizationKeys {
  /// Common action strings used throughout the app.
  // MARK: — Common
  /// Title for cancel actions.
  static let cancel               = "common.cancel"
  /// Title for save actions.
  static let save                 = "common.save"
  /// Title for done actions.
  static let done                 = "common.done"
  /// Title for OK actions.
  static let ok                   = "common.ok"
  /// Message displayed when there is no data available.
  static let noData               = "common.no_data"
  
  /// Strings used in the Add Appointment and Appointment views.
  // MARK: — Appointment/AddAppointmentView
  static let addAppointmentTitle  = "appointment.add.title"
  static let appointmentDetails   = "appointment.details.header"
  static let dateTimePicker       = "appointment.details.date_time"
  static let serviceTypePicker    = "appointment.details.service_type"
  static let durationStepper      = "appointment.details.duration"
  static let notesPlaceholder     = "appointment.details.notes_placeholder"
  static let linkChargeToggle     = "appointment.details.link_charge"
  static let enableReminderToggle = "appointment.details.enable_reminder"
  static let loyaltyProgressLabel = "appointment.details.loyalty_progress"
  static let behaviorBadgeLabel   = "appointment.details.behavior_badge"
  static let photosSectionHeader  = "appointment.photos.header"
  static let beforePhotoLabel     = "appointment.photos.before"
  static let afterPhotoLabel      = "appointment.photos.after"
  static let conflictWarning      = "appointment.conflict.warning"
  static let conflictAlertTitle   = "appointment.conflict.alert_title"

  /// Strings for the Appointment Reminder view.
  // MARK: — AppointmentReminderView
  static let remindersTitle       = "reminder.view.title"
  static let defaultOffsetLabel   = "reminder.settings.default_offset"
  static let noUpcomingAppts      = "reminder.no_upcoming"
  static let setReminderButton    = "reminder.button.set"
  static let cancelReminderButton = "reminder.button.cancel"
  static let resendReminderButton = "reminder.button.resend"
  static let notificationSuccess  = "reminder.alert.success"
  static let notificationCanceled = "reminder.alert.canceled"

  /// Strings for the Inventory Dashboard view.
  // MARK: — InventoryDashboardView
  static let inventoryTitle       = "inventory.dashboard.title"
  static let summarySectionHeader = "inventory.dashboard.summary"
  static let totalItemsLabel      = "inventory.summary.total_items"
  static let totalValueLabel      = "inventory.summary.total_value"
  static let lowStockHeader       = "inventory.low_stock.header"
  static let topValueHeader       = "inventory.top_value.header"
  static let allItemsHeader       = "inventory.all.header"
  static let refreshButton        = "inventory.toolbar.refresh"

  /// Strings for the Loyalty Progress view.
  // MARK: — LoyaltyProgressView
  static let loyaltyStatusTitle   = "loyalty.view.title"
  static let visitsProgressLabel  = "loyalty.progress.visits"
  static let freeBathTag          = "loyalty.tag.free_bath"
  static let progressCompleteTag  = "loyalty.tag.complete"

  /// Strings for the Missed Appointments view.
  // MARK: — MissedAppointmentsView
  static let missedTitle          = "missed.view.title"
  static let noMissed             = "missed.view.none"
  static let rescheduleButton     = "missed.row.reschedule"

  /// Strings for the Popular Services view.
  // MARK: — PopularServicesView
  static let popularServicesTitle = "popular.view.title"
  static let bookingsSuffix       = "popular.view.bookings_suffix"

  /// Strings for the Expense views.
  // MARK: — Expense
  static let addExpenseTitle      = "expense.add.title"
  static let expenseSummaryTitle  = "expense.summary.title"
  static let expenseTotalLabel    = "expense.summary.total"
  static let expenseDatePicker    = "expense.add.date_picker"
  static let expenseCategoryPicker = "expense.add.category_picker"
  static let expenseAmountField   = "expense.add.amount_field"
  static let expenseNotesField    = "expense.add.notes_field"

  /// Strings for the Settings views.
  // MARK: — Settings
  static let settingsTitle        = "settings.view.title"
  static let darkModeLockToggle   = "settings.dark_mode_lock"
  static let notificationsToggle  = "settings.notifications_toggle"
  static let locationAccessToggle = "settings.location_access_toggle"
  static let privacyPolicyLink    = "settings.privacy_policy_link"
  static let termsOfServiceLink   = "settings.terms_of_service_link"

  /// Strings for the Audit Log views.
  // MARK: — AuditLog
  static let auditLogTitle        = "audit_log.view.title"
  static let auditLogDateFilter   = "audit_log.filter.date"
  static let auditLogUserFilter   = "audit_log.filter.user"
  static let auditLogActionFilter = "audit_log.filter.action"
  static let auditLogEntryDetails = "audit_log.entry.details"
  static let auditLogNoEntries    = "audit_log.no_entries"

  /// Strings for the Appointment Templates.
  // MARK: — AppointmentTemplate
  static let templateFullGroomTitle   = "appointment.template.full_groom.title"
  static let templateBasicGroomTitle  = "appointment.template.basic_groom.title"
  static let templateSpaBathTitle     = "appointment.template.spa_bath.title"
  static let templateServiceDuration  = "appointment.template.duration"
  static let templateServicePriceRange = "appointment.template.price_range"

  /// Strings for Add-On Services.
  // MARK: — AddOnService
  static let addOnServicesHeader      = "addon.services.header"
  static let addOnServiceNameFormat   = "addon.service.name.%@"      // use String(format:) with service identifier
  static let addOnServicePriceRange   = "addon.service.price_range.%@" // use String(format:) with service identifier
}

/// Convenience extensions for localized string lookups.
extension String {
  /// Returns the localized string for the given key, optionally formatted with arguments.
  /// - Parameters:
  ///   - key: The localization key to look up.
  ///   - args: Arguments for string formatting.
  /// - Returns: Localized string from .strings files, formatted if arguments are provided.
  static func loc(_ key: String, _ args: CVarArg...) -> String {
    locLogger.log("Localization lookup for key: \(key)")
    let format = NSLocalizedString(key, comment: "")
    let result = args.isEmpty ? format : String(format: format, locale: .current, arguments: args)
    locLogger.log("Localized result for key: \(key) -> \(result)")
    return result
  }

  /// Returns a localized string for a key with plural rule based on count.
  /// - Parameters:
  ///   - singularKey: The key for the singular form.
  ///   - pluralKey: The key for the plural form.
  ///   - count: The count to determine pluralization.
  /// - Returns: Localized pluralized string.
  static func loc(_ singularKey: String, _ pluralKey: String, count: Int) -> String {
    let formatKey = count == 1 ? singularKey : pluralKey
    let format = NSLocalizedString(formatKey, comment: "")
    let result = String(format: format, locale: .current, count)
    locLogger.log("Plural localization for keys: \(singularKey)/\(pluralKey), count: \(count) -> \(result)")
    return result
  }
}
