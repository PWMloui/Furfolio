//
//  DailyRevenue.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on May 16, 2025 — added hourlyAppointmentFrequency helper and polished SwiftData model.
//

import Foundation
import SwiftData
import SwiftUI

// TODO: Move transformer registration to PersistenceController and consider caching aggregated summaries separately.
// TODO: Consider persisting aggregated summaries separately to optimize large data reads

@MainActor
@Model
final class DailyRevenue: Identifiable, Hashable {
  
  /// Shared calendar for date calculations and comparisons.
  private static let calendar = Calendar.current
  
  // MARK: – Persisted Properties
  
  @Attribute
  var id: UUID = UUID()
  
  @Attribute
  var date: Date = Date.now
  
  @Attribute
  var totalAmount: Double = 0.0
  
  @Relationship(deleteRule: .cascade)
  var dogOwner: DogOwner
  
  
  // MARK: – Initialization & Creation Errors
  
  enum RevenueError: Error, LocalizedError {
    case negativeAmount, futureDate
    var errorDescription: String? {
      switch self {
      case .negativeAmount:
        return NSLocalizedString("Total amount cannot be negative.", comment: "")
      case .futureDate:
        return NSLocalizedString("Date cannot be in the future.", comment: "")
      }
    }
  }
  
  /// Initializes a DailyRevenue, enforcing non-negative amounts and non-future dates.
  init(
    date: Date = Date.now,
    totalAmount: Double = 0.0,
    owner: DogOwner
  ) {
    self.date = date <= Date.now ? date : Date.now
    self.totalAmount = max(0, totalAmount)
    self.dogOwner = owner
  }
  
  /// Designated initializer for DailyRevenue model.
  init(
    id: UUID = UUID(),
    date: Date = Date.now,
    totalAmount: Double = 0.0,
    dogOwner: DogOwner
  ) {
    self.id = id
    self.date = date <= Date.now ? date : Date.now
    self.totalAmount = max(0, totalAmount)
    self.dogOwner = dogOwner
  }
  
  /// Creates and inserts a new DailyRevenue, validating inputs via `RevenueError`.
  @discardableResult
  static func create(
    date: Date = Date.now,
    totalAmount: Double,
    owner: DogOwner,
    in context: ModelContext
  ) throws -> DailyRevenue {
    guard totalAmount >= 0 else { throw RevenueError.negativeAmount }
    guard date <= Date.now        else { throw RevenueError.futureDate }
    let revenue = DailyRevenue(date: date, totalAmount: totalAmount, owner: owner)
    context.insert(revenue)
    return revenue
  }
  
  
  // MARK: – Cached Formatters
  
  private static let currencyFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .currency
    return f
  }()
  
  private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return f
  }()
  
  
  // MARK: – Computed Properties
  
  /// Returns the totalAmount formatted as a currency string using the current locale.
  @Transient
  var formattedTotal: String {
    Self.currencyFormatter.locale = .current
    return Self.currencyFormatter.string(from: NSNumber(value: totalAmount))
      ?? "\(Self.currencyFormatter.currencySymbol ?? "$")\(totalAmount)"
  }
  
  /// Returns the date formatted as a medium style date string.
  @Transient
  var formattedDate: String {
    Self.dateFormatter.string(from: date)
  }
  
  /// Indicates whether the date is today.
  @Transient
  var isToday: Bool {
    Self.calendar.isDateInToday(date)
  }
  
  /// Indicates whether the date is in the current month.
  @Transient
  var isCurrentMonth: Bool {
    Self.calendar.isDate(date, equalTo: Date.now, toGranularity: .month)
  }
  
  /// Returns a reward tag string based on totalAmount thresholds.
  @Transient
  var dailyRewardTag: String? {
    let thresholds = SettingsManager.shared.rewardThresholds
    switch totalAmount {
    case 0..<thresholds[0]: return nil
    case thresholds[0]..<thresholds[1]: return "🏅 Goal Met"
    case thresholds[1]..<thresholds[2]: return "🎯 Great Day"
    case thresholds[2]...: return "🚀 Record Breaker"
    default: return nil
    }
  }
  
  /// Returns the number of earned loyalty points based on totalAmount.
  @Transient
  var earnedLoyaltyPoints: Int {
    let thresholds = SettingsManager.shared.rewardThresholds
    let points = SettingsManager.shared.loyaltyPointsPerTier
    switch totalAmount {
    case 0..<thresholds[0]:
        return 0
    case thresholds[0]..<thresholds[1]:
        return points[0]
    case thresholds[1]..<thresholds[2]:
        return points[1]
    case thresholds[2]...:
        return points[2]
    default:
        return 0
    }
  }
  
  /// Returns a loyalty badge string based on totalAmount.
  @Transient
  var loyaltyBadge: String {
    switch totalAmount {
    case 0..<100:       return "🔸 Starter"
    case 100..<250:     return "🔹 Loyal"
    case 250..<500:     return "⭐️ Super Loyal"
    case 500...:        return "🏆 VIP"
    default:            return "🔸 Starter"
    }
  }
  
  /// Combined summary of this day's revenue and badge.
  @Transient
  var summary: String {
    let dateStr = formattedDate
    let amountStr = formattedTotal
    let badgeStr = dailyRewardTag ?? ""
    return badgeStr.isEmpty ? "\(dateStr): \(amountStr)" : "\(dateStr): \(amountStr) \(badgeStr)"
  }
  
  func snapshotCategory(averageLast7Days: Double) -> String {
    guard averageLast7Days >= 0 else { return "➖ On Par" }
    if totalAmount > averageLast7Days {
      return "📈 Above Average"
    } else if totalAmount < averageLast7Days {
      return "📉 Below Average"
    } else {
      return "➖ On Par"
    }
  }
  
  
  // MARK: – Mutating Methods
  
  func addRevenue(_ amount: Double) {
    guard amount >= 0 else { return }
    totalAmount += amount
  }
  
  func resetIfNotToday() {
    if !isToday {
      totalAmount = 0.0
    }
  }
  
  
  // MARK: – Range Calculations
  
  /// Calculates total revenue within the specified date range.
  static func totalRevenue(
    for range: ClosedRange<Date>,
    in entries: [DailyRevenue]
  ) -> Double {
    entries
      .filter { range.contains($0.date) }
      .reduce(0) { $0 + $1.totalAmount }
  }
  
  /// Computes average daily revenue over the given date range.
  static func averageDailyRevenue(
    for range: ClosedRange<Date>,
    in entries: [DailyRevenue]
  ) -> Double {
    guard let days = Self.calendar
            .dateComponents([.day], from: range.lowerBound, to: range.upperBound).day,
          days >= 0
    else { return 0 }
    let total = totalRevenue(for: range, in: entries)
    return total / Double(days + 1)
  }
  
  
  // MARK: – Summaries
  
  static func weeklyRevenueSummary(
    from entries: [DailyRevenue]
  ) -> [(week: String, total: Double)] {
    let calendar = Self.calendar
    let grouped = Dictionary(grouping: entries) {
      calendar.component(.weekOfYear, from: $0.date)
    }
    return grouped
      .map { week, revenues in
        (week: NSLocalizedString("Week \(week)", comment: ""), total: revenues.reduce(0) { $0 + $1.totalAmount })
      }
      .sorted {
        let a = Int($0.week.components(separatedBy: " ").last!)!
        let b = Int($1.week.components(separatedBy: " ").last!)!
        return a < b
      }
  }
  
  static func dailyRevenueSummary(
    for month: Int,
    year: Int,
    in entries: [DailyRevenue]
  ) -> [(day: Int, total: Double)] {
    let calendar = Self.calendar
    guard let start = calendar.date(from: DateComponents(year: year, month: month)) else { return [] }
    guard let end = calendar.date(byAdding: .month, value: 1, to: start)?
            .addingTimeInterval(-1) else { return [] }
    let monthly = entries.filter { $0.date >= start && $0.date <= end }
    let byDay = Dictionary(grouping: monthly) {
      calendar.component(.day, from: $0.date)
    }
    return byDay
      .map { day, revenues in (day: day, total: revenues.reduce(0) { $0 + $1.totalAmount }) }
      .sorted { $0.day < $1.day }
  }
  
  /// Breaks down number of appointments per hour for a given day.
  /// - Parameters:
  ///   - day: the date to slice (time component ignored)
  ///   - appointments: list of all appointments
  /// - Returns: array of (hour: 0–23, count: Int), sorted by hour
  static func hourlyAppointmentFrequency(
    for day: Date,
    in appointments: [Appointment]
  ) -> [(hour: Int, count: Int)] {
    let calendar = Self.calendar
    let startOfDay = calendar.startOfDay(for: day)
    let startOfNext = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
    let dailyAppts = appointments.filter {
      $0.date >= startOfDay && $0.date < startOfNext
    }
    let grouped = Dictionary(grouping: dailyAppts) {
      calendar.component(.hour, from: $0.date)
    }
    return grouped
      .map { (hour: $0.key, count: $0.value.count) }
      .sorted { $0.hour < $1.hour }
  }
  
  // MARK: – Total per owner
  
  static func totalRevenue(
    for owner: DogOwner,
    in entries: [DailyRevenue]
  ) -> Double {
    entries
      .filter { $0.dogOwner.id == owner.id }
      .reduce(0) { $0 + $1.totalAmount }
  }
  
  
  // MARK: – Fetch Helpers
  
  /// Fetches all DailyRevenue entries in reverse date order.
  static func fetchAll(in context: ModelContext) -> [DailyRevenue] {
    let desc = FetchDescriptor<DailyRevenue>(
      sortBy: [SortDescriptor(\DailyRevenue.date, order: .reverse)]
    )
    do {
      return try context.fetch(desc)
    } catch {
      print("⚠️ DailyRevenue.fetchAll failed:", error)
      return []
    }
  }
  
  /// Fetches the DailyRevenue for a specific owner on the given day, if any.
  static func fetch(
    for owner: DogOwner,
    on day: Date,
    in context: ModelContext
  ) -> DailyRevenue? {
    let start = Self.calendar.startOfDay(for: day)
    let end = Self.calendar.date(byAdding: .day, value: 1, to: start)!
    let desc = FetchDescriptor<DailyRevenue>(
      predicate: #Predicate { $0.dogOwner.id == owner.id && $0.date >= start && $0.date < end },
      sortBy: [SortDescriptor(\DailyRevenue.date, order: .reverse)]
    )
    return (try? context.fetch(desc))?.first
  }
  
  /// Fetches today's DailyRevenue for the specified owner, if it exists.
  static func fetchToday(
    for owner: DogOwner,
    in context: ModelContext
  ) -> DailyRevenue? {
    fetch(for: owner, on: Date.now, in: context)
  }
  
  
  // MARK: – Hashable
  
  static func == (lhs: DailyRevenue, rhs: DailyRevenue) -> Bool {
    lhs.id == rhs.id
  }
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

#if DEBUG
extension DailyRevenue {
  static var sample: DailyRevenue {
    let owner = DogOwner(
      ownerName: "Jane Doe",
      dogName: "Rex",
      breed: "Labrador",
      contactInfo: "jane@example.com",
      address: "123 Bark St."
    )
    return DailyRevenue(date: Date.now, totalAmount: 275, owner: owner)
  }
}
#endif
