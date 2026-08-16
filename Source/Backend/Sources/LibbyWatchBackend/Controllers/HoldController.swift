import Vapor
import Fluent
import LibbyWatchShared

struct HoldController {
    static func list(req: Request) async throws -> [HoldResponse] {
        let user = try req.auth.require(User.self)
        let client = req.overdriveClient
        
        let token = try await getValidAccessToken(user: user, req: req)
        let holds = try await client.getHolds(patronToken: token)
        
        return holds.map { HoldResponse(from: $0) }
    }
    
    static func place(req: Request) async throws -> HoldResponse {
        let user = try req.auth.require(User.self)
        let bookId = req.parameters.get("bookId") ?? ""
        let client = req.overdriveClient
        
        let token = try await getValidAccessToken(user: user, req: req)
        let hold = try await client.placeHold(bookId: bookId, patronToken: token)
        
        try await AuditLog(
            userId: user.id,
            eventType: "place_hold",
            eventData: JSONValue(["book_id": bookId, "hold_id": hold.id]),
            ipAddress: req.headers.first(name: .xForwardedFor) ?? req.remoteAddress?.description,
            userAgent: req.headers.first(name: .userAgent)
        ).save(on: req.db)
        
        return HoldResponse(from: hold)
    }
    
    static func cancel(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        let holdId = req.parameters.get("holdId") ?? ""
        let client = req.overdriveClient
        
        let token = try await getValidAccessToken(user: user, req: req)
        try await client.cancelHold(holdId: holdId, patronToken: token)
        
        try await AuditLog(
            userId: user.id,
            eventType: "cancel_hold",
            eventData: JSONValue(["hold_id": holdId]),
            ipAddress: req.headers.first(name: .xForwardedFor) ?? req.remoteAddress?.description,
            userAgent: req.headers.first(name: .userAgent)
        ).save(on: req.db)
        
        return .noContent
    }
    
    static func suspend(req: Request) async throws -> HoldResponse {
        let user = try req.auth.require(User.self)
        let holdId = req.parameters.get("holdId") ?? ""
        
        try await AuditLog(
            userId: user.id,
            eventType: "suspend_hold",
            eventData: JSONValue(["hold_id": holdId]),
            ipAddress: req.headers.first(name: .xForwardedFor) ?? req.remoteAddress?.description,
            userAgent: req.headers.first(name: .userAgent)
        ).save(on: req.db)
        
        throw Abort(.notImplemented, reason: "Hold suspension not yet implemented")
    }
    
    static func reactivate(req: Request) async throws -> HoldResponse {
        let user = try req.auth.require(User.self)
        let holdId = req.parameters.get("holdId") ?? ""
        
        try await AuditLog(
            userId: user.id,
            eventType: "reactivate_hold",
            eventData: JSONValue(["hold_id": holdId]),
            ipAddress: req.headers.first(name: .xForwardedFor) ?? req.remoteAddress?.description,
            userAgent: req.headers.first(name: .userAgent)
        ).save(on: req.db)
        
        throw Abort(.notImplemented, reason: "Hold reactivation not yet implemented")
    }
    
    private static func getValidAccessToken(user: User, req: Request) async throws -> String {
        let token = try await Token.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .first()
        
        guard let token = token else {
            throw Abort(.unauthorized, reason: "No token stored")
        }
        
        if token.expiresAt < Date() {
            let decrypted = try req.application.crypto.decrypt(token.refreshTokenEncrypted)
            let refreshToken = String(data: decrypted, encoding: .utf8)!
            
            let newTokenPair = try await req.overdriveClient.refreshAccessToken(refreshToken: refreshToken)
            
            let accessEncrypted = try req.application.crypto.encrypt(newTokenPair.accessToken.data(using: .utf8)!)
            let refreshEncrypted = try req.application.crypto.encrypt(newTokenPair.refreshToken.data(using: .utf8)!)
            
            try await Token.query(on: req.db)
                .filter(\.$user.$id == user.id!)
                .set(\.$accessTokenEncrypted, to: accessEncrypted)
                .set(\.$refreshTokenEncrypted, to: refreshEncrypted)
                .set(\.$expiresAt, to: newTokenPair.expiresAt)
                .update()
            
            return newTokenPair.accessToken
        }
        
        let decrypted = try req.application.crypto.decrypt(token.accessTokenEncrypted)
        return String(data: decrypted, encoding: .utf8)!
    }
}

struct HoldResponse: Content {
    let id: String
    let book: BookResponse
    let placedAt: Date
    let position: Int
    let isReady: Bool
    let readyAt: Date?
    let expiresAt: Date?
    
    init(from hold: Hold) {
        self.id = hold.id
        self.book = BookResponse(from: hold.book)
        self.placedAt = hold.placedAt
        self.position = hold.position
        self.isReady = hold.isReady
        self.readyAt = hold.readyAt
        self.expiresAt = hold.expiresAt
    }
}