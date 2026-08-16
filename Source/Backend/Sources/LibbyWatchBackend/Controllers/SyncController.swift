import Vapor
import Fluent
import LibbyWatchShared

struct SyncController {
    static func syncProgress(req: Request) async throws -> SyncResponse {
        let user = try req.auth.require(User.self)
        
        struct SyncRequest: Content {
            let bookId: String
            let progress: PlaybackProgressRequest
        }
        
        let request = try req.content.decode(SyncRequest.self)
        let progress = PlaybackProgress(
            chapterIndex: request.progress.chapterIndex,
            positionInChapter: request.progress.positionInChapter,
            totalDuration: request.progress.totalDuration,
            playbackRate: request.progress.playbackRate
        )
        
        try await AuditLog(
            userId: user.id,
            eventType: "progress_sync",
            eventData: JSONValue([
                "book_id": request.bookId,
                "chapter": request.progress.chapterIndex,
                "position": request.progress.positionInChapter
            ]),
            ipAddress: req.headers.first(name: .xForwardedFor) ?? req.remoteAddress?.description,
            userAgent: req.headers.first(name: .userAgent)
        ).save(on: req.db)
        
        return SyncResponse(synced: true, serverProgress: nil)
    }
    
    static func getProgress(req: Request) async throws -> PlaybackProgressResponse {
        let user = try req.auth.require(User.self)
        let bookId = req.parameters.get("bookId") ?? ""
        
        guard let offline = try await OfflineAudiobook.query(on: req.db)
            .filter(\.$user.$id == user.id!)
            .filter(\.$bookId == bookId)
            .first() else {
            throw Abort(.notFound, reason: "No offline audiobook found")
        }
        
        let manifest = try JSONDecoder().decode(AudiobookManifest.self, from: offline.manifestJSON)
        let progress = PlaybackProgress(
            chapterIndex: offline.downloadedChapters.max() ?? 0,
            positionInChapter: 0,
            totalDuration: manifest.totalDuration
        )
        
        return PlaybackProgressResponse(from: progress)
    }
}

struct SyncResponse: Content {
    let synced: Bool
    let serverProgress: PlaybackProgressResponse?
}

struct PlaybackProgressRequest: Content {
    let chapterIndex: Int
    let positionInChapter: Double
    let totalDuration: Double
    let playbackRate: Float
}