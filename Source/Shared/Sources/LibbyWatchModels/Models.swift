import Foundation

public struct Library: Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let shortName: String
    public let websiteURL: URL
    public let overdriveURL: URL
    public let isAdvantage: Bool
    
    public init(id: String, name: String, shortName: String, websiteURL: URL, overdriveURL: URL, isAdvantage: Bool) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.websiteURL = websiteURL
        self.overdriveURL = overdriveURL
        self.isAdvantage = isAdvantage
    }
}

public struct Book: Codable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let author: String
    public let narrator: String?
    public let coverImageURL: URL?
    public let format: Format
    public let availability: Availability
    public let library: Library
    public let isbn: String?
    public let publisher: String?
    public let publishedDate: Date?
    public let series: String?
    public let seriesPosition: Int?
    public let duration: TimeInterval?
    public let description: String?
    public let subjects: [String]
    
    public init(
        id: String,
        title: String,
        author: String,
        narrator: String? = nil,
        coverImageURL: URL? = nil,
        format: Format,
        availability: Availability,
        library: Library,
        isbn: String? = nil,
        publisher: String? = nil,
        publishedDate: Date? = nil,
        series: String? = nil,
        seriesPosition: Int? = nil,
        duration: TimeInterval? = nil,
        description: String? = nil,
        subjects: [String] = []
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.narrator = narrator
        self.coverImageURL = coverImageURL
        self.format = format
        self.availability = availability
        self.library = library
        self.isbn = isbn
        self.publisher = publisher
        self.publishedDate = publishedDate
        self.series = series
        self.seriesPosition = seriesPosition
        self.duration = duration
        self.description = description
        self.subjects = subjects
    }
}

public enum Format: String, Codable, Sendable {
    case audiobook = "audiobook-overdrive"
    case ebook = "ebook-overdrive"
    case magazine = "magazine-overdrive"
    case unknown
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        self = Format(rawValue: string) ?? .unknown
    }
}

public struct Availability: Codable, Sendable, Hashable {
    public let isOwned: Bool
    public let copiesOwned: Int
    public let copiesAvailable: Int
    public let holdsCount: Int
    public let estimatedWaitDays: Int?
    public let isAvailable: Bool
    
    public init(isOwned: Bool, copiesOwned: Int, copiesAvailable: Int, holdsCount: Int, estimatedWaitDays: Int? = nil) {
        self.isOwned = isOwned
        self.copiesOwned = copiesOwned
        self.copiesAvailable = copiesAvailable
        self.holdsCount = holdsCount
        self.estimatedWaitDays = estimatedWaitDays
        self.isAvailable = copiesAvailable > 0
    }
}

public struct Loan: Codable, Sendable, Hashable {
    public let id: String
    public let book: Book
    public let expiresAt: Date
    public let downloadedAt: Date?
    public let progress: PlaybackProgress?
    public let isReturned: Bool
    public let fulfillmentURL: URL?
    
    public init(
        id: String,
        book: Book,
        expiresAt: Date,
        downloadedAt: Date? = nil,
        progress: PlaybackProgress? = nil,
        isReturned: Bool = false,
        fulfillmentURL: URL? = nil
    ) {
        self.id = id
        self.book = book
        self.expiresAt = expiresAt
        self.downloadedAt = downloadedAt
        self.progress = progress
        self.isReturned = isReturned
        self.fulfillmentURL = fulfillmentURL
    }
    
    public var isExpired: Bool {
        Date() > expiresAt
    }
    
    public var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: expiresAt).day ?? 0
    }
}

public struct Hold: Codable, Sendable, Hashable {
    public let id: String
    public let book: Book
    public let placedAt: Date
    public let position: Int
    public let isReady: Bool
    public let readyAt: Date?
    public let expiresAt: Date?
    
    public init(id: String, book: Book, placedAt: Date, position: Int, isReady: Bool = false, readyAt: Date? = nil, expiresAt: Date? = nil) {
        self.id = id
        self.book = book
        self.placedAt = placedAt
        self.position = position
        self.isReady = isReady
        self.readyAt = readyAt
        self.expiresAt = expiresAt
    }
}

public struct PlaybackProgress: Codable, Sendable, Hashable {
    public let chapterIndex: Int
    public let positionInChapter: TimeInterval
    public let totalDuration: TimeInterval
    public let lastUpdated: Date
    public let playbackRate: Float
    
    public init(chapterIndex: Int, positionInChapter: TimeInterval, totalDuration: TimeInterval, lastUpdated: Date = Date(), playbackRate: Float = 1.0) {
        self.chapterIndex = chapterIndex
        self.positionInChapter = positionInChapter
        self.totalDuration = totalDuration
        self.lastUpdated = lastUpdated
        self.playbackRate = playbackRate
    }
    
    public var overallProgress: Double {
        guard totalDuration > 0 else { return 0 }
        let elapsed = positionInChapter + (Double(chapterIndex) * (totalDuration / Double(max(chapterIndex + 1, 1))))
        return min(elapsed / totalDuration, 1.0)
    }
}

public struct Patron: Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let email: String?
    public let libraryCardNumber: String
    public let libraries: [Library]
    public let loanLimit: Int
    public let holdLimit: Int
    
    public init(id: String, name: String, email: String? = nil, libraryCardNumber: String, libraries: [Library], loanLimit: Int, holdLimit: Int) {
        self.id = id
        self.name = name
        self.email = email
        self.libraryCardNumber = libraryCardNumber
        self.libraries = libraries
        self.loanLimit = loanLimit
        self.holdLimit = holdLimit
    }
}

public struct SearchResult: Codable, Sendable {
    public let books: [Book]
    public let totalResults: Int
    public let page: Int
    public let pageSize: Int
    public let facets: [Facet]
    
    public init(books: [Book], totalResults: Int, page: Int, pageSize: Int, facets: [Facet] = []) {
        self.books = books
        self.totalResults = totalResults
        self.page = page
        self.pageSize = pageSize
        self.facets = facets
    }
}

public struct Facet: Codable, Sendable, Hashable {
    public let name: String
    public let values: [FacetValue]
    
    public init(name: String, values: [FacetValue]) {
        self.name = name
        self.values = values
    }
}

public struct FacetValue: Codable, Sendable, Hashable {
    public let value: String
    public let count: Int
    
    public init(value: String, count: Int) {
        self.value = value
        self.count = count
    }
}