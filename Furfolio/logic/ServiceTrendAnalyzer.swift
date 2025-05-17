//  ServiceTrendAnalyzer.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on 2025-07-03 — added frequency, trend scoring, and simple forecast.
//

import Foundation

// TODO: Allow injection of custom window sizes and smoothing factors; cache shared Calendar for performance.

@MainActor
/// Analyzes appointment data to surface service usage trends, including frequency, trend scoring, and forecasting.
struct ServiceTrendAnalyzer {
  /// Shared calendar for date calculations.
  private static let calendar = Calendar.current

  /// Computes usage frequency of each service type in the provided appointments.
  /// - Parameter appointments: Array of Appointment objects to analyze.
  /// - Returns: Dictionary mapping each Appointment.ServiceType to its count.
  static func frequency(
    in appointments: [Appointment]
  ) -> [Appointment.ServiceType: Int] {
    Dictionary(grouping: appointments, by: \.serviceType)
      .mapValues { $0.count }
  }

  /// Returns the top-N most frequently used services.
  /// - Parameters:
  ///   - appointments: Array of Appointment objects.
  ///   - n: Maximum number of results.
  /// - Returns: Array of (service, count) tuples sorted descending, where service is Appointment.ServiceType.
  static func topServices(
    in appointments: [Appointment],
    top n: Int
  ) -> [(service: Appointment.ServiceType, count: Int)] {
    frequency(in: appointments)
      .sorted { $0.value > $1.value }
      .prefix(n)
      .map { ($0.key, $0.value) }
  }

  /// Computes trend scores by comparing usage in the recent window to the previous window.
  /// - Parameters:
  ///   - appointments: Array of Appointment objects.
  ///   - days: Number of days for each window (default 30).
  /// - Returns: Dictionary mapping Appointment.ServiceType to percent change score.
  static func trendScores(
    in appointments: [Appointment],
    recentWindow days: Int = 30
  ) -> [Appointment.ServiceType: Double] {
    let now = Date.now
    let cal = Self.calendar

    // Split appointments into “recent” and “previous” windows
    let recentStart = cal.date(byAdding: .day, value: -days, to: now)!
    let previousStart = cal.date(byAdding: .day, value: -2*days, to: now)!
    
    let recent   = appointments.filter { $0.date >= recentStart }
    let previous = appointments.filter { $0.date >= previousStart && $0.date < recentStart }
    
    let recentFreq   = frequency(in: recent)
    let previousFreq = frequency(in: previous)

    // For each service, compute percent change: (recent - previous) / previous
    var scores: [Appointment.ServiceType: Double] = [:]
    for service in Appointment.ServiceType.allCases {
      let r = Double(recentFreq[service] ?? 0)
      let p = Double(previousFreq[service] ?? 0)
      let change: Double
      if p == 0 {
        change = r > 0 ? 1.0 : 0.0
      } else {
        change = (r - p) / p
      }
      scores[service] = change
    }
    return scores
  }

  /// Returns the top-N services by trend score (highest growth).
  /// - Parameters:
  ///   - appointments: Array of Appointment objects.
  ///   - n: Maximum number of results.
  ///   - days: Window size for trend scoring (default 30).
  /// - Returns: Array of (service, score) tuples sorted descending, where service is Appointment.ServiceType.
  static func topTrendingServices(
    in appointments: [Appointment],
    top n: Int,
    recentWindow days: Int = 30
  ) -> [(service: Appointment.ServiceType, score: Double)] {
    trendScores(in: appointments, recentWindow: days)
      .sorted { $0.value > $1.value }
      .prefix(n)
      .map { ($0.key, $0.value) }
  }

  /// Forecasts future usage using exponential smoothing over daily counts.
  /// - Parameters:
  ///   - service: The Appointment.ServiceType to forecast.
  ///   - appointments: Array of Appointment objects.
  ///   - days: Number of past days to include (default 30).
  ///   - alpha: Smoothing factor between 0…1 (default 0.3).
  /// - Returns: Forecasted count for the next period.
  static func forecast(
    for service: Appointment.ServiceType,
    in appointments: [Appointment],
    overPast days: Int = 30,
    alpha: Double = 0.3
  ) -> Double {
    let now = Date.now
    let cal = Self.calendar
    let start = cal.date(byAdding: .day, value: -days, to: now)!

    // Build a time‐series of daily counts
    var dailyCounts: [Int] = []
    for offset in 0..<days {
      let dayStart = cal.date(byAdding: .day, value: -offset, to: now)!
      let nextDay  = cal.date(byAdding: .day, value: -(offset-1), to: now)!
      let count = appointments.filter {
          $0.serviceType.rawValue == service.rawValue &&
        $0.date >= dayStart &&
        $0.date < nextDay
      }.count
      dailyCounts.insert(count, at: 0) // earliest first
    }

    // Exponential smoothing
    var forecast = Double(dailyCounts.first ?? 0)
    for count in dailyCounts.dropFirst() {
      forecast = alpha * Double(count) + (1 - alpha) * forecast
    }
    return forecast
  }
}
