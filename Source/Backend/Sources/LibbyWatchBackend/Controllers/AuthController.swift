import Vapor
import Fluent
import JWTKit
import Crypto
import LibbyWatchShared

struct AuthController {
    static func initiateQR(req: Request) async throws -> QRInitResponse {
        let qrAuth = QRCodeAuthRequest(
            clientId: req.application.overdriveConfig.clientId,
            redirectURL: req.application.overdriveConfig.redirectURL,
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
        
        let tokenPair = try await req.overdriveClient.exchangeCodeForToken(code: callback.code, redirectURL: req.application.overdriveConfig.redirectURL)
        
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
        
        let decrypted = try req.application.crypto.decrypt(token.refreshTokenEncrypted)
        let refreshToken = String(data: decrypted, encoding: .utf8)!
        
        let newTokenPair = try await req.overdriveClient.refreshAccessToken(refreshToken: refreshToken)
        try await updateTokens(user: user, tokenPair: newTokenPair, req: req)
        
        let jwt = try await generateJWT(for: user, req: req)
        
        return TokenResponse(accessToken: jwt, tokenType: "Bearer", expiresIn: 3600)
    }
    
    static func revokeToken(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        
        try await Token.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .delete()
        
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
        let accessEncrypted = try req.application.crypto.encrypt(tokenPair.accessToken.data(using: .utf8)!)
        let refreshEncrypted = try req.application.crypto.encrypt(tokenPair.refreshToken.data(using: .utf8)!)
        
        let token = Token(
            userId: user.id!,
            accessTokenEncrypted: accessEncrypted,
            refreshTokenEncrypted: refreshEncrypted,
            expiresAt: tokenPair.expiresAt
        )
        try await token.save(on: req.db)
    }
    
    private static func updateTokens(user: User, tokenPair: TokenPair, req: Request) async throws {
        let accessEncrypted = try req.application.crypto.encrypt(tokenPair.accessToken.data(using: .utf8)!)
        let refreshEncrypted = try req.application.crypto.encrypt(tokenPair.refreshToken.data(using: .utf8)!)
        
        try await Token.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .set(\.$accessTokenEncrypted, to: accessEncrypted)
            .set(\.$refreshTokenEncrypted, to: refreshEncrypted)
            .set(\.$expiresAt, to: tokenPair.expiresAt)
            .update()
    }
    
    private static func generateJWT(for user: User, req: Request) async throws -> String {
        let payload = JWTPayload(
            sub: user.id!.uuidString,
            patronId: user.patronId,
            exp: ExpirationClaim(value: Date().addingTimeInterval(3600)),
            iat: IssuedAtClaim(value: Date())
        )
        
        return try req.application.jwt.signers.sign(payload)
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

struct JWTPayload: JWTPayload, Authenticatable {
    let sub: String
    let patronId: String
    let exp: ExpirationClaim
    let iat: IssuedAtClaim
    
    func verify(using signer: JWTSigner) throws {
        try exp.verifyNotExpired()
    }
}