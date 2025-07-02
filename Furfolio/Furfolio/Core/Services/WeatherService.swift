//
//  WeatherService.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//

import Foundation
import Combine

/**
 WeatherService
 --------------
 A centralized service for fetching weather data in Furfolio, with async analytics and audit logging.

 - **Purpose**: Retrieves current and forecast weather information.
 - **Architecture**: Singleton service using URLSession.
 - **Concurrency & Async Logging**: Wraps network calls in non-blocking `Task` blocks for analytics and audit.
 - **Audit/Analytics Ready**: Defines protocols for async event tracking and integrates a dedicated audit manager actor.
 - **Localization**: Error messages use `NSLocalizedString`.
 - **Diagnostics & Preview/Testability**: Exposes methods to fetch and export recent audit entries.
 */

// MARK: - Analytics & Audit Protocols

public protocol WeatherAnalyticsLogger {
    /// Log a weather API event asynchronously.
    func log(event: String, parameters: [String: Any]?) async
}

public protocol WeatherAuditLogger {
    /// Record a weather API audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
}

public struct NullWeatherAnalyticsLogger: WeatherAnalyticsLogger {
    public init() {}
    public func log(event: String, parameters: [String : Any]?) async {}
}

public struct NullWeatherAuditLogger: WeatherAuditLogger {
    public init() {}
    public func record(_ message: String, metadata: [String : String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a weather API audit event.
public struct WeatherAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let detail: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String, detail: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.detail = detail
    }
}

/// Concurrency-safe actor for logging weather API events.
public actor WeatherAuditManager {
    private var buffer: [WeatherAuditEntry] = []
    private let maxEntries = 100
    public static let shared = WeatherAuditManager()

    public func add(_ entry: WeatherAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 20) -> [WeatherAuditEntry] {
        Array(buffer.suffix(limit))
    }

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

// MARK: - Models

/// Simplified weather data model
public struct WeatherData: Codable {
    public let temperature: Double
    public let description: String
    public let city: String
}

// MARK: - Service

@MainActor
public final class WeatherService {
    public static let shared = WeatherService(
        analytics: NullWeatherAnalyticsLogger(),
        audit: NullWeatherAuditLogger()
    )

    private let session: URLSession
    private let apiKey: String
    private let analytics: WeatherAnalyticsLogger
    private let audit: WeatherAuditLogger

    private init(
        session: URLSession = .shared,
        apiKey: String = "YOUR_API_KEY",
        analytics: WeatherAnalyticsLogger,
        audit: WeatherAuditLogger
    ) {
        self.session = session
        self.apiKey = apiKey
        self.analytics = analytics
        self.audit = audit
    }

    /// Fetches current weather for a given city.
    public func fetchCurrentWeather(for city: String) async throws -> WeatherData {
        let endpoint = URL(string:
            "https://api.openweathermap.org/data/2.5/weather?q=\(city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city)&units=metric&appid=\(apiKey)"
        )!

        Task {
            await analytics.log(event: "weather_fetch_start", parameters: ["city": city])
            await audit.record("Fetch weather started", metadata: ["city": city])
            await WeatherAuditManager.shared.add(
                WeatherAuditEntry(event: "fetch_start", detail: city)
            )
        }

        let (data, response) = try await session.data(from: endpoint)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1

        Task {
            await analytics.log(event: "weather_fetch_response", parameters: ["status": status])
            await audit.record("Fetch weather response", metadata: ["status": "\(status)"])
            await WeatherAuditManager.shared.add(
                WeatherAuditEntry(event: "fetch_response", detail: "\(status)")
            )
        }

        guard status == 200 else {
            let msg = NSLocalizedString("Failed to fetch weather.", comment: "Weather error")
            throw NSError(domain: "WeatherService", code: status, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let decoder = JSONDecoder()
        let raw = try decoder.decode(OpenWeatherResponse.self, from: data)
        let weather = WeatherData(
            temperature: raw.main.temp,
            description: raw.weather.first?.description ?? "",
            city: raw.name
        )

        Task {
            await analytics.log(event: "weather_fetch_complete", parameters: ["city": weather.city])
            await audit.record("Fetch weather complete", metadata: ["city": weather.city])
            await WeatherAuditManager.shared.add(
                WeatherAuditEntry(event: "fetch_complete", detail: weather.city)
            )
        }

        return weather
    }
}

/// Helper structs matching OpenWeather API
private struct OpenWeatherResponse: Codable {
    let name: String
    let weather: [WeatherDescription]
    let main: WeatherMain
}

private struct WeatherDescription: Codable {
    let description: String
}

private struct WeatherMain: Codable {
    let temp: Double
}

// MARK: - Diagnostics

public extension WeatherService {
    /// Fetch recent weather audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [WeatherAuditEntry] {
        await WeatherAuditManager.shared.recent(limit: limit)
    }

    /// Export weather audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await WeatherAuditManager.shared.exportJSON()
    }
}
