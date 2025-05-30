//  ServiceTrendAnalyzer.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on 2025-07-03 — added frequency, trend scoring, and simple forecast.
//


import Foundation
import os
import FirebaseRemoteConfigService
private let trendLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ServiceTrendAnalyzer")
import _Concurrency


/// Analyzes appointment data to surface service usage trends, including frequency, trend scoring, and forecasting.
struct ServiceTrendAnalyzer {
    private static let logger = trendLogger

    /// Default “top-N” limit pulled from Remote Config.
    private static var defaultTopLimit: Int {
        FirebaseRemoteConfigService.shared.configValue(forKey: .analyticsTopServicesLimit)
    }

    /// Default window size (days) for trend scoring, from Remote Config.
    private static var defaultTrendWindowDays: Int {
        FirebaseRemoteConfigService.shared.configValue(forKey: .trendWindowDays)
    }
  /// Shared calendar for date calculations.
  private static let calendar = Calendar.current

  /// Computes usage frequency of each service type in the provided appointments.
  /// - Parameter appointments: Array of Appointment objects to analyze.
  /// - Returns: Dictionary mapping each Appointment.ServiceType to its count.
  static func frequency(
    in appointments: [Appointment]
  ) -> [Appointment.ServiceType: Int] {
      logger.log("frequency: starting with \(appointments.count) appointments")
      let result = Dictionary(grouping: appointments, by: \.serviceType).mapValues { $0.count }
      logger.log("frequency: result \(result)")
      return result
  }

  /// Returns the top-N most frequently used services.
  /// - Parameters:
  ///   - appointments: Array of Appointment objects.
  ///   - n: Maximum number of results.
  /// - Returns: Array of (service, count) tuples sorted descending, where service is Appointment.ServiceType.
  static func topServices(
    in appointments: [Appointment],
    top n: Int = ServiceTrendAnalyzer.defaultTopLimit
  ) -> [(service: Appointment.ServiceType, count: Int)] {
      logger.log("topServices: computing top \(n) from \(appointments.count) appointments")
      let freqs = frequency(in: appointments)
      let sorted = freqs.sorted { $0.value > $1.value }.prefix(n).map { ($0.key, $0.value) }
      logger.log("topServices: result \(sorted)")
      return sorted
  }

  /// Computes trend scores by comparing usage in the recent window to the previous window.
  /// - Parameters:
  ///   - appointments: Array of Appointment objects.
  ///   - days: Number of days for each window (default 30).
  /// - Returns: Dictionary mapping Appointment.ServiceType to percent change score.
  static func trendScores(
    in appointments: [Appointment],
    recentWindow days: Int = ServiceTrendAnalyzer.defaultTrendWindowDays
  ) -> [Appointment.ServiceType: Double] {
      logger.log("trendScores: computing with \(appointments.count) appointments over \(days)-day windows")
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
      logger.log("trendScores: result \(scores)")
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
    top n: Int = ServiceTrendAnalyzer.defaultTopLimit,
    recentWindow days: Int = ServiceTrendAnalyzer.defaultTrendWindowDays
  ) -> [(service: Appointment.ServiceType, score: Double)] {
      logger.log("topTrendingServices: computing top \(n) trending over \(days)-day window")
      let scores = trendScores(in: appointments, recentWindow: days)
      let sorted = scores.sorted { $0.value > $1.value }.prefix(n).map { ($0.key, $0.value) }
      logger.log("topTrendingServices: result \(sorted)")
      return sorted
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
    let windowDays = FirebaseRemoteConfigService.shared.configValue(forKey: .forecastWindowDays)
    let smoothingAlpha = FirebaseRemoteConfigService.shared.configValue(forKey: .forecastSmoothingAlpha)
      logger.log("forecast: starting for service \(service) over past \(windowDays) days with alpha \(smoothingAlpha)")
    let now = Date.now
    let cal = Self.calendar
    let start = cal.date(byAdding: .day, value: -windowDays, to: now)!

    // Build a time‐series of daily counts
    var dailyCounts: [Int] = []
    for offset in 0..<windowDays {
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
      forecast = smoothingAlpha * Double(count) + (1 - smoothingAlpha) * forecast
    }
      logger.log("forecast: result \(forecast)")
    return forecast
  }

  /// Async variant of frequency(...).
  static func frequency(
    in appointments: [Appointment]
  ) async -> [Appointment.ServiceType: Int] {
      logger.log("frequency async: invoked")
    await _Concurrency.Task.detached { frequency(in: appointments) }.value
  }

  /// Async variant of topServices(...).
  static func topServices(
    in appointments: [Appointment],
    top n: Int
  ) async -> [(service: Appointment.ServiceType, count: Int)] {
      logger.log("topServices async: invoked")
    await _Concurrency.Task.detached { topServices(in: appointments, top: n) }.value
  }

  /// Async variant of trendScores(...).
  static func trendScores(
    in appointments: [Appointment],
    recentWindow days: Int = 30
  ) async -> [Appointment.ServiceType: Double] {
      logger.log("trendScores async: invoked")
    await _Concurrency.Task.detached { trendScores(in: appointments, recentWindow: days) }.value
  }

  /// Async variant of topTrendingServices(...).
  static func topTrendingServices(
    in appointments: [Appointment],
    top n: Int,
    recentWindow days: Int = 30
  ) async -> [(service: Appointment.ServiceType, score: Double)] {
      logger.log("topTrendingServices async: invoked")
    await _Concurrency.Task.detached { topTrendingServices(in: appointments, top: n, recentWindow: days) }.value
  }

  /// Async variant of forecast(...).
  static func forecast(
    for service: Appointment.ServiceType,
    in appointments: [Appointment],
    overPast days: Int = 30,
    alpha: Double = 0.3
  ) async -> Double {
      logger.log("forecast async: invoked")
    await _Concurrency.Task.detached { forecast(for: service, in: appointments, overPast: days, alpha: alpha) }.value
  }
}
