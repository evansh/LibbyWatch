import Vapor
import LibbyWatchShared
import JWTKit

func routes(_ app: Application) throws {
    app.get("health") { req in
        return ["status": "ok", "timestamp": Date()]
    }
    
    let api = app.grouped("api", "v1")
    
    api.grouped(UserAuthenticator()).group("auth") { auth in
        auth.post("qr-initiate", use: AuthController.initiateQR)
        auth.post("qr-callback", use: AuthController.handleQRCallback)
        auth.post("refresh", use: AuthController.refreshToken)
        auth.post("revoke", use: AuthController.revokeToken)
    }
    
    let protected = api.grouped(UserAuthenticator(), UserGuardMiddleware())
    
    protected.group("libraries") { libraries in
        libraries.get(use: LibraryController.list)
        libraries.get(":id", use: LibraryController.get)
        libraries.get(":id", "search", use: LibraryController.search)
        libraries.get(":id", "availability", use: LibraryController.availability)
    }
    
    protected.group("loans") { loans in
        loans.get(use: LoanController.list)
        loans.post(":bookId", "borrow", use: LoanController.borrow)
        loans.post(":loanId", "return", use: LoanController.returnLoan)
        loans.get(":loanId", "fulfillment", use: LoanController.fulfillment)
        loans.get(":loanId", "progress", use: LoanController.getProgress)
        loans.put(":loanId", "progress", use: LoanController.updateProgress)
    }
    
    protected.group("holds") { holds in
        holds.get(use: HoldController.list)
        holds.post(":bookId", use: HoldController.place)
        holds.delete(":holdId", use: HoldController.cancel)
        holds.post(":holdId", "suspend", use: HoldController.suspend)
        holds.post(":holdId", "reactivate", use: HoldController.reactivate)
    }
    
    protected.group("offline") { offline in
        offline.get(use: OfflineController.list)
        offline.post("download", use: OfflineController.startDownload)
        offline.get(":bookId", "status", use: OfflineController.downloadStatus)
        offline.delete(":bookId", use: OfflineController.delete)
        offline.post("cleanup", use: OfflineController.cleanupExpired)
    }
    
    protected.group("sync") { sync in
        sync.post("progress", use: SyncController.syncProgress)
        sync.get("progress/:bookId", use: SyncController.getProgress)
    }
    
    protected.group("session") { session in
        session.post("export", use: SessionController.export)
        session.post("incident", use: SessionController.reportIncident)
    }
}

struct UserAuthenticator: AsyncBearerAuthenticator {
    typealias User = AppUser
    
    func authenticate(bearer: BearerAuthorization, for request: Request) async throws {
        guard let token = try await Token.query(on: request.db)
            .join(User.self, on: \Token.$user.$id == \User.$id)
            .filter(User.self, \.$id == bearer.token)
            .first() else {
            return
        }
        
        if token.expiresAt < Date() {
            return
        }
        
        request.auth.login(token.user)
    }
}

struct UserGuardMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard request.auth.has(User.self) else {
            throw Abort(.unauthorized, reason: "Authentication required")
        }
        return try await next.respond(to: request)
    }
}