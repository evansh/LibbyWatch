import Vapor
import Fluent
import Crypto
import JWTKit
import LibbyWatchShared
import LibbyWatchModels
import LibbyWatchNetworking
import LibbyWatchAuth

struct OverdriveConfigKey: StorageKey {
    typealias Value = OverdriveConfig
}

struct OverDriveClientKey: StorageKey {
    typealias Value = OverDriveClient
}

struct CryptoServiceKey: StorageKey {
    typealias Value = CryptoService
}

struct QRCodeAuthenticatorKey: StorageKey {
    typealias Value = QRCodeAuthenticator
}

struct JWTSignerKey: StorageKey {
    typealias Value = any JWTAlgorithm
}

struct OfflineStoragePathKey: StorageKey {
    typealias Value = URL
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

extension Application {
    var overdriveConfig: OverdriveConfig {
        get { storage[OverdriveConfigKey.self] ?? OverdriveConfig() }
        set { storage[OverdriveConfigKey.self] = newValue }
    }
    
    var overdriveClient: OverDriveClient {
        get { storage[OverDriveClientKey.self] ?? createOverDriveClient() }
        set { storage[OverDriveClientKey.self] = newValue }
    }
    
    var qrAuthenticator: QRCodeAuthenticator {
        get { storage[QRCodeAuthenticatorKey.self] ?? createQRCodeAuthenticator() }
        set { storage[QRCodeAuthenticatorKey.self] = newValue }
    }
    
    var crypto: CryptoService {
        get { storage[CryptoServiceKey.self] ?? createCryptoService() }
        set { storage[CryptoServiceKey.self] = newValue }
    }
    
    var jwtSigner: any JWTAlgorithm {
        get { storage[JWTSignerKey.self] ?? createJWTSigner() }
        set { storage[JWTSignerKey.self] = newValue }
    }
    
    var offlineStoragePath: URL {
        get { storage[OfflineStoragePathKey.self] ?? URL(fileURLWithPath: "/tmp/libbywatch_offline") }
        set { storage[OfflineStoragePathKey.self] = newValue }
    }
    
private func createJWTSigner() -> any JWTAlgorithm {
        return HS256Algorithm(key: crypto.key)
    }
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
    
    private func createQRCodeAuthenticator() -> QRCodeAuthenticator {
        return QRCodeAuthenticator(configuration: overdriveConfig.apiConfiguration, tokenStore: TokenStore(encryptionKey: crypto.key))
    }
    
    private func createCryptoService() -> CryptoService {
        let key = SymmetricKey(size: .bits256)
        return CryptoService(key: key)
    }
}

extension OverdriveConfig {
    var apiConfiguration: APIConfiguration {
        APIConfiguration(
            baseURL: baseURL,
            clientId: clientId,
            clientSecret: clientSecret,
            userAgent: userAgent
        )
    }
}

extension Request {
    var overdriveClient: OverDriveClient {
        application.overdriveClient
    }
    
    var qrAuthenticator: QRCodeAuthenticator {
        application.qrAuthenticator
    }
    
    var crypto: CryptoService {
        application.crypto
    }
    
    var jwtSigner: any JWTAlgorithm {
        application.jwtSigner
    }
    
    var overdriveConfig: OverdriveConfig {
        application.overdriveConfig
    }
    
    var offlineStoragePath: URL {
        application.offlineStoragePath
    }
}

struct HS256Algorithm: JWTAlgorithm {
    let key: SymmetricKey
    
    func sign(_ plaintext: some DataProtocol) throws -> [UInt8] {
        let auth = HMAC<SHA256>.authenticationCode(for: plaintext, using: key)
        return Array(auth)
    }
    
    func verify(_ plaintext: some DataProtocol, signature: some DataProtocol) throws {
        let expected = HMAC<SHA256>.authenticationCode(for: plaintext, using: key)
        let provided = Array(signature)
        guard expected == provided else {
            throw JWTError.invalidSignature
        }
    }
}