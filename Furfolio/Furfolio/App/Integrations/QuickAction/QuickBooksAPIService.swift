//
//  QuickBooksAPIService.swift
//  Furfolio
//
//  Purpose:
//      QuickBooksAPIService provides a robust, testable, and protocol-oriented interface for integrating QuickBooks Online with Furfolio.
//      This service encapsulates authentication, data fetching, and transactional operations with QuickBooks, enabling seamless business analytics and accounting integration.
//
//  Enhanced 2025: Secure token management, audit logging, diagnostics, robust error handling, dependency injection, ready for analytics/audit/role-based tracking.
//

import Foundation

// MARK: - Protocols

/// For secure token storage (e.g. Keychain, EncryptedStore)
protocol QuickBooksTokenStore {
    func save(token: String) throws
    func load() throws -> String?
    func clear() throws
}

/// For audit logging (compliance, business audit, error logging)
protocol QuickBooksAuditLogger {
    func log(event: QuickBooksAuditEvent)
}

enum QuickBooksAuditEvent {
    case authenticationAttempt(success: Bool, error: String?)
    case apiRequest(endpoint: String, params: [String: Any]?, success: Bool, error: String?)
    case invoiceCreated(id: String, status: String, error: String?)
    case error(message: String, context: String)
}

// MARK: - Protocol for Service

protocol QuickBooksAPIServiceProtocol {
    func authenticate() async throws
    func fetchAccounts() async throws -> [QuickBooksAccount]
    func createInvoice(_ invoice: QuickBooksInvoice) async throws -> QuickBooksInvoiceResponse
    func fetchTransactions() async throws -> [QuickBooksTransaction]
}

// MARK: - Models

struct QuickBooksAccount: Codable, Equatable {
    let id: String
    let name: String
    // Add other relevant fields
}

struct QuickBooksInvoice: Codable, Equatable {
    let id: String
    let amount: Double
    // Add other relevant fields
}

struct QuickBooksInvoiceResponse: Codable, Equatable {
    let invoiceId: String
    let status: String
    // Add other relevant fields
}

struct QuickBooksTransaction: Codable, Equatable {
    let id: String
    let date: Date
    let amount: Double
    // Add other relevant fields
}

// MARK: - Error Handling

enum QuickBooksAPIServiceError: Error, LocalizedError {
    case authenticationFailed
    case tokenStoreError(String)
    case networkError(Error)
    case invalidResponse
    case mappingError(Error)
    case unauthorized
    case unknown

    var errorDescription: String? {
        switch self {
        case .authenticationFailed: return "Authentication with QuickBooks failed."
        case .tokenStoreError(let msg): return "Token storage error: \(msg)"
        case .networkError(let err): return "Network error: \(err.localizedDescription)"
        case .invalidResponse: return "Invalid response from QuickBooks."
        case .mappingError(let err): return "Failed to map QuickBooks data: \(err.localizedDescription)"
        case .unauthorized: return "Unauthorized access to QuickBooks."
        case .unknown: return "Unknown QuickBooks API error."
        }
    }
}

// MARK: - Service Implementation

final class QuickBooksAPIService: QuickBooksAPIServiceProtocol {
    private let session: URLSession
    private let tokenStore: QuickBooksTokenStore
    private let auditLogger: QuickBooksAuditLogger

    private var accessToken: String? {
        get { try? tokenStore.load() }
        set {
            if let token = newValue {
                try? tokenStore.save(token: token)
            } else {
                try? tokenStore.clear()
            }
        }
    }

    init(
        session: URLSession = .shared,
        tokenStore: QuickBooksTokenStore,
        auditLogger: QuickBooksAuditLogger
    ) {
        self.session = session
        self.tokenStore = tokenStore
        self.auditLogger = auditLogger
    }

    func authenticate() async throws {
        auditLogger.log(event: .authenticationAttempt(success: false, error: nil))
        // Placeholder for OAuth2: in production, launch browser/ASWebAuth, obtain code/token, handle PKCE, etc.
        // Here, we simulate authentication.
        do {
            // let token = try await actualAuthFlow()
            let token = "demo_fake_access_token"
            try tokenStore.save(token: token)
            auditLogger.log(event: .authenticationAttempt(success: true, error: nil))
        } catch {
            auditLogger.log(event: .authenticationAttempt(success: false, error: error.localizedDescription))
            throw QuickBooksAPIServiceError.authenticationFailed
        }
    }

    func fetchAccounts() async throws -> [QuickBooksAccount] {
        let endpoint = "GET /v3/company/{companyId}/account"
        guard let token = accessToken else {
            auditLogger.log(event: .apiRequest(endpoint: endpoint, params: nil, success: false, error: "Unauthorized"))
            throw QuickBooksAPIServiceError.unauthorized
        }
        let url = URL(string: "https://quickbooks.api.intuit.com/v3/company/COMPANY_ID/account")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                auditLogger.log(event: .apiRequest(endpoint: endpoint, params: nil, success: false, error: "Invalid response"))
                throw QuickBooksAPIServiceError.invalidResponse
            }
            let accounts = try JSONDecoder().decode([QuickBooksAccount].self, from: data)
            auditLogger.log(event: .apiRequest(endpoint: endpoint, params: nil, success: true, error: nil))
            return accounts
        } catch let decodeError as DecodingError {
            auditLogger.log(event: .apiRequest(endpoint: endpoint, params: nil, success: false, error: "Mapping error: \(decodeError.localizedDescription)"))
            throw QuickBooksAPIServiceError.mappingError(decodeError)
        } catch {
            auditLogger.log(event: .apiRequest(endpoint: endpoint, params: nil, success: false, error: error.localizedDescription))
            throw QuickBooksAPIServiceError.networkError(error)
        }
    }

    func createInvoice(_ invoice: QuickBooksInvoice) async throws -> QuickBooksInvoiceResponse {
        let endpoint = "POST /v3/company/{companyId}/invoice"
        guard let token = accessToken else {
            auditLogger.log(event: .apiRequest(endpoint: endpoint, params: ["invoiceId": invoice.id], success: false, error: "Unauthorized"))
            throw QuickBooksAPIServiceError.unauthorized
        }
        let url = URL(string: "https://quickbooks.api.intuit.com/v3/company/COMPANY_ID/invoice")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(invoice)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                auditLogger.log(event: .apiRequest(endpoint: endpoint, params: ["invoiceId": invoice.id], success: false, error: "Invalid response"))
                throw QuickBooksAPIServiceError.invalidResponse
            }
            let invoiceResponse = try JSONDecoder().decode(QuickBooksInvoiceResponse.self, from: data)
            auditLogger.log(event: .invoiceCreated(id: invoiceResponse.invoiceId, status: invoiceResponse.status, error: nil))
            return invoiceResponse
        } catch let decodeError as DecodingError {
            auditLogger.log(event: .invoiceCreated(id: invoice.id, status: "error", error: "Mapping error: \(decodeError.localizedDescription)"))
            throw QuickBooksAPIServiceError.mappingError(decodeError)
        } catch {
            auditLogger.log(event: .invoiceCreated(id: invoice.id, status: "error", error: error.localizedDescription))
            throw QuickBooksAPIServiceError.networkError(error)
        }
    }

    func fetchTransactions() async throws -> [QuickBooksTransaction] {
        let endpoint = "GET /v3/company/{companyId}/transactions"
        guard let token = accessToken else {
            auditLogger.log(event: .apiRequest(endpoint: endpoint, params: nil, success: false, error: "Unauthorized"))
            throw QuickBooksAPIServiceError.unauthorized
        }
        let url = URL(string: "https://quickbooks.api.intuit.com/v3/company/COMPANY_ID/transactions")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                auditLogger.log(event: .apiRequest(endpoint: endpoint, params: nil, success: false, error: "Invalid response"))
                throw QuickBooksAPIServiceError.invalidResponse
            }
            let transactions = try JSONDecoder().decode([QuickBooksTransaction].self, from: data)
            auditLogger.log(event: .apiRequest(endpoint: endpoint, params: nil, success: true, error: nil))
            return transactions
        } catch let decodeError as DecodingError {
            auditLogger.log(event: .apiRequest(endpoint: endpoint, params: nil, success: false, error: "Mapping error: \(decodeError.localizedDescription)"))
            throw QuickBooksAPIServiceError.mappingError(decodeError)
        } catch {
            auditLogger.log(event: .apiRequest(endpoint: endpoint, params: nil, success: false, error: error.localizedDescription))
            throw QuickBooksAPIServiceError.networkError(error)
        }
    }
}

// MARK: - Stubs/Mocks for Injection, Testing, and Previews

final class MockQuickBooksTokenStore: QuickBooksTokenStore {
    private var token: String?
    func save(token: String) throws { self.token = token }
    func load() throws -> String? { token }
    func clear() throws { token = nil }
}

final class MockQuickBooksAuditLogger: QuickBooksAuditLogger {
    func log(event: QuickBooksAuditEvent) {
        // For test/UI preview: print or no-op
        // You could forward to console, UI, or unit test checks
    }
}

final class MockQuickBooksAPIService: QuickBooksAPIServiceProtocol {
    func authenticate() async throws {}
    func fetchAccounts() async throws -> [QuickBooksAccount] {
        return [
            QuickBooksAccount(id: "1", name: "Checking"),
            QuickBooksAccount(id: "2", name: "Savings")
        ]
    }
    func createInvoice(_ invoice: QuickBooksInvoice) async throws -> QuickBooksInvoiceResponse {
        return QuickBooksInvoiceResponse(invoiceId: invoice.id, status: "mocked")
    }
    func fetchTransactions() async throws -> [QuickBooksTransaction] {
        return [
            QuickBooksTransaction(id: "tx1", date: Date(), amount: 100.0),
            QuickBooksTransaction(id: "tx2", date: Date(), amount: -50.0)
        ]
    }
}
