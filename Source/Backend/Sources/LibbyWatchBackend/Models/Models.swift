import Vapor
import Fluent
import Foundation
import LibbyWatchShared

final class User: Model, @unchecked Sendable, Authenticatable {
    static let schema = "users"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "patron_id")
    var patronId: String
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "email")
    var email: String?
    
    @Field(key: "library_card_number")
    var libraryCardNumber: String
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    @Field(key: "access_token_hash")
    var accessTokenHash: String?
    
    @Children(for: \.$user)
    var tokens: [Token]
    
    @Children(for: \.$user)
    var offlineAudiobooks: [OfflineAudiobook]
    
    init() {}
    
    init(id: UUID? = nil, patronId: String, name: String, email: String? = nil, libraryCardNumber: String, accessTokenHash: String? = nil) {
        self.id = id
        self.patronId = patronId
        self.name = name
        self.email = email
        self.libraryCardNumber = libraryCardNumber
        self.accessTokenHash = accessTokenHash
    }
}

final class Token: Model, @unchecked Sendable {
    static let schema = "tokens"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "access_token_encrypted")
    var accessTokenEncrypted: Data
    
    @Field(key: "refresh_token_encrypted")
    var refreshTokenEncrypted: Data
    
    @Field(key: "expires_at")
    var expiresAt: Date
    
    @Field(key: "patron_collection_token_encrypted")
    var patronCollectionTokenEncrypted: Data?
    
    @Field(key: "collection_token_expires_at")
    var collectionTokenExpiresAt: Date?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() {}
    
    init(id: UUID? = nil, userId: UUID, accessTokenEncrypted: Data, refreshTokenEncrypted: Data, expiresAt: Date, patronCollectionTokenEncrypted: Data? = nil, collectionTokenExpiresAt: Date? = nil) {
        self.id = id
        self.$user.id = userId
        self.accessTokenEncrypted = accessTokenEncrypted
        self.refreshTokenEncrypted = refreshTokenEncrypted
        self.expiresAt = expiresAt
        self.patronCollectionTokenEncrypted = patronCollectionTokenEncrypted
        self.collectionTokenExpiresAt = collectionTokenExpiresAt
    }
}

final class OfflineAudiobook: Model, @unchecked Sendable {
    static let schema = "offline_audiobooks"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "book_id")
    var bookId: String
    
    @Field(key: "manifest_json")
    var manifestJSON: Data
    
    @Field(key: "local_path")
    var localPath: String
    
    @Field(key: "downloaded_at")
    var downloadedAt: Date
    
    @Field(key: "expires_at")
    var expiresAt: Date?
    
    @Field(key: "is_complete")
    var isComplete: Bool
    
    @Field(key: "downloaded_chapters")
    var downloadedChapters: [Int]
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() {}
    
    init(id: UUID? = nil, userId: UUID, bookId: String, manifestJSON: Data, localPath: String, downloadedAt: Date, expiresAt: Date?, isComplete: Bool, downloadedChapters: [Int]) {
        self.id = id
        self.$user.id = userId
        self.bookId = bookId
        self.manifestJSON = manifestJSON
        self.localPath = localPath
        self.downloadedAt = downloadedAt
        self.expiresAt = expiresAt
        self.isComplete = isComplete
        self.downloadedChapters = downloadedChapters
    }
}

final class AuditLog: Model, @unchecked Sendable {
    static let schema = "audit_logs"
    
    @ID(key: .id)
    var id: UUID?
    
    @OptionalParent(key: "user_id")
    var user: User?
    
    @Field(key: "event_type")
    var eventType: String
    
    @Field(key: "event_data")
    var eventData: JSONValue?
    
    @Field(key: "ip_address")
    var ipAddress: String?
    
    @Field(key: "user_agent")
    var userAgent: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(id: UUID? = nil, userId: UUID?, eventType: String, eventData: JSONValue? = nil, ipAddress: String? = nil, userAgent: String? = nil) {
        self.id = id
        self.$user.id = userId
        self.eventType = eventType
        self.eventData = eventData
        self.ipAddress = ipAddress
        self.userAgent = userAgent
    }
}

struct JSONValue: Codable, @unchecked Sendable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([JSONValue].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: JSONValue].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let bool as Bool: try container.encode(bool)
        case let int as Int: try container.encode(int)
        case let double as Double: try container.encode(double)
        case let string as String: try container.encode(string)
        case let array as [Any]: try container.encode(array.map { JSONValue($0) })
        case let dict as [String: Any]: try container.encode(dict.mapValues { JSONValue($0) })
        default: try container.encodeNil()
        }
    }
}