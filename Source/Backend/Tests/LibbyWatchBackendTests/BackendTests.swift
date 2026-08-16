import XCTest
import VaporTesting
@testable import LibbyWatchBackend
import LibbyWatchShared

final class AppTests: XCTestCase {
    func testHealthEndpoint() async throws {
        try await withApp { app in
            try await app.testing().test(.GET, "health") { res in
                XCTAssertEqual(res.status, .ok)
                let body = try res.content.decode([String: String].self)
                XCTAssertEqual(body["status"], "ok")
            }
        }
    }
    
    func testQRInitiate() async throws {
        try await withApp { app in
            try await app.testing().test(.POST, "api/v1/auth/qr-initiate") { res in
                XCTAssertEqual(res.status, .ok)
                let body = try res.content.decode(QRInitResponse.self)
                XCTAssertFalse(body.authorizationURL.isEmpty)
                XCTAssertFalse(body.state.isEmpty)
            }
        }
    }
}

final class AuthTests: XCTestCase {
    func testJWTPayload() throws {
        let payload = JWTPayload(
            sub: "user-123",
            patronId: "patron-456",
            exp: ExpirationClaim(value: Date().addingTimeInterval(3600)),
            iat: IssuedAtClaim(value: Date())
        )
        
        XCTAssertEqual(payload.sub, "user-123")
        XCTAssertEqual(payload.patronId, "patron-456")
    }
    
    func testTokenPairExpiration() {
        let expired = TokenPair(accessToken: "a", refreshToken: "r", expiresIn: -100)
        XCTAssertTrue(expired.isExpired)
        
        let valid = TokenPair(accessToken: "a", refreshToken: "r", expiresIn: 3600)
        XCTAssertFalse(valid.isExpired)
    }
}

final class ModelTests: XCTestCase {
    func testUserCreation() throws {
        let user = User(patronId: "patron-1", name: "Test User", libraryCardNumber: "12345")
        XCTAssertEqual(user.patronId, "patron-1")
        XCTAssertEqual(user.name, "Test User")
    }
    
    func testTokenCreation() throws {
        let userId = UUID()
        let token = Token(
            userId: userId,
            accessTokenEncrypted: Data(),
            refreshTokenEncrypted: Data(),
            expiresAt: Date().addingTimeInterval(3600)
        )
        XCTAssertEqual(token.$user.id, userId)
    }
    
    func testOfflineAudiobookCreation() throws {
        let userId = UUID()
        let manifest = AudiobookManifest(
            bookId: "1",
            chapters: [],
            totalDuration: 3600
        )
        let manifestData = try JSONEncoder().encode(manifest)
        
        let offline = OfflineAudiobook(
            userId: userId,
            bookId: "1",
            manifestJSON: manifestData,
            localPath: "/tmp/test",
            downloadedAt: Date(),
            expiresAt: Date().addingTimeInterval(86400),
            isComplete: false,
            downloadedChapters: []
        )
        
        XCTAssertEqual(offline.bookId, "1")
        XCTAssertFalse(offline.isComplete)
    }
}

final class LibraryControllerTests: XCTestCase {
    func testListLibraries() async throws {
        try await withApp { app in
            let req = Request(application: app, on: app.eventLoopGroup.next())
            req.auth.login(User(patronId: "test", name: "Test", libraryCardNumber: "123"))
            
            let libraries = try await LibraryController.list(req: req)
            XCTAssertEqual(libraries.count, 3)
            XCTAssertEqual(libraries[0].id, "nypl")
        }
    }
}

final class CryptoServiceTests: XCTestCase {
    func testEncryptDecrypt() throws {
        let service = CryptoService(key: SymmetricKey(size: .bits256))
        let original = "test data".data(using: .utf8)!
        
        let encrypted = try service.encrypt(original)
        let decrypted = try service.decrypt(encrypted)
        
        XCTAssertEqual(original, decrypted)
    }
}

extension Application {
    static func testing() -> Application {
        let app = Application(.testing)
        return app
    }
}