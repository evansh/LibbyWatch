# LibbyWatch Implementation

Independent proposal for an official Apple Watch library-audiobook experience.

## Project Structure

```
libbyWatch/
├── Source/
│   ├── Shared/                 # Shared Swift package (iOS, watchOS, macOS)
│   │   ├── Sources/
│   │   │   ├── LibbyWatchModels/      # Core data models
│   │   │   ├── LibbyWatchNetworking/  # OverDrive API client
│   │   │   ├── LibbyWatchAuth/        # QR auth, token management
│   │   │   └── LibbyWatchPlayback/    # Playback interfaces & mocks
│   │   └── Tests/
│   │       └── LibbyWatchSharedTests/
│   ├── Backend/                # Vapor backend service
│   │   ├── Sources/
│   │   │   └── LibbyWatchBackend/
│   │   │       ├── Controllers/       # API endpoints
│   │   │       ├── Models/            # Fluent models
│   │   │       ├── Services/          # Business logic
│   │   │       └── Middleware/        # Auth, logging
│   │   └── Tests/
│   │       └── LibbyWatchBackendTests/
│   ├── App/                    # iOS companion app (Xcode project)
│   └── WatchApp/               # watchOS app (Xcode project)
├── docs/                       # Architecture & compliance docs
├── .github/workflows/          # CI/CD pipelines
└── Package.swift               # Root package (if needed)
```

## Milestone 1: Playback Prototype (Current)

### Implemented Components

| Component | Location | Status |
|-----------|----------|--------|
| Core Models (Book, Loan, Hold, Patron, etc.) | `Source/Shared/Sources/LibbyWatchModels/Models.swift` | ✅ Complete |
| OverDrive API Client | `Source/Shared/Sources/LibbyWatchNetworking/` | ✅ Complete |
| Mock OverDrive Client | `Source/Shared/Sources/LibbyWatchNetworking/MockClient.swift` | ✅ Complete |
| QR Authentication & Token Management | `Source/Shared/Sources/LibbyWatchAuth/Auth.swift` | ✅ Complete |
| Playback Interfaces (Player, Offline, Sync) | `Source/Shared/Sources/LibbyWatchPlayback/Playback.swift` | ✅ Complete |
| Mock Audiobook Player | `Source/Shared/Sources/LibbyWatchPlayback/MockPlayer.swift` | ✅ Complete |
| Mock Offline Storage | `Source/Shared/Sources/LibbyWatchPlayback/MockPlayer.swift` | ✅ Complete |
| Vapor Backend (Auth, Libraries, Loans, Holds, Offline, Sync, Session) | `Source/Backend/Sources/LibbyWatchBackend/` | ✅ Complete |
| Unit Tests (Shared + Backend) | `Source/Shared/Tests/`, `Source/Backend/Tests/` | ✅ Complete |
| CI Pipeline (GitHub Actions) | `.github/workflows/ci.yml` | ✅ Complete |

### Issues Addressed

- **#12**: Scaffold iOS, watchOS, shared packages, CI workspace
- **#13**: Build service contracts, deterministic mocks, licensed audio fixtures

## Getting Started

### Prerequisites

- macOS 14+ with Xcode 15.2+
- Swift 5.9+
- Vapor Toolbox (`brew install vapor/tap/vapor`)

### Building Shared Package

```bash
cd Source/Shared
swift build
swift test
```

### Building Backend

```bash
cd Source/Backend
swift build
swift test
```

### Running Backend Server

```bash
cd Source/Backend
swift run App serve --hostname 0.0.0.0 --port 8080
```

### CI/CD

The GitHub Actions workflow runs on every push/PR:
- Shared package tests (macOS)
- Backend tests (macOS)
- iOS build & test (when Xcode project exists)
- watchOS build (when Xcode project exists)
- SwiftLint
- Security audit
- Documentation build

## Architecture

### Shared Package Modules

1. **LibbyWatchModels** - Pure Swift data structures (Book, Loan, Hold, Patron, SearchResult, etc.)
2. **LibbyWatchNetworking** - OverDrive API client protocol + implementation
3. **LibbyWatchAuth** - QR code auth flow, token storage, refresh logic, encryption
4. **LibbyWatchPlayback** - Player protocol, offline storage, progress sync, mock implementations

### Backend API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /health` | Health check |
| `POST /api/v1/auth/qr-initiate` | Start QR auth flow |
| `POST /api/v1/auth/qr-callback` | Handle QR callback |
| `POST /api/v1/auth/refresh` | Refresh access token |
| `POST /api/v1/auth/revoke` | Revoke tokens |
| `GET /api/v1/libraries` | List libraries |
| `GET /api/v1/libraries/:id/search` | Search catalog |
| `GET /api/v1/libraries/:id/availability` | Check availability |
| `GET /api/v1/loans` | List loans |
| `POST /api/v1/loans/:bookId/borrow` | Borrow book |
| `POST /api/v1/loans/:loanId/return` | Return loan |
| `GET /api/v1/loans/:loanId/fulfillment` | Get fulfillment URL |
| `GET /api/v1/holds` | List holds |
| `POST /api/v1/holds/:bookId` | Place hold |
| `DELETE /api/v1/holds/:holdId` | Cancel hold |
| `GET /api/v1/offline` | List downloads |
| `POST /api/v1/offline/download` | Start download |
| `DELETE /api/v1/offline/:bookId` | Delete download |
| `POST /api/v1/sync/progress` | Sync progress |
| `POST /api/v1/session/export` | Export session data |
| `POST /api/v1/session/incident` | Report incident |

## Compliance

All implementation follows the constraints documented in:
- `docs/OVERDRIVE-COMPLIANCE.md` - OverDrive API Agreement compliance matrix
- `docs/THREAT-MODEL.md` - STRIDE threat model
- `docs/RISKS.md` - Risk register with stop conditions

### Key Compliance Controls Implemented

- ✅ Backend-only client secret storage (Vault-ready)
- ✅ Encrypted token storage with AES-256-GCM
- ✅ QR/link authentication (no credential handling on client)
- ✅ Token refresh with rotation
- ✅ Audit logging for all user actions
- ✅ Data minimization (allowlist-only fields)
- ✅ Automatic cleanup of expired offline content

## Next Steps (Milestone 1 Remaining)

- [ ] **#11**: Spike long-form background playback & Bluetooth routing on physical Apple Watch
- [ ] **#9**: Spike offline download, protected storage, expiry, deletion on watchOS
- [ ] **#10**: Prototype progress journaling, conflict resolution, restart recovery
- [ ] **#15**: Define observability, session-data export, 24h incident process
- [ ] **#16**: Physical-device test matrix (battery, storage, accessibility)
- [ ] Create Xcode project for iOS app (`Source/App/`)
- [ ] Create Xcode project for watchOS app (`Source/WatchApp/`)
- [ ] Integrate shared package as Swift Package dependency in Xcode projects

## License

MIT License - see LICENSE file for details.

## Disclaimer

This is an independent proposal. Not affiliated with, endorsed by, or approved by OverDrive, Libby, Apple, or any library.