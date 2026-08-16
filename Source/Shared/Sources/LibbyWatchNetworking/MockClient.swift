import Foundation
import LibbyWatchModels

public final class MockOverDriveClient: OverDriveAPIClient, @unchecked Sendable {
    public var shouldFail = false
    public var mockBooks: [Book] = []
    public var mockLoans: [Loan] = []
    public var mockHolds: [Hold] = []
    public var mockSearchResults: SearchResult?
    public var mockFulfillment: Fulfillment?
    public var mockSamples: [Sample] = []
    
    public init() {
        setupMockData()
    }
    
    private func setupMockData() {
        let library = Library(
            id: "nypl",
            name: "New York Public Library",
            shortName: "NYPL",
            websiteURL: URL(string: "https://nypl.org")!,
            overdriveURL: URL(string: "https://nypl.overdrive.com")!,
            isAdvantage: false
        )
        
        let book1 = Book(
            id: "1",
            title: "Project Hail Mary",
            author: "Andy Weir",
            narrator: "Ray Porter",
            coverImageURL: URL(string: "https://example.com/covers/1.jpg"),
            format: .audiobook,
            availability: Availability(isOwned: true, copiesOwned: 10, copiesAvailable: 3, holdsCount: 12),
            library: library,
            duration: 16 * 3600,
            description: "A lone astronaut must save humanity...",
            subjects: ["Science Fiction", "Space"]
        )
        
        let book2 = Book(
            id: "2",
            title: "The Midnight Library",
            author: "Matt Haig",
            narrator: "Carey Mulligan",
            coverImageURL: URL(string: "https://example.com/covers/2.jpg"),
            format: .audiobook,
            availability: Availability(isOwned: true, copiesOwned: 5, copiesAvailable: 0, holdsCount: 25),
            library: library,
            duration: 8 * 3600 + 30 * 60,
            description: "Between life and death there is a library...",
            subjects: ["Fiction", "Philosophy"]
        )
        
        mockBooks = [book1, book2]
        mockSearchResults = SearchResult(books: mockBooks, totalResults: 2, page: 1, pageSize: 20)
        
        let loan = Loan(
            id: "loan-1",
            book: book1,
            expiresAt: Date().addingTimeInterval(14 * 24 * 3600),
            downloadedAt: Date(),
            progress: PlaybackProgress(chapterIndex: 3, positionInChapter: 1200, totalDuration: 16 * 3600),
            fulfillmentURL: URL(string: "https://fulfillment.overdrive.com/loan-1")
        )
        mockLoans = [loan]
        
        let hold = Hold(
            id: "hold-1",
            book: book2,
            placedAt: Date().addingTimeInterval(-5 * 24 * 3600),
            position: 3,
            isReady: false
        )
        mockHolds = [hold]
        
        mockFulfillment = Fulfillment(
            type: .overdriveListen,
            url: URL(string: "https://listen.overdrive.com/loan-1")!,
            expiresAt: Date().addingTimeInterval(3600),
            drmScheme: .none
        )
        
        mockSamples = [
            Sample(type: .audio, url: URL(string: "https://samples.overdrive.com/1.mp3")!, duration: 300),
            Sample(type: .audio, url: URL(string: "https://samples.overdrive.com/2.mp3")!, duration: 240),
        ]
    }
    
    public func search(query: String, library: Library, page: Int, pageSize: Int) async throws -> SearchResult {
        if shouldFail { throw APIError.networkError(NSError(domain: "Mock", code: -1)) }
        return mockSearchResults ?? SearchResult(books: [], totalResults: 0, page: page, pageSize: pageSize)
    }
    
    public func getBook(id: String, library: Library) async throws -> Book {
        if shouldFail { throw APIError.networkError(NSError(domain: "Mock", code: -1)) }
        return mockBooks.first { $0.id == id } ?? mockBooks[0]
    }
    
    public func getAvailability(for bookIds: [String], library: Library) async throws -> [String: Availability] {
        if shouldFail { throw APIError.networkError(NSError(domain: "Mock", code: -1)) }
        var result: [String: Availability] = [:]
        for id in bookIds {
            if let book = mockBooks.first(where: { $0.id == id }) {
                result[id] = book.availability
            }
        }
        return result
    }
    
    public func getLoans(patronToken: String) async throws -> [Loan] {
        if shouldFail { throw APIError.unauthorized }
        return mockLoans
    }
    
    public func getHolds(patronToken: String) async throws -> [Hold] {
        if shouldFail { throw APIError.unauthorized }
        return mockHolds
    }
    
    public func borrow(bookId: String, patronToken: String) async throws -> Loan {
        if shouldFail { throw APIError.networkError(NSError(domain: "Mock", code: -1)) }
        guard let book = mockBooks.first(where: { $0.id == bookId }) else { throw APIError.notFound }
        let loan = Loan(id: "new-loan", book: book, expiresAt: Date().addingTimeInterval(14 * 24 * 3600))
        mockLoans.append(loan)
        return loan
    }
    
    public func placeHold(bookId: String, patronToken: String) async throws -> Hold {
        if shouldFail { throw APIError.networkError(NSError(domain: "Mock", code: -1)) }
        guard let book = mockBooks.first(where: { $0.id == bookId }) else { throw APIError.notFound }
        let hold = Hold(id: "new-hold", book: book, placedAt: Date(), position: mockHolds.count + 1)
        mockHolds.append(hold)
        return hold
    }
    
    public func returnLoan(loanId: String, patronToken: String) async throws {
        if shouldFail { throw APIError.unauthorized }
        mockLoans.removeAll { $0.id == loanId }
    }
    
    public func cancelHold(holdId: String, patronToken: String) async throws {
        if shouldFail { throw APIError.unauthorized }
        mockHolds.removeAll { $0.id == holdId }
    }
    
    public func getFulfillment(loanId: String, patronToken: String) async throws -> Fulfillment {
        if shouldFail { throw APIError.unauthorized }
        return mockFulfillment ?? Fulfillment(type: .overdriveListen, url: URL(string: "https://example.com")!)
    }
    
    public func getSamples(bookId: String, library: Library) async throws -> [Sample] {
        if shouldFail { throw APIError.networkError(NSError(domain: "Mock", code: -1)) }
        return mockSamples
    }
}