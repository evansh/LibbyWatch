import Foundation
import AVFoundation
import LibbyWatchModels
import LibbyWatchNetworking

public final class MockAudiobookPlayer: AudiobookPlayer, @unchecked Sendable {
    public private(set) var currentBook: Book?
    public private(set) var currentChapter: Int = 0
    public private(set) var playbackState: PlaybackState = .idle
    public private(set) var progress: PlaybackProgress = PlaybackProgress(chapterIndex: 0, positionInChapter: 0, totalDuration: 0)
    public var playbackRate: Float = 1.0
    public var volume: Float = 1.0
    
    private var manifest: AudiobookManifest?
    private var progressTimer: Timer?
    private let updateInterval: TimeInterval = 1.0
    
    public init() {}
    
    public func load(book: Book, fulfillment: Fulfillment, startChapter: Int, startPosition: TimeInterval) async throws {
        currentBook = book
        currentChapter = startChapter
        
        let chapters = (0..<15).map { index in
            Chapter(
                index: index,
                title: "Chapter \(index + 1)",
                startOffset: TimeInterval(index) * 3600,
                duration: 3600,
                url: URL(string: "https://example.com/audio/chapter_\(index).mp3")!
            )
        }
        
        manifest = AudiobookManifest(
            bookId: book.id,
            chapters: chapters,
            totalDuration: book.duration ?? 15 * 3600,
            drmScheme: fulfillment.drmScheme,
            licenseURL: nil,
            expiresAt: fulfillment.expiresAt
        )
        
        progress = PlaybackProgress(
            chapterIndex: startChapter,
            positionInChapter: startPosition,
            totalDuration: manifest?.totalDuration ?? book.duration ?? 0
        )
        
        playbackState = .loading
        try await Task.sleep(nanoseconds: 500_000_000)
        playbackState = .paused
    }
    
    public func play() async throws {
        guard manifest != nil else { throw PlaybackError.notLoaded }
        playbackState = .playing
        startProgressTimer()
    }
    
    public func pause() async throws {
        playbackState = .paused
        stopProgressTimer()
    }
    
    public func seek(to chapter: Int, position: TimeInterval) async throws {
        guard let manifest = manifest, chapter < manifest.chapters.count else { return }
        currentChapter = chapter
        progress = PlaybackProgress(
            chapterIndex: chapter,
            positionInChapter: position,
            totalDuration: manifest.totalDuration,
            lastUpdated: Date(),
            playbackRate: playbackRate
        )
    }
    
    public func setPlaybackRate(_ rate: Float) async throws {
        playbackRate = max(0.5, min(3.0, rate))
    }
    
    public func setVolume(_ volume: Float) async throws {
        self.volume = max(0, min(1, volume))
    }
    
    public func skipForward(_ seconds: TimeInterval) async throws {
        var newPosition = progress.positionInChapter + seconds
        var newChapter = progress.chapterIndex
        
        if let manifest = manifest, newChapter < manifest.chapters.count {
            let chapterDuration = manifest.chapters[newChapter].duration
            while newPosition >= chapterDuration && newChapter < manifest.chapters.count - 1 {
                newPosition -= chapterDuration
                newChapter += 1
            }
        }
        
        try await seek(to: newChapter, position: newPosition)
    }
    
    public func skipBackward(_ seconds: TimeInterval) async throws {
        var newPosition = progress.positionInChapter - seconds
        var newChapter = progress.chapterIndex
        
        while newPosition < 0 && newChapter > 0 {
            newChapter -= 1
            if let manifest = manifest {
                newPosition += manifest.chapters[newChapter].duration
            }
        }
        
        newPosition = max(0, newPosition)
        try await seek(to: newChapter, position: newPosition)
    }
    
    public func stop() async throws {
        playbackState = .idle
        stopProgressTimer()
        currentBook = nil
        currentChapter = 0
        manifest = nil
        progress = PlaybackProgress(chapterIndex: 0, positionInChapter: 0, totalDuration: 0)
    }
    
    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func updateProgress() {
        guard playbackState == .playing, let manifest = manifest else { return }
        
        let newPosition = progress.positionInChapter + (updateInterval * TimeInterval(playbackRate))
        var newChapter = progress.chapterIndex
        var position = newPosition
        
        if newChapter < manifest.chapters.count {
            let chapterDuration = manifest.chapters[newChapter].duration
            if position >= chapterDuration {
                position -= chapterDuration
                newChapter += 1
            }
        }
        
        if newChapter >= manifest.chapters.count {
            playbackState = .finished
            stopProgressTimer()
            return
        }
        
        currentChapter = newChapter
        progress = PlaybackProgress(
            chapterIndex: newChapter,
            positionInChapter: position,
            totalDuration: manifest.totalDuration,
            lastUpdated: Date(),
            playbackRate: playbackRate
        )
    }
}

public final class MockOfflineStorage: OfflineStorage, @unchecked Sendable {
    private var downloaded: [OfflineAudiobook] = []
    private let documentsURL: URL
    
    public init(documentsURL: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) {
        self.documentsURL = documentsURL
    }
    
    public func download(manifest: AudiobookManifest, progress: @escaping @Sendable (Double) -> Void) async throws -> OfflineAudiobook {
        let bookPath = documentsURL.appendingPathComponent("Audiobooks/\(manifest.bookId)", isDirectory: true)
        try FileManager.default.createDirectory(at: bookPath, withIntermediateDirectories: true)
        
        var offline = OfflineAudiobook(
            bookId: manifest.bookId,
            manifest: manifest,
            localPath: bookPath.path,
            expiresAt: manifest.expiresAt
        )
        
        for i in 0..<manifest.chapters.count {
            progress(Double(i) / Double(manifest.chapters.count))
            try await Task.sleep(nanoseconds: 100_000_000)
            offline.downloadedChapters.insert(i)
        }
        
        progress(1.0)
        var completeOffline = offline
        completeOffline.isComplete = true
        downloaded.append(completeOffline)
        
        return completeOffline
    }
    
    public func delete(offlineAudiobook: OfflineAudiobook) async throws {
        let url = URL(fileURLWithPath: offlineAudiobook.localPath)
        try FileManager.default.removeItem(at: url)
        downloaded.removeAll { $0.bookId == offlineAudiobook.bookId }
    }
    
    public func listDownloaded() async throws -> [OfflineAudiobook] {
        return downloaded
    }
    
    public func getLocalURL(for chapter: Chapter, in audiobook: OfflineAudiobook) -> URL? {
        guard audiobook.downloadedChapters.contains(chapter.index) else { return nil }
        return URL(fileURLWithPath: audiobook.localPath).appendingPathComponent("chapter_\(chapter.index).mp3")
    }
    
    public func getStorageSize() async throws -> Int64 {
        var size: Int64 = 0
        for offline in downloaded {
            let url = URL(fileURLWithPath: offline.localPath)
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey])
            for fileURL in contents {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    size += Int64(fileSize)
                }
            }
        }
        return size
    }
    
    public func cleanupExpired() async throws -> Int {
        let expired = downloaded.filter { $0.isExpired }
        for offline in expired {
            try await delete(offlineAudiobook: offline)
        }
        return expired.count
    }
}