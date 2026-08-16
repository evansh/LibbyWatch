import Vapor
import Fluent
import LibbyWatchShared

struct LoanController {
    static func list(req: Request) async throws -> [LoanResponse] {
        let user = try req.auth.require(User.self)
        let client = req.overdriveClient
        
        let token = try await getValidAccessToken(user: user, req: req)
        let loans = try await client.getLoans(patronToken: token)
        
        return loans.map { LoanResponse(from: $0) }
    }
    
    static func borrow(req: Request) async throws -> LoanResponse {
        let user = try req.auth.require(User.self)
        let bookId = req.parameters.get("bookId") ?? ""
        let client = req.overdriveClient
        
        let token = try await getValidAccessToken(user: user, req: req)
        let loan = try await client.borrow(bookId: bookId, patronToken: token)
        
        try await AuditLog(
            userId: user.id,
            eventType: "borrow",
            eventData: JSONValue(["book_id": bookId, "loan_id": loan.id]),
            ipAddress: req.headers.first(name: .xForwardedFor) ?? req.remoteAddress?.description,
            userAgent: req.headers.first(name: .userAgent)
        ).save(on: req.db)
        
        return LoanResponse(from: loan)
    }
    
    static func returnLoan(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        let loanId = req.parameters.get("loanId") ?? ""
        let client = req.overdriveClient
        
        let token = try await getValidAccessToken(user: user, req: req)
        try await client.returnLoan(loanId: loanId, patronToken: token)
        
        try await AuditLog(
            userId: user.id,
            eventType: "return",
            eventData: JSONValue(["loan_id": loanId]),
            ipAddress: req.headers.first(name: .xForwardedFor) ?? req.remoteAddress?.description,
            userAgent: req.headers.first(name: .userAgent)
        ).save(on: req.db)
        
        return .noContent
    }
    
    static func fulfillment(req: Request) async throws -> FulfillmentResponse {
        let user = try req.auth.require(User.self)
        let loanId = req.parameters.get("loanId") ?? ""
        let client = req.overdriveClient
        
        let token = try await getValidAccessToken(user: user, req: req)
        let fulfillment = try await client.getFulfillment(loanId: loanId, patronToken: token)
        
        return FulfillmentResponse(from: fulfillment)
    }
    
    static func getProgress(req: Request) async throws -> PlaybackProgressResponse {
        let user = try req.auth.require(User.self)
        let loanId = req.parameters.get("loanId") ?? ""
        
        let offline = try await OfflineAudiobook.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .filter(\.$bookId == loanId)
            .first()
        
        guard let offline = offline else {
            throw Abort(.notFound, reason: "No offline audiobook found for loan")
        }
        
        let manifest = try JSONDecoder().decode(AudiobookManifest.self, from: offline.manifestJSON)
        let progress = PlaybackProgress(
            chapterIndex: offline.downloadedChapters.max() ?? 0,
            positionInChapter: 0,
            totalDuration: manifest.totalDuration
        )
        
        return PlaybackProgressResponse(from: progress)
    }
    
    static func updateProgress(req: Request) async throws -> PlaybackProgressResponse {
        let user = try req.auth.require(User.self)
        let loanId = req.parameters.get("loanId") ?? ""
        
        struct ProgressRequest: Content {
            let chapterIndex: Int
            let positionInChapter: Double
            let totalDuration: Double
            let playbackRate: Float
        }
        
        let progressRequest = try req.content.decode(ProgressRequest.self)
        let progress = PlaybackProgress(
            chapterIndex: progressRequest.chapterIndex,
            positionInChapter: progressRequest.positionInChapter,
            totalDuration: progressRequest.totalDuration,
            playbackRate: progressRequest.playbackRate
        )
        
        try await AuditLog(
            userId: user.id,
            eventType: "progress_update",
            eventData: JSONValue([
                "loan_id": loanId,
                "chapter": progressRequest.chapterIndex,
                "position": progressRequest.positionInChapter
            ]),
            ipAddress: req.headers.first(name: .xForwardedFor) ?? req.remoteAddress?.description,
            userAgent: req.headers.first(name: .userAgent)
        ).save(on: req.db)
        
        return PlaybackProgressResponse(from: progress)
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

struct LoanResponse: Content {
    let id: String
    let book: BookResponse
    let expiresAt: Date
    let downloadedAt: Date?
    let progress: PlaybackProgressResponse?
    let isReturned: Bool
    let fulfillmentURL: String?
    
    init(from loan: Loan) {
        self.id = loan.id
        self.book = BookResponse(from: loan.book)
        self.expiresAt = loan.expiresAt
        self.downloadedAt = loan.downloadedAt
        self.progress = loan.progress.map { PlaybackProgressResponse(from: $0) }
        self.isReturned = loan.isReturned
        self.fulfillmentURL = loan.fulfillmentURL?.absoluteString
    }
}

struct FulfillmentResponse: Content {
    let type: String
    let url: String
    let expiresAt: Date?
    let drmScheme: String?
    
    init(from fulfillment: Fulfillment) {
        self.type = fulfillment.type.rawValue
        self.url = fulfillment.url.absoluteString
        self.expiresAt = fulfillment.expiresAt
        self.drmScheme = fulfillment.drmScheme?.rawValue
    }
}

struct PlaybackProgressResponse: Content {
    let chapterIndex: Int
    let positionInChapter: Double
    let totalDuration: Double
    let lastUpdated: Date
    let playbackRate: Float
    let overallProgress: Double
    
    init(from progress: PlaybackProgress) {
        self.chapterIndex = progress.chapterIndex
        self.positionInChapter = progress.positionInChapter
        self.totalDuration = progress.totalDuration
        self.lastUpdated = progress.lastUpdated
        self.playbackRate = progress.playbackRate
        self.overallProgress = progress.overallProgress
    }
}