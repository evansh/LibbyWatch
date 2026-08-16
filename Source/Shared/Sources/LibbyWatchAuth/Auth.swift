import Foundation
import Crypto
import X509
import JWTKit
import LibbyWatchModels

public struct QRCodeAuthRequest: Codable, Sendable {
    public let clientId: String
    public let redirectURL: String
    public let scope: String
    public let state: String
    public let responseType: String = "code"
    
    public init(clientId: String, redirectURL: String, scope: String, state: String) {
        self.clientId = clientId
        self.redirectURL = redirectURL
        self.scope = scope
        self.state = state
    }
    
    public var authorizationURL: URL? {
        var components = URLComponents(string: "https://auth.overdrive.com/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURL),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "response_type", value: responseType),
        ]
        return components.url
    }
}

public struct TokenResponse: Codable, Sendable {
    public let accessToken: String
    public let tokenType: String
    public let expiresIn: Int
    public let refreshToken: String
    public let scope: String
    public let patronId: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case patronId = "patron_id"
    }
}

public struct TokenPair: Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date
    public let patronId: String?
    
    public init(accessToken: String, refreshToken: String, expiresIn: TimeInterval, patronId: String? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = Date().addingTimeInterval(expiresIn)
        self.patronId = patronId
    }
    
    public var isExpired: Bool {
        Date() >= expiresAt.addingTimeInterval(-60)
    }
}

public actor TokenStore {
    private var tokens: [String: TokenPair] = [:]
    private let encryptionKey: SymmetricKey
    
    public init(encryptionKey: SymmetricKey) {
        self.encryptionKey = encryptionKey
    }
    
    public func store(patronId: String, tokenPair: TokenPair) async {
        tokens[patronId] = tokenPair
    }
    
    public func retrieve(patronId: String) async -> TokenPair? {
        tokens[patronId]
    }
    
    public func delete(patronId: String) async {
        tokens.removeValue(forKey: patronId)
    }
    
    public func allPatronIds() async -> [String] {
        Array(tokens.keys)
    }
    
    public func encryptTokenPair(_ tokenPair: TokenPair) async throws -> Data {
        let data = try JSONEncoder().encode(tokenPair)
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
        return sealedBox.combined!
    }
    
    public func decryptTokenPair(_ data: Data) async throws -> TokenPair {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decrypted = try AES.GCM.open(sealedBox, using: encryptionKey)
        return try JSONDecoder().decode(TokenPair.self, from: decrypted)
    }
}

public struct QRCodeAuthenticator: Sendable {
    private let configuration: APIConfiguration
    private let tokenStore: TokenStore
    private let session: URLSession
    
    public init(configuration: APIConfiguration, tokenStore: TokenStore, session: URLSession = .shared) {
        self.configuration = configuration
        self.tokenStore = tokenStore
        self.session = session
    }
    
    public func initiateQRCodeAuth(redirectURL: String, scope: String = "profile loans holds") -> QRCodeAuthRequest {
        let state = UUID().uuidString
        return QRCodeAuthRequest(
            clientId: configuration.clientId,
            redirectURL: redirectURL,
            scope: scope,
            state: state
        )
    }
    
    public func exchangeCodeForToken(code: String, redirectURL: String) async throws -> TokenPair {
        var components = URLComponents(string: "https://auth.overdrive.com/oauth/token")!
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectURL),
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "client_secret", value: configuration.clientSecret),
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        return TokenPair(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresIn: TimeInterval(tokenResponse.expiresIn),
            patronId: tokenResponse.patronId
        )
    }
    
    public func refreshAccessToken(patronId: String) async throws -> TokenPair {
        guard let tokenPair = await tokenStore.retrieve(patronId: patronId) else {
            throw APIError.invalidToken
        }
        
        var components = URLComponents(string: "https://auth.overdrive.com/oauth/token")!
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: tokenPair.refreshToken),
            URLQueryItem(name: "client_id", value: configuration.clientId),
            URLQueryItem(name: "client_secret", value: configuration.clientSecret),
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 400 || httpResponse.statusCode == 401 {
                await tokenStore.delete(patronId: patronId)
                throw APIError.tokenExpired
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        let newTokenPair = TokenPair(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresIn: TimeInterval(tokenResponse.expiresIn),
            patronId: tokenResponse.patronId
        )
        
        await tokenStore.store(patronId: patronId, tokenPair: newTokenPair)
        return newTokenPair
    }
    
    public func getValidAccessToken(patronId: String) async throws -> String {
        guard let tokenPair = await tokenStore.retrieve(patronId: patronId) else {
            throw APIError.invalidToken
        }
        
        if tokenPair.isExpired {
            let newTokenPair = try await refreshAccessToken(patronId: patronId)
            return newTokenPair.accessToken
        }
        
        return tokenPair.accessToken
    }
}

public struct PatronCollectionToken: Codable, Sendable {
    public let token: String
    public let expiresAt: Date
    public let libraryId: String
    
    public var isExpired: Bool {
        Date() >= expiresAt.addingTimeInterval(-300)
    }
}

public actor CollectionTokenStore {
    private var tokens: [String: PatronCollectionToken] = [:]
    
    public init() {}
    
    public func store(libraryId: String, token: PatronCollectionToken) async {
        tokens[libraryId] = token
    }
    
    public func retrieve(libraryId: String) async -> PatronCollectionToken? {
        tokens[libraryId]
    }
    
    public func delete(libraryId: String) async {
        tokens.removeValue(forKey: libraryId)
    }
}