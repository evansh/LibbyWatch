import Vapor
import LibbyWatchBackend

@main
enum App {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        
        let app = Application(env)
        defer { app.shutdown() }
        
        try await configure(app)
        try await app.execute()
    }
}

extension Application {
    var overdriveConfig: OverdriveConfig {
        get { storage[OverdriveConfigKey.self] ?? OverdriveConfig() }
        set { storage[OverdriveConfigKey.self] = newValue }
    }
    
    var overdriveClient: OverDriveClient {
        get { storage[OverDriveClientKey.self] ?? createOverDriveClient() }
        set { storage[OverDriveClientKey.self] = newValue }
    }
    
    var crypto: CryptoService {
        get { storage[CryptoServiceKey.self] ?? createCryptoService() }
        set { storage[CryptoServiceKey.self] = newValue }
    }
    
    var jwt: JWTService {
        get { storage[JWTServiceKey.self] ?? createJWTService() }
        set { storage[JWTServiceKey.self] = newValue }
    }
    
    var offlineStoragePath: String {
        get { storage[OfflineStoragePathKey.self] ?? "/tmp/libbywatch_offline" }
        set { storage[OfflineStoragePathKey.self] = newValue }
    }
    
    private func createOverDriveClient() -> OverDriveClient {
        let config = overdriveConfig
        return OverDriveClient(configuration: APIConfiguration(
            baseURL: config.baseURL,
            clientId: config.clientId,
            clientSecret: config.clientSecret,
            userAgent: config.userAgent
        ))
    }
    
    private func createCryptoService() -> CryptoService {
        let key = SymmetricKey(size: .bits256)
        return CryptoService(key: key)
    }
    
    private func createJWTService() -> JWTService {
        let key = SymmetricKey(size: .bits256)
        return JWTService(key: key)
    }
}

struct OverdriveConfigKey: StorageKey {
    typealias Value = OverdriveConfig
}

struct OverDriveClientKey: StorageKey {
    typealias Value = OverDriveClient
}

struct CryptoServiceKey: StorageKey {
    typealias Value = CryptoService
}

struct JWTServiceKey: StorageKey {
    typealias Value = JWTService
}

struct OfflineStoragePathKey: StorageKey {
    typealias Value = String
}

struct OverdriveConfig {
    var baseURL: URL = URL(string: "https://api.overdrive.com")!
    var clientId: String = ""
    var clientSecret: String = ""
    var redirectURL: String = "https://app.libbywatch.example.com/callback"
    var userAgent: String = "LibbyWatch/1.0 (iOS; watchOS) Vapor"
}

struct CryptoService {
    let key: SymmetricKey
    
    func encrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined!
    }
    
    func decrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }
}

struct JWTService {
    let key: SymmetricKey
    var signers: JWTSigners {
        var signers = JWTSigners()
        signers.use(.hs256(key: key))
        return signers
    }
}

import Crypto
import JWTKit