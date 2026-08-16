import Foundation
import LibbyWatchModels

public protocol OverDriveAPIClient: Sendable {
    func search(query: String, library: Library, page: Int, pageSize: Int) async throws -> SearchResult
    func getBook(id: String, library: Library) async throws -> Book
    func getAvailability(for bookIds: [String], library: Library) async throws -> [String: Availability]
    func getLoans(patronToken: String) async throws -> [Loan]
    func getHolds(patronToken: String) async throws -> [Hold]
    func borrow(bookId: String, patronToken: String) async throws -> Loan
    func placeHold(bookId: String, patronToken: String) async throws -> Hold
    func returnLoan(loanId: String, patronToken: String) async throws
    func cancelHold(holdId: String, patronToken: String) async throws
    func getFulfillment(loanId: String, patronToken: String) async throws -> Fulfillment
    func getSamples(bookId: String, library: Library) async throws -> [Sample]
}

public struct Fulfillment: Codable, Sendable {
    public let type: FulfillmentType
    public let url: URL
    public let expiresAt: Date?
    public let drmScheme: DRMScheme?
    
    public init(type: FulfillmentType, url: URL, expiresAt: Date? = nil, drmScheme: DRMScheme? = nil) {
        self.type = type
        self.url = url
        self.expiresAt = expiresAt
        self.drmScheme = drmScheme
    }
}

public enum FulfillmentType: String, Codable, Sendable {
    case overdriveListen = "overdrive-listen"
    case odread = "odread"
    case adobe = "adobe"
    case axis360 = "axis360"
    case unknown
}

public enum DRMScheme: String, Codable, Sendable {
    case adobe = "adobe"
    case lcp = "lcp"
    case fairplay = "fairplay"
    case none
}

public struct Sample: Codable, Sendable {
    public let type: SampleType
    public let url: URL
    public let duration: TimeInterval?
    
    public init(type: SampleType, url: URL, duration: TimeInterval? = nil) {
        self.type = type
        self.url = url
        self.duration = duration
    }
}

public enum SampleType: String, Codable, Sendable {
    case audio = "audio"
    case text = "text"
    case unknown
}

public enum APIError: Error, LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, data: Data?)
    case decodingError(Error)
    case encodingError(Error)
    case unauthorized
    case forbidden
    case notFound
    case rateLimited(retryAfter: TimeInterval?)
    case serverError
    case networkError(Error)
    case tokenExpired
    case invalidToken
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .httpError(let statusCode, _): return "HTTP error: \(statusCode)"
        case .decodingError(let error): return "Decoding error: \(error.localizedDescription)"
        case .encodingError(let error): return "Encoding error: \(error.localizedDescription)"
        case .unauthorized: return "Unauthorized - please re-authenticate"
        case .forbidden: return "Forbidden"
        case .notFound: return "Resource not found"
        case .rateLimited(let retryAfter): return "Rate limited" + (retryAfter.map { " - retry after \($0)s" } ?? "")
        case .serverError: return "Server error"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .tokenExpired: return "Token expired"
        case .invalidToken: return "Invalid token"
        }
    }
}

public struct APIConfiguration: Sendable {
    public let baseURL: URL
    public let clientId: String
    public let clientSecret: String
    public let userAgent: String
    public let timeout: TimeInterval
    
    public init(baseURL: URL, clientId: String, clientSecret: String, userAgent: String, timeout: TimeInterval = 30) {
        self.baseURL = baseURL
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.userAgent = userAgent
        self.timeout = timeout
    }
}