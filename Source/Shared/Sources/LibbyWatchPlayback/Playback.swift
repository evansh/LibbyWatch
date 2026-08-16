import Foundation
import AVFoundation
import LibbyWatchModels

public protocol AudiobookPlayer: Sendable {
    var currentBook: Book? { get }
    var currentChapter: Int { get }
    var playbackState: PlaybackState { get }
    var progress: PlaybackProgress { get }
    var playbackRate: Float { get set }
    var volume: Float { get set }
    
    func load(book: Book, fulfillment: Fulfillment, startChapter: Int, startPosition: TimeInterval) async throws
    func play() async throws
    func pause() async throws
    func seek(to chapter: Int, position: TimeInterval) async throws
    func setPlaybackRate(_ rate: Float) async throws
    func setVolume(_ volume: Float) async throws
    func skipForward(_ seconds: TimeInterval) async throws
    func skipBackward(_ seconds: TimeInterval) async throws
    func stop() async throws
}

public enum PlaybackState: String, Sendable {
    case idle
    case loading
    case playing
    case paused
    case buffering
    case finished
    case failed(Error)
    
    public static func == (lhs: PlaybackState, rhs: PlaybackState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.playing, .playing), (.paused, .paused), (.buffering, .buffering), (.finished, .finished):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

public struct Chapter: Codable, Sendable, Hashable {
    public let index: Int
    public let title: String
    public let startOffset: TimeInterval
    public let duration: TimeInterval
    public let url: URL
    
    public init(index: Int, title: String, startOffset: TimeInterval, duration: TimeInterval, url: URL) {
        self.index = index
        self.title = title
        self.startOffset = startOffset
        self.duration = duration
        self.url = url
    }
}

public struct AudiobookManifest: Codable, Sendable {
    public let bookId: String
    public let chapters: [Chapter]
    public let totalDuration: TimeInterval
    public let drmScheme: DRMScheme?
    public let licenseURL: URL?
    public let expiresAt: Date?
    
    public init(bookId: String, chapters: [Chapter], totalDuration: TimeInterval, drmScheme: DRMScheme? = nil, licenseURL: URL? = nil, expiresAt: Date? = nil) {
        self.bookId = bookId
        self.chapters = chapters
        self.totalDuration = totalDuration
        self.drmScheme = drmScheme
        self.licenseURL = licenseURL
        self.expiresAt = expiresAt
    }
}

public protocol OfflineStorage: Sendable {
    func download(manifest: AudiobookManifest, progress: @escaping @Sendable (Double) -> Void) async throws -> OfflineAudiobook
    func delete(offlineAudiobook: OfflineAudiobook) async throws
    func listDownloaded() async throws -> [OfflineAudiobook]
    func getLocalURL(for chapter: Chapter, in audiobook: OfflineAudiobook) -> URL?
    func getStorageSize() async throws -> Int64
    func cleanupExpired() async throws -> Int
}

public struct OfflineAudiobook: Codable, Sendable, Hashable {
    public let bookId: String
    public let manifest: AudiobookManifest
    public let localPath: String
    public let downloadedAt: Date
    public let expiresAt: Date?
    public var isComplete: Bool
    public var downloadedChapters: Set<Int>
    
    public init(bookId: String, manifest: AudiobookManifest, localPath: String, downloadedAt: Date = Date(), expiresAt: Date? = nil, isComplete: Bool = false, downloadedChapters: Set<Int> = []) {
        self.bookId = bookId
        self.manifest = manifest
        self.localPath = localPath
        self.downloadedAt = downloadedAt
        self.expiresAt = expiresAt
        self.isComplete = isComplete
        self.downloadedChapters = downloadedChapters
    }
    
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
}

public enum PlaybackError: Error, LocalizedError, Sendable {
    case notLoaded
    case invalidManifest
    case drmError(String)
    case networkError(Error)
    case fileNotFound
    case decodingError(Error)
    case licenseExpired
    case storageFull
    case playbackSessionFailed
    
    public var errorDescription: String? {
        switch self {
        case .notLoaded: return "No audiobook loaded"
        case .invalidManifest: return "Invalid audiobook manifest"
        case .drmError(let msg): return "DRM error: \(msg)"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .fileNotFound: return "Audio file not found"
        case .decodingError(let error): return "Decoding error: \(error.localizedDescription)"
        case .licenseExpired: return "License expired"
        case .storageFull: return "Storage full"
        case .playbackSessionFailed: return "Playback session failed"
        }
    }
}

public protocol ProgressSync: Sendable {
    func sync(progress: PlaybackProgress, for bookId: String) async throws
    func fetchProgress(for bookId: String) async throws -> PlaybackProgress?
    func resolveConflict(local: PlaybackProgress, remote: PlaybackProgress) -> PlaybackProgress
}

public struct ProgressConflictResolver: ProgressSync {
    public init() {}
    
    public func sync(progress: PlaybackProgress, for bookId: String) async throws {
        // Backend sync implementation
    }
    
    public func fetchProgress(for bookId: String) async throws -> PlaybackProgress? {
        // Backend fetch implementation
        return nil
    }
    
    public func resolveConflict(local: PlaybackProgress, remote: PlaybackProgress) -> PlaybackProgress {
        // Use the most recent progress
        return local.lastUpdated > remote.lastUpdated ? local : remote
    }
}

public actor PlaybackSessionManager {
    private var currentSession: PlaybackSession?
    private let player: AudiobookPlayer
    private let progressSync: ProgressSync
    private let syncInterval: TimeInterval = 30
    private var syncTask: Task<Void, Never>?
    
    public init(player: AudiobookPlayer, progressSync: ProgressSync) {
        self.player = player
        self.progressSync = progressSync
    }
    
    public func startSession(book: Book, fulfillment: Fulfillment, startChapter: Int = 0, startPosition: TimeInterval = 0) async throws {
        try await player.load(book: book, fulfillment: fulfillment, startChapter: startChapter, startPosition: startPosition)
        try await player.play()
        
        syncTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(syncInterval * 1_000_000_000))
                await syncProgress()
            }
        }
    }
    
    public func pauseSession() async throws {
        try await player.pause()
        await syncProgress()
    }
    
    public func resumeSession() async throws {
        try await player.play()
    }
    
    public func endSession() async throws {
        syncTask?.cancel()
        syncTask = nil
        await syncProgress()
        try await player.stop()
        currentSession = nil
    }
    
    private func syncProgress() async {
        let progress = player.progress
        do {
            try await progressSync.sync(progress: progress, for: player.currentBook?.id ?? "")
        } catch {
            // Log error but don't interrupt playback
        }
    }
    
    public func handleInterruption(_ interruption: AVAudioSession.InterruptionType) async {
        switch interruption {
        case .began:
            try? await player.pause()
        case .ended:
            try? await player.play()
        @unknown default:
            break
        }
    }
    
    public func handleRouteChange(_ change: AVAudioSession.RouteChangeReason) async {
        switch change {
        case .oldDeviceUnavailable:
            try? await player.pause()
        default:
            break
        }
    }
}

public struct PlaybackSession: Sendable {
    public let bookId: String
    public let startedAt: Date
    public var lastProgress: PlaybackProgress
    public var totalPlaybackTime: TimeInterval
    public var interruptions: Int
    
    public init(bookId: String, startedAt: Date = Date(), lastProgress: PlaybackProgress, totalPlaybackTime: TimeInterval = 0, interruptions: Int = 0) {
        self.bookId = bookId
        self.startedAt = startedAt
        self.lastProgress = lastProgress
        self.totalPlaybackTime = totalPlaybackTime
        self.interruptions = interruptions
    }
}