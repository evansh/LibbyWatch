import Vapor
import Fluent
import FluentSQLiteDriver
import JWTKit
import LibbyWatchShared

public func configure(_ app: Application) async throws {
    app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    
    app.migrations.add(CreateUser())
    app.migrations.add(CreateToken())
    app.migrations.add(CreateOfflineAudiobook())
    app.migrations.add(CreateAuditLog())
    
    try await app.autoMigrate()
    
    app.routes.defaultMaxBodySize = "10mb"
    
    try routes(app)
}

struct CreateUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .id()
            .field("patron_id", .string, .required)
            .field("name", .string, .required)
            .field("email", .string)
            .field("library_card_number", .string, .required)
            .field("created_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "patron_id")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("users").delete()
    }
}

struct CreateToken: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("tokens")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("access_token_encrypted", .data, .required)
            .field("refresh_token_encrypted", .data, .required)
            .field("expires_at", .datetime, .required)
            .field("patron_collection_token_encrypted", .data)
            .field("collection_token_expires_at", .datetime)
            .field("created_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("tokens").delete()
    }
}

struct CreateOfflineAudiobook: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("offline_audiobooks")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("book_id", .string, .required)
            .field("manifest_json", .data, .required)
            .field("local_path", .string, .required)
            .field("downloaded_at", .datetime, .required)
            .field("expires_at", .datetime)
            .field("is_complete", .bool, .required)
            .field("downloaded_chapters", .array(of: .int), .required)
            .field("created_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("offline_audiobooks").delete()
    }
}

struct CreateAuditLog: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("audit_logs")
            .id()
            .field("user_id", .uuid, .references("users", "id", onDelete: .setNull))
            .field("event_type", .string, .required)
            .field("event_data", .json)
            .field("ip_address", .string)
            .field("user_agent", .string)
            .field("created_at", .datetime, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("audit_logs").delete()
    }
}