import Vapor
import Fluent
import JWTKit
import Crypto
import LibbyWatchShared

struct AuthController {
    static func initiateQR(req: Request) async throws -> QRInitResponse {
        let qrAuth = QRCodeAuthRequest(
            clientId: req.overdriveConfig.clientId,
            redirectURL: req.overdriveConfig.redirectURL,
            scope: "profile loans holds",
            state: UUID().uuidString
        )
        
        try await AuditLog(
            userId: nil,
            eventType: "qr_initiate",
            eventData: JSONValue(["state": qrAuth.state]),
            ipAddress: req.headers.first(name: .xForwardedFor) ?? req.remoteAddress?.description,
            userAgent: req.headers.first(name: .userAgent)
        ).save(on: req.db)
        
        return QRInitResponse(
            authorizationURL: qrAuth.authorizationURL!.absoluteString,
            state: qrAuth.state
        )
    }
    
    static func handleQRCallback(req: Request) async throws -> TokenResponse {
        struct CallbackRequest: Content {
            let code: String
            let state: String
        }
        
        let callback = try req.content.decode(CallbackRequest.self)
        
        let tokenPair = try await req.qrAuthenticator.exchangeCodeForToken(code: callback.code, redirectURL: req.overdriveConfig.redirectURL)
        
        let user = try await findOrCreateUser(patronId: tokenPair.patronId ?? UUID().uuidString, req: req)
        try await storeTokens(user: user, tokenPair: tokenPair, req: req)
        
        let jwt = try await generateJWT(for: user, req: req)
        
        try await AuditLog(
            userId: user.id,
            eventType: "qr_callback",
            eventData: JSONValue(["patron_id": tokenPair.patronId ?? ""]),
            ipAddress: req.headers.first(name: .xForwardedFor) ?? req.remoteAddress?.description,
            userAgent: req.headers.first(name: .userAgent)
        ).save(on: req.db)
        
        return TokenResponse(accessToken: jwt, tokenType: "Bearer", expiresIn: 3600)
    }
    
    static func refreshToken(req: Request) async throws -> TokenResponse {
        let user = try req.auth.require(User.self)
        
        guard let token = try await Token.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .first() else {
            throw Abort(.unauthorized, reason: "No token found")
        }
        
        let newTokenPair = try await req.qrAuthenticator.refreshAccessToken(patronId: user.patronId)
        try await updateTokens(user: user, tokenPair: newTokenPair, req: req)
        
        let jwt = try await generateJWT(for: user, req: req)
        
        return TokenResponse(accessToken: jwt, tokenType: "Bearer", expiresIn: 3600)
    }
    
    static func revokeToken(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        
        try await Token.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .delete()
        
        user.accessTokenHash = nil
        try await user.save(on: req.db)
        
        try await AuditLog(
            userId: user.id,
            eventType: "token_revoke",
            ipAddress: req.headers.first(name: .xForwardedFor) ?? req.remoteAddress?.description,
            userAgent: req.headers.first(name: .userAgent)
        ).save(on: req.db)
        
        return .noContent
    }
    
    private static func findOrCreateUser(patronId: String, req: Request) async throws -> User {
        if let existing = try await User.query(on: req.db)
            .filter(\.$patronId == patronId)
            .first() {
            return existing
        }
        
        let user = User(patronId: patronId, name: "Patron \(patronId.prefix(8))", libraryCardNumber: patronId)
        try await user.save(on: req.db)
        return user
    }
    
    private static func storeTokens(user: User, tokenPair: TokenPair, req: Request) async throws {
        let accessEncrypted = try req.crypto.encrypt(tokenPair.accessToken.data(using: .utf8)!)
        let refreshEncrypted = try req.crypto.encrypt(tokenPair.refreshToken.data(using: .utf8)!)
        
        let token = Token(
            userId: user.id!,
            accessTokenEncrypted: accessEncrypted,
            refreshTokenEncrypted: refreshEncrypted,
            expiresAt: tokenPair.expiresAt
        )
        try await token.save(on: req.db)
        
        user.accessTokenHash = hashToken(tokenPair.accessToken)
        try await user.save(on: req.db)
    }
    
    private static func updateTokens(user: User, tokenPair: TokenPair, req: Request) async throws {
        let accessEncrypted = try req.crypto.encrypt(tokenPair.accessToken.data(using: .utf8)!)
        let refreshEncrypted = try req.crypto.encrypt(tokenPair.refreshToken.data(using: .utf8)!)
        
        try await Token.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .set(\.$accessTokenEncrypted, to: accessEncrypted)
            .set(\.$refreshTokenEncrypted, to: refreshEncrypted)
            .set(\.$expiresAt, to: tokenPair.expiresAt)
            .update()
        
        user.accessTokenHash = hashToken(tokenPair.accessToken)
        try await user.save(on: req.db)
    }
    
    private static func generateJWT(for user: User, req: Request) async throws -> String {
        let payload = LibbyWatchJWTPayload(
            sub: user.id!.uuidString,
            patronId: user.patronId,
            exp: ExpirationClaim(value: Date().addingTimeInterval(3600)),
            iat: IssuedAtClaim(value: Date())
        )
        
        let header = ["alg": "HS256", "typ": "JWT"]
        let headerData = try JSONEncoder().encode(header)
        let payloadData = try JSONEncoder().encode(payload)
        
        let headerB64 = base64URLEncode(headerData)
        let payloadB64 = base64URLEncode(payloadData)
        let signingInput = "\(headerB64).\(payloadB64)"
        
        let signature = try req.jwtSigner.sign(Data(signingInput.utf8))
        let signatureB64 = base64URLEncode(Data(signature))
        
        return "\(signingInput).\(signatureB64)"
    }
    
    private static func base64URLEncode(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    private static func hashToken(_ token: String) -> String {
        let data = Data(token.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
    }
}

struct QRInitResponse: Content {
    let authorizationURL: String
    let state: String
}

struct TokenResponse: Content {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

struct LibbyWatchJWTPayload: JWTPayload, Authenticatable {
    let sub: String
    let patronId: String
    let exp: ExpirationClaim
    let iat: IssuedAtClaim
    
    func verify(using algorithm: some JWTAlgorithm) async throws {
        try exp.verifyNotExpired()
    }
}