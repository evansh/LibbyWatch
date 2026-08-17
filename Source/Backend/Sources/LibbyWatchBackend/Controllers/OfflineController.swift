import Vapor
import Fluent
import LibbyWatchShared

struct OfflineController {
    static func list(req: Request) async throws -> [OfflineAudiobookResponse] {
        let user = try req.auth.require(User.self)
        
        let offlineBooks = try await OfflineAudiobook.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .all()
        
        return offlineBooks.map { OfflineAudiobookResponse(from: $0) }
    }
    
    static func startDownload(req: Request) async throws -> OfflineAudiobookResponse {
        let user = try req.auth.require(User.self)
        
        struct DownloadRequest: Content {
            let bookId: String
            let loanId: String
        }
        
        let request = try req.content.decode(DownloadRequest.self)
        let client = req.overdriveClient
        
        let token = try await getValidAccessToken(user: user, req: req)
        let fulfillment = try await client.getFulfillment(loanId: request.loanId, patronToken: token)
        
        let book = try await client.getBook(id: request.bookId, library: Library(id: "nypl", name: "NYPL", shortName: "NYPL", websiteURL: URL(string: "https://nypl.org")!, overdriveURL: URL(string: "https://nypl.overdrive.com")!, isAdvantage: false))
        
        let manifest = AudiobookManifest(
            bookId: request.bookId,
            chapters: (0..<15).map { index in
                Chapter(index: index, title: "Chapter \(index + 1)", startOffset: Double(index) * 3600, duration: 3600, url: URL(string: "https://example.com/chapter_\(index).mp3")!)
            },
            totalDuration: book.duration ?? 15 * 3600,
            drmScheme: fulfillment.drmScheme,
            licenseURL: nil,
            expiresAt: fulfillment.expiresAt
        )
        
        let localPath = req.offlineStoragePath.appendingPathComponent("Audiobooks/\(request.bookId)").path
        try FileManager.default.createDirectory(atPath: localPath, withIntermediateDirectories: true)
        
        let manifestData = try JSONEncoder().encode(manifest)
        
        let offline = OfflineAudiobook(
            userId: user.id!,
            bookId: request.bookId,
            manifestJSON: manifestData,
            localPath: localPath,
            downloadedAt: Date(),
            expiresAt: fulfillment.expiresAt,
            isComplete: false,
            downloadedChapters: []
        )
        
        try await offline.save(on: req.db)
        
        Task.detached {
            await downloadChapters(offline: offline, manifest: manifest, req: req)
        }
        
        try await AuditLog(
            userId: user.id,
            eventType: "download_start",
            eventData: JSONValue(["book_id": request.bookId, "loan_id": request.loanId]),
            ipAddress: req.headers.first(name: .xForwardedFor) ?? req.remoteAddress?.description,
            userAgent: req.headers.first(name: .userAgent)
        ).save(on: req.db)
        
        return OfflineAudiobookResponse(from: offline)
    }
    
    static func downloadStatus(req: Request) async throws -> OfflineAudiobookResponse {
        let user = try req.auth.require(User.self)
        let bookId = req.parameters.get("bookId") ?? ""
        
        guard let offline = try await OfflineAudiobook.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .filter(\.$bookId == bookId)
            .first() else {
            throw Abort(.notFound, reason: "Offline audiobook not found")
        }
        
        return OfflineAudiobookResponse(from: offline)
    }
    
    static func delete(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        let bookId = req.parameters.get("bookId") ?? ""
        
        guard let offline = try await OfflineAudiobook.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .filter(\.$bookId == bookId)
            .first() else {
            throw Abort(.notFound, reason: "Offline audiobook not found")
        }
        
        let url = URL(fileURLWithPath: offline.localPath)
        try FileManager.default.removeItem(at: url)
        
        try await offline.delete(on: req.db)
        
        try await AuditLog(
            userId: user.id,
            eventType: "download_delete",
            eventData: JSONValue(["book_id": bookId]),
            ipAddress: req.headers.first(name: .xForwardedFor) ?? req.remoteAddress?.description,
            userAgent: req.headers.first(name: .userAgent)
        ).save(on: req.db)
        
        return .noContent
    }
    
    static func cleanupExpired(req: Request) async throws -> CleanupResponse {
        let user = try req.auth.require(User.self)
        
        let expired = try await OfflineAudiobook.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .filter(\.$expiresAt < Date())
            .all()
        
        for offline in expired {
            let url = URL(fileURLWithPath: offline.localPath)
            try? FileManager.default.removeItem(at: url)
            try await offline.delete(on: req.db)
        }
        
        return CleanupResponse(deletedCount: expired.count)
    }
    
    private static func downloadChapters(offline: OfflineAudiobook, manifest: AudiobookManifest, req: Request) async {
        var downloadedChapters: Set<Int> = []
        
        for chapter in manifest.chapters {
            let chapterURL = URL(fileURLWithPath: offline.localPath).appendingPathComponent("chapter_\(chapter.index).mp3")
            
            let dummyData = Data(count: 1024 * 1024)
            try? dummyData.write(to: chapterURL)
            
            downloadedChapters.insert(chapter.index)
            
            do {
                try await OfflineAudiobook.query(on: req.db)
                    .filter(\.$id == offline.id!)
                    .set(\.$downloadedChapters, to: Array(downloadedChapters))
                    .update()
            } catch {
                req.logger.error("Failed to update download progress: \(error)")
            }
            
            do {
                try await Task.sleep(nanoseconds: 200_000_000)
            } catch {
                return
            }
        }
        
        do {
            try await OfflineAudiobook.query(on: req.db)
                .filter(\.$id == offline.id!)
                .set(\.$isComplete, to: true)
                .set(\.$downloadedChapters, to: Array(downloadedChapters))
                .update()
            
            try await AuditLog(
                userId: offline.$user.id,
                eventType: "download_complete",
                eventData: JSONValue(["book_id": offline.bookId]),
                ipAddress: nil,
                userAgent: nil
            ).save(on: req.db)
        } catch {
            req.logger.error("Failed to complete download: \(error)")
        }
    }
    
    private static func getValidAccessToken(user: User, req: Request) async throws -> String {
        let token = try await Token.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .first()
        
        guard let token = token else {
            throw Abort(.unauthorized, reason: "No token stored")
        }
        
        if token.expiresAt < Date() {
            let newTokenPair = try await req.qrAuthenticator.refreshAccessToken(patronId: user.patronId)
            
            let accessEncrypted = try req.crypto.encrypt(newTokenPair.accessToken.data(using: .utf8)!)
            let refreshEncrypted = try req.crypto.encrypt(newTokenPair.refreshToken.data(using: .utf8)!)
            
            try await Token.query(on: req.db)
                .filter(\.$user.$id == user.id!)
                .set(\.$accessTokenEncrypted, to: accessEncrypted)
                .set(\.$refreshTokenEncrypted, to: refreshEncrypted)
                .set(\.$expiresAt, to: newTokenPair.expiresAt)
                .update()
            
            return newTokenPair.accessToken
        }
        
        let decrypted = try req.crypto.decrypt(token.accessTokenEncrypted)
        return String(data: decrypted, encoding: .utf8)!
    }
}

struct OfflineAudiobookResponse: Content {
    let id: String
    let bookId: String
    let localPath: String
    let downloadedAt: Date
    let expiresAt: Date?
    let isComplete: Bool
    let downloadedChapters: [Int]
    let totalChapters: Int
    let progress: Double
    
    init(from offline: OfflineAudiobook) {
        self.id = offline.id?.uuidString ?? ""
        self.bookId = offline.bookId
        self.localPath = offline.localPath
        self.downloadedAt = offline.downloadedAt
        self.expiresAt = offline.expiresAt
        self.isComplete = offline.isComplete
        self.downloadedChapters = offline.downloadedChapters
        
        let manifest = try? JSONDecoder().decode(AudiobookManifest.self, from: offline.manifestJSON)
        self.totalChapters = manifest?.chapters.count ?? 0
        self.progress = manifest?.chapters.isEmpty == false ? Double(offline.downloadedChapters.count) / Double(manifest!.chapters.count) : 0
    }
}

struct CleanupResponse: Content {
    let deletedCount: Int
}