import Foundation
import LibbyWatchModels

public final class OverDriveClient: OverDriveAPIClient, @unchecked Sendable {
    private let configuration: APIConfiguration
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    public init(configuration: APIConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    public func search(query: String, library: Library, page: Int = 1, pageSize: Int = 20) async throws -> SearchResult {
        var components = URLComponents(url: configuration.baseURL.appendingPathComponent("v2/libraries/\(library.id)/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "perPage", value: "\(pageSize)"),
        ]
        
        return try await performRequest(url: components.url!, method: "GET", patronToken: nil)
    }
    
    public func getBook(id: String, library: Library) async throws -> Book {
        let url = configuration.baseURL.appendingPathComponent("v2/libraries/\(library.id)/titles/\(id)")
        return try await performRequest(url: url, method: "GET", patronToken: nil)
    }
    
    public func getAvailability(for bookIds: [String], library: Library) async throws -> [String: Availability] {
        let ids = bookIds.joined(separator: ",")
        var components = URLComponents(url: configuration.baseURL.appendingPathComponent("v2/libraries/\(library.id)/availability"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "ids", value: ids)]
        
        struct AvailabilityResponse: Codable {
            let availability: [String: Availability]
        }
        
        let response: AvailabilityResponse = try await performRequest(url: components.url!, method: "GET", patronToken: nil)
        return response.availability
    }
    
    public func getLoans(patronToken: String) async throws -> [Loan] {
        let url = configuration.baseURL.appendingPathComponent("v2/patron/loans")
        return try await performRequest(url: url, method: "GET", patronToken: patronToken)
    }
    
    public func getHolds(patronToken: String) async throws -> [Hold] {
        let url = configuration.baseURL.appendingPathComponent("v2/patron/holds")
        return try await performRequest(url: url, method: "GET", patronToken: patronToken)
    }
    
    public func borrow(bookId: String, patronToken: String) async throws -> Loan {
        let url = configuration.baseURL.appendingPathComponent("v2/patron/loans")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(["titleId": bookId])
        
        return try await performRequest(request: request, patronToken: patronToken, expectData: true)
    }
    
    public func placeHold(bookId: String, patronToken: String) async throws -> Hold {
        let url = configuration.baseURL.appendingPathComponent("v2/patron/holds")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(["titleId": bookId])
        
        return try await performRequest(request: request, patronToken: patronToken, expectData: true)
    }
    
    public func returnLoan(loanId: String, patronToken: String) async throws {
        let url = configuration.baseURL.appendingPathComponent("v2/patron/loans/\(loanId)/return")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        try await performRequestVoid(request: request, patronToken: patronToken)
    }
    
    public func cancelHold(holdId: String, patronToken: String) async throws {
        let url = configuration.baseURL.appendingPathComponent("v2/patron/holds/\(holdId)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        try await performRequestVoid(request: request, patronToken: patronToken)
    }
    
    public func getFulfillment(loanId: String, patronToken: String) async throws -> Fulfillment {
        let url = configuration.baseURL.appendingPathComponent("v2/patron/loans/\(loanId)/fulfillment")
        return try await performRequest(url: url, method: "GET", patronToken: patronToken)
    }
    
    public func getSamples(bookId: String, library: Library) async throws -> [Sample] {
        let url = configuration.baseURL.appendingPathComponent("v2/libraries/\(library.id)/titles/\(bookId)/samples")
        struct SamplesResponse: Codable { let samples: [Sample] }
        let response: SamplesResponse = try await performRequest(url: url, method: "GET", patronToken: nil)
        return response.samples
    }
    
    private func performRequest<T: Decodable>(url: URL, method: String = "GET", patronToken: String?, expectData: Bool = true) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = configuration.timeout
        request.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let patronToken = patronToken {
            request.setValue("Bearer \(patronToken)", forHTTPHeaderField: "Authorization")
        }
        
        return try await performRequest(request: request, patronToken: patronToken, expectData: expectData)
    }
    
    private func performRequest<T: Decodable>(request: URLRequest, patronToken: String?, expectData: Bool) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200..<300:
                if expectData {
                    return try decoder.decode(T.self, from: data)
                } else {
                    return try decoder.decode(T.self, from: "{}".data(using: .utf8)!)
                }
            case 401:
                throw APIError.unauthorized
            case 403:
                throw APIError.forbidden
            case 404:
                throw APIError.notFound
            case 429:
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
                throw APIError.rateLimited(retryAfter: retryAfter)
            case 500..<600:
                throw APIError.serverError
            default:
                throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    private func performRequestVoid(request: URLRequest, patronToken: String?) async throws {
        do {
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200..<300:
                return
            case 401:
                throw APIError.unauthorized
            case 403:
                throw APIError.forbidden
            case 404:
                throw APIError.notFound
            case 429:
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
                throw APIError.rateLimited(retryAfter: retryAfter)
            case 500..<600:
                throw APIError.serverError
            default:
                throw APIError.httpError(statusCode: httpResponse.statusCode, data: nil)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
}