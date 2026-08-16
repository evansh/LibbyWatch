import XCTest
import LibbyWatchShared
import LibbyWatchModels

final class ModelsTests: XCTestCase {
    func testBookCreation() {
        let library = Library(
            id: "nypl",
            name: "New York Public Library",
            shortName: "NYPL",
            websiteURL: URL(string: "https://nypl.org")!,
            overdriveURL: URL(string: "https://nypl.overdrive.com")!,
            isAdvantage: false
        )
        
        let book = Book(
            id: "1",
            title: "Test Book",
            author: "Test Author",
            narrator: "Test Narrator",
            coverImageURL: URL(string: "https://example.com/cover.jpg"),
            format: .audiobook,
            availability: Availability(isOwned: true, copiesOwned: 5, copiesAvailable: 2, holdsCount: 10),
            library: library,
            duration: 36000,
            subjects: ["Fiction", "Sci-Fi"]
        )
        
        XCTAssertEqual(book.id, "1")
        XCTAssertEqual(book.title, "Test Book")
        XCTAssertEqual(book.author, "Test Author")
        XCTAssertEqual(book.format, .audiobook)
        XCTAssertEqual(book.library.id, "nypl")
    }
    
    func testLoanExpiration() {
        let library = Library(
            id: "nypl",
            name: "NYPL",
            shortName: "NYPL",
            websiteURL: URL(string: "https://nypl.org")!,
            overdriveURL: URL(string: "https://nypl.overdrive.com")!,
            isAdvantage: false
        )
        
        let book = Book(
            id: "1", title: "Test", author: "Author", format: .audiobook,
            availability: Availability(isOwned: true, copiesOwned: 1, copiesAvailable: 1, holdsCount: 0),
            library: library
        )
        
        let expiredLoan = Loan(
            id: "1", book: book, expiresAt: Date().addingTimeInterval(-3600)
        )
        XCTAssertTrue(expiredLoan.isExpired)
        
        let activeLoan = Loan(
            id: "2", book: book, expiresAt: Date().addingTimeInterval(86400)
        )
        XCTAssertFalse(activeLoan.isExpired)
        XCTAssertGreaterThan(activeLoan.daysRemaining, 0)
    }
    
    func testPlaybackProgress() {
        let progress = PlaybackProgress(
            chapterIndex: 5,
            positionInChapter: 1800,
            totalDuration: 36000
        )
        
        XCTAssertEqual(progress.chapterIndex, 5)
        XCTAssertEqual(progress.positionInChapter, 1800)
        XCTAssertGreaterThan(progress.overallProgress, 0)
        XCTAssertLessThanOrEqual(progress.overallProgress, 1.0)
    }
    
    func testAvailability() {
        let available = Availability(isOwned: true, copiesOwned: 10, copiesAvailable: 5, holdsCount: 3)
        XCTAssertTrue(available.isAvailable)
        
        let unavailable = Availability(isOwned: true, copiesOwned: 5, copiesAvailable: 0, holdsCount: 10)
        XCTAssertFalse(unavailable.isAvailable)
    }
    
    func testFormatDecoding() throws {
        let json = "\"audiobook-overdrive\""
        let format = try JSONDecoder().decode(Format.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(format, .audiobook)
        
        let unknownJson = "\"unknown-format\""
        let unknownFormat = try JSONDecoder().decode(Format.self, from: unknownJson.data(using: .utf8)!)
        XCTAssertEqual(unknownFormat, .unknown)
    }
    
    func testSearchResult() {
        let library = Library(
            id: "nypl", name: "NYPL", shortName: "NYPL",
            websiteURL: URL(string: "https://nypl.org")!,
            overdriveURL: URL(string: "https://nypl.overdrive.com")!,
            isAdvantage: false
        )
        
        let books = (1...3).map { i in
            Book(id: "\(i)", title: "Book \(i)", author: "Author", format: .audiobook,
                 availability: Availability(isOwned: true, copiesOwned: 1, copiesAvailable: 1, holdsCount: 0),
                 library: library)
        }
        
        let result = SearchResult(books: books, totalResults: 100, page: 1, pageSize: 20)
        
        XCTAssertEqual(result.books.count, 3)
        XCTAssertEqual(result.totalResults, 100)
        XCTAssertEqual(result.page, 1)
    }
}

final class NetworkingTests: XCTestCase {
    var mockClient: MockOverDriveClient!
    
    override func setUp() {
        mockClient = MockOverDriveClient()
    }
    
    func testSearchReturnsResults() async throws {
        let library = Library(
            id: "nypl", name: "NYPL", shortName: "NYPL",
            websiteURL: URL(string: "https://nypl.org")!,
            overdriveURL: URL(string: "https://nypl.overdrive.com")!,
            isAdvantage: false
        )
        
        let result = try await mockClient.search(query: "test", library: library, page: 1, pageSize: 20)
        
        XCTAssertEqual(result.books.count, 2)
        XCTAssertEqual(result.totalResults, 2)
    }
    
    func testGetLoansRequiresToken() async throws {
        mockClient.shouldFail = true
        
        do {
            _ = try await mockClient.getLoans(patronToken: "invalid")
            XCTFail("Should have thrown unauthorized")
        } catch APIError.unauthorized {
            // Expected
        }
    }
    
    func testBorrowCreatesLoan() async throws {
        let initialCount = mockClient.mockLoans.count
        let loan = try await mockClient.borrow(bookId: "1", patronToken: "valid")
        
        XCTAssertEqual(mockClient.mockLoans.count, initialCount + 1)
        XCTAssertEqual(loan.book.id, "1")
    }
    
    func testReturnLoanRemovesLoan() async throws {
        let loanId = mockClient.mockLoans[0].id
        try await mockClient.returnLoan(loanId: loanId, patronToken: "valid")
        
        XCTAssertFalse(mockClient.mockLoans.contains { $0.id == loanId })
    }
}

final class PlaybackTests: XCTestCase {
    var mockPlayer: MockAudiobookPlayer!
    
    override func setUp() {
        mockPlayer = MockAudiobookPlayer()
    }
    
    func testLoadBook() async throws {
        let library = Library(
            id: "nypl", name: "NYPL", shortName: "NYPL",
            websiteURL: URL(string: "https://nypl.org")!,
            overdriveURL: URL(string: "https://nypl.overdrive.com")!,
            isAdvantage: false
        )
        
        let book = Book(
            id: "1", title: "Test", author: "Author", format: .audiobook,
            availability: Availability(isOwned: true, copiesOwned: 1, copiesAvailable: 1, holdsCount: 0),
            library: library, duration: 36000
        )
        
        let fulfillment = Fulfillment(
            type: .overdriveListen,
            url: URL(string: "https://example.com")!,
            drmScheme: .none
        )
        
        try await mockPlayer.load(book: book, fulfillment: fulfillment, startChapter: 0, startPosition: 0)
        
        XCTAssertEqual(mockPlayer.currentBook?.id, "1")
        XCTAssertEqual(mockPlayer.playbackState, .paused)
    }
    
    func testPlayPause() async throws {
        let library = Library(
            id: "nypl", name: "NYPL", shortName: "NYPL",
            websiteURL: URL(string: "https://nypl.org")!,
            overdriveURL: URL(string:// "https://nypl.overdrive.com")!,
            isAdvantage: false
        )
        
        let book = Book(
            id: "1", title: "Test", author: "Author", format: .audiobook,
            availability: Availability(isOwned: true, copiesOwned: 1, copiesAvailable: 1, holdsCount: 0),
            library: library, duration: 36000
        )
        
        let fulfillment = Fulfillment(type: .overdriveListen, url: URL(string: "https://example.com")!)
        
        try await mockPlayer.load(book: book, fulfillment: fulfillment, startChapter: 0, startPosition: 0)
        try await mockPlayer.play()
        
        XCTAssertEqual(mockPlayer.playbackState, .playing)
        
        try await mockPlayer.pause()
        XCTAssertEqual(mockPlayer.playbackState, .paused)
    }
    
    func testSeek() async throws {
        let library = Library(
            id: "nypl", name: "NYPL", shortName: "NYPL",
            websiteURL: URL(string: "https://nypl.org")!,
            overdriveURL: URL(string: "https://nypl.overdrive.com")!,
            isAdvantage: false
        )
        
        let book = Book(
            id: "1", title: "Test", author: "Author", format: .audiobook,
            availability: Availability(isOwned: true, copiesOwned: 1, copiesAvailable: 1, holdsCount: 0),
            library: library, duration: 36000
        )
        
        let fulfillment = Fulfillment(type: .overdriveListen, url: URL(string: "https://example.com")!)
        
        try await mockPlayer.load(book: book, fulfillment: fulfillment, startChapter: 0, startPosition: 0)
        try await mockPlayer.seek(to: 3, position: 1200)
        
        XCTAssertEqual(mockPlayer.currentChapter, 3)
        XCTAssertEqual(mockPlayer.progress.positionInChapter, 1200)
    }
    
    func testPlaybackRate() async throws {
        let library = Library(
            id: "nypl", name: "NYPL", shortName: "NYPL",
            websiteURL: URL(string: "https://nypl.org")!,
            overdriveURL: URL(string: "https://nypl.overdrive.com")!,
            isAdvantage: false
        )
        
        let book = Book(
            id: "1", title: "Test", author: "Author", format: .audiobook,
            availability: Availability(isOwned: true, copiesOwned: 1, copiesAvailable: 1, holdsCount: 0),
            library: library, duration: 36000
        )
        
        let fulfillment = Fulfillment(type: .overdriveListen, url: URL(string: "https://example.com")!)
        
        try await mockPlayer.load(book: book, fulfillment: fulfillment, startChapter: 0, startPosition: 0)
        try await mockPlayer.setPlaybackRate(1.5)
        
        XCTAssertEqual(mockPlayer.playbackRate, 1.5)
        
        try await mockPlayer.setPlaybackRate(3.5)
        XCTAssertEqual(mockPlayer.playbackRate, 3.0)
        
        try await mockPlayer.setPlaybackRate(0.25)
        XCTAssertEqual(mockPlayer.playbackRate, 0.5)
    }
}

final class OfflineStorageTests: XCTestCase {
    var mockStorage: MockOfflineStorage!
    var tempDir: URL!
    
    override func setUp() {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        mockStorage = MockOfflineStorage(documentsURL: tempDir)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    func testDownloadAndList() async throws {
        let manifest = AudiobookManifest(
            bookId: "1",
            chapters: [
                Chapter(index: 0, title: "Ch 1", startOffset: 0, duration: 1800, url: URL(string: "https://example.com/1.mp3")!),
                Chapter(index: 1, title: "Ch 2", startOffset: 1800, duration: 1800, url: URL(string: "https://example.com/2.mp3")!),
            ],
            totalDuration: 3600
        )
        
        var progressValues: [Double] = []
        let offline = try await mockStorage.download(manifest: manifest) { progress in
            progressValues.append(progress)
        }
        
        XCTAssertTrue(offline.isComplete)
        XCTAssertEqual(offline.downloadedChapters.count, 2)
        XCTAssertEqual(progressValues.last, 1.0)
        
        let downloaded = try await mockStorage.listDownloaded()
        XCTAssertEqual(downloaded.count, 1)
    }
    
    func testDeleteOfflineAudiobook() async throws {
        let manifest = AudiobookManifest(
            bookId: "1",
            chapters: [Chapter(index: 0, title: "Ch 1", startOffset: 0, duration: 1800, url: URL(string: "https://example.com/1.mp3")!)],
            totalDuration: 1800
        )
        
        let offline = try await mockStorage.download(manifest: manifest) { _ in }
        try await mockStorage.delete(offlineAudiobook: offline)
        
        let downloaded = try await mockStorage.listDownloaded()
        XCTAssertEqual(downloaded.count, 0)
    }
    
    func testGetLocalURL() async throws {
        let manifest = AudiobookManifest(
            bookId: "1",
            chapters: [Chapter(index: 0, title: "Ch 1", startOffset: 0, duration: 1800, url: URL(string: "https://example.com/1.mp3")!)],
            totalDuration: 1800
        )
        
        let offline = try await mockStorage.download(manifest: manifest) { _ in }
        let chapter = manifest.chapters[0]
        
        let url = mockStorage.getLocalURL(for: chapter, in: offline)
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.path.contains("chapter_0.mp3") == true)
        
        let missingChapter = Chapter(index: 1, title: "Ch 2", startOffset: 1800, duration: 1800, url: URL(string: "https://example.com/2.mp3")!)
        let missingURL = mockStorage.getLocalURL(for: missingChapter, in: offline)
        XCTAssertNil(missingURL)
    }
}

final class AuthTests: XCTestCase {
    func testQRCodeAuthRequest() {
        let request = QRCodeAuthRequest(
            clientId: "test-client",
            redirectURL: "https://app.example.com/callback",
            scope: "profile loans holds",
            state: "test-state"
        )
        
        XCTAssertNotNil(request.authorizationURL)
        XCTAssertTrue(request.authorizationURL?.absoluteString.contains("client_id=test-client") == true)
        XCTAssertTrue(request.authorizationURL?.absoluteString.contains("redirect_uri=https%3A%2F%2Fapp.example.com%2Fcallback") == true)
    }
    
    func testTokenPairExpiration() {
        let tokenPair = TokenPair(accessToken: "access", refreshToken: "refresh", expiresIn: -100)
        XCTAssertTrue(tokenPair.isExpired)
        
        let validTokenPair = TokenPair(accessToken: "access", refreshToken: "refresh", expiresIn: 3600)
        XCTAssertFalse(validTokenPair.isExpired)
    }
    
    func testOfflineAudiobookExpiration() {
        let manifest = AudiobookManifest(
            bookId: "1",
            chapters: [],
            totalDuration: 3600,
            expiresAt: Date().addingTimeInterval(-3600)
        )
        
        let offline = OfflineAudiobook(
            bookId: "1",
            manifest: manifest,
            localPath: "/tmp/test",
            expiresAt: Date().addingTimeInterval(-3600)
        )
        
        XCTAssertTrue(offline.isExpired)
        
        let validManifest = AudiobookManifest(
            bookId: "2",
            chapters: [],
            totalDuration: 3600,
            expiresAt: Date().addingTimeInterval(86400)
        )
        
        let validOffline = OfflineAudiobook(
            bookId: "2",
            manifest: validManifest,
            localPath: "/tmp/test2",
            expiresAt: Date().addingTimeInterval(86400)
        )
        
        XCTAssertFalse(validOffline.isExpired)
    }
}

final class ProgressConflictResolverTests: XCTestCase {
    let resolver = ProgressConflictResolver()
    
    func testResolveConflictUsesMostRecent() {
        let older = PlaybackProgress(chapterIndex: 5, positionInChapter: 1000, totalDuration: 36000, lastUpdated: Date().addingTimeInterval(-3600))
        let newer = PlaybackProgress(chapterIndex: 3, positionInChapter: 500, totalDuration: 36000, lastUpdated: Date())
        
        let resolved = resolver.resolveConflict(local: newer, remote: older)
        XCTAssertEqual(resolved.chapterIndex, 3)
        
        let resolved2 = resolver.resolveConflict(local: older, remote: newer)
        XCTAssertEqual(resolved2.chapterIndex, 3)
    }
}