import Vapor
import Fluent
import LibbyWatchShared

struct LibraryController {
    static func list(req: Request) async throws -> [LibraryResponse] {
        let libraries = [
            LibraryResponse(id: "nypl", name: "New York Public Library", shortName: "NYPL", websiteURL: "https://nypl.org", overdriveURL: "https://nypl.overdrive.com", isAdvantage: false),
            LibraryResponse(id: "bpl", name: "Boston Public Library", shortName: "BPL", websiteURL: "https://bpl.org", overdriveURL: "https://bpl.overdrive.com", isAdvantage: false),
            LibraryResponse(id: "sfpl", name: "San Francisco Public Library", shortName: "SFPL", websiteURL: "https://sfpl.org", overdriveURL: "https://sfpl.overdrive.com", isAdvantage: false),
        ]
        return libraries
    }
    
    static func get(req: Request) async throws -> LibraryResponse {
        let id = req.parameters.get("id") ?? ""
        let library = LibraryResponse(
            id: id,
            name: "\(id.uppercased()) Public Library",
            shortName: id.uppercased(),
            websiteURL: "https://\(id).org",
            overdriveURL: "https://\(id).overdrive.com",
            isAdvantage: false
        )
        return library
    }
    
    static func search(req: Request) async throws -> SearchResultResponse {
        struct SearchQuery: Content {
            let query: String
            let page: Int?
            let pageSize: Int?
        }
        
        let query = try req.query.decode(SearchQuery.self)
        let user = try req.auth.require(User.self)
        let libraryId = req.parameters.get("id") ?? "nypl"
        
        let client = req.overdriveClient
        let library = Library(id: libraryId, name: "Library", shortName: libraryId.uppercased(), websiteURL: URL(string: "https://example.com")!, overdriveURL: URL(string: "https://example.com")!, isAdvantage: false)
        
        let result = try await client.search(query: query.query, library: library, page: query.page ?? 1, pageSize: query.pageSize ?? 20)
        
        return SearchResultResponse(
            books: result.books.map { BookResponse(from: $0) },
            totalResults: result.totalResults,
            page: result.page,
            pageSize: result.pageSize
        )
    }
    
    static func availability(req: Request) async throws -> AvailabilityResponse {
        struct AvailabilityQuery: Content {
            let ids: String
        }
        
        let query = try req.query.decode(AvailabilityQuery.self)
        let libraryId = req.parameters.get("id") ?? "nypl"
        let bookIds = query.ids.split(separator: ",").map(String.init)
        
        let client = req.overdriveClient
        let library = Library(id: libraryId, name: "Library", shortName: libraryId.uppercased(), websiteURL: URL(string: "https://example.com")!, overdriveURL: URL(string: "https://example.com")!, isAdvantage: false)
        
        let availability = try await client.getAvailability(for: bookIds, library: library)
        
        return AvailabilityResponse(availability: availability.mapValues { AvailabilityResponseItem(from: $0) })
    }
}

struct LibraryResponse: Content {
    let id: String
    let name: String
    let shortName: String
    let websiteURL: String
    let overdriveURL: String
    let isAdvantage: Bool
}

struct BookResponse: Content {
    let id: String
    let title: String
    let author: String
    let narrator: String?
    let coverImageURL: String?
    let format: String
    let availability: AvailabilityResponseItem
    let library: LibraryResponse
    let duration: Double?
    let description: String?
    let subjects: [String]
    
    init(from book: Book) {
        self.id = book.id
        self.title = book.title
        self.author = book.author
        self.narrator = book.narrator
        self.coverImageURL = book.coverImageURL?.absoluteString
        self.format = book.format.rawValue
        self.availability = AvailabilityResponseItem(from: book.availability)
        self.library = LibraryResponse(
            id: book.library.id,
            name: book.library.name,
            shortName: book.library.shortName,
            websiteURL: book.library.websiteURL.absoluteString,
            overdriveURL: book.library.overdriveURL.absoluteString,
            isAdvantage: book.library.isAdvantage
        )
        self.duration = book.duration
        self.description = book.description
        self.subjects = book.subjects
    }
}

struct AvailabilityResponseItem: Content {
    let isOwned: Bool
    let copiesOwned: Int
    let copiesAvailable: Int
    let holdsCount: Int
    let estimatedWaitDays: Int?
    let isAvailable: Bool
    
    init(from availability: Availability) {
        self.isOwned = availability.isOwned
        self.copiesOwned = availability.copiesOwned
        self.copiesAvailable = availability.copiesAvailable
        self.holdsCount = availability.holdsCount
        self.estimatedWaitDays = availability.estimatedWaitDays
        self.isAvailable = availability.isAvailable
    }
}

struct SearchResultResponse: Content {
    let books: [BookResponse]
    let totalResults: Int
    let page: Int
    let pageSize: Int
}

struct AvailabilityResponse: Content {
    let availability: [String: AvailabilityResponseItem]
}