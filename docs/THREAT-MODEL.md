# Credential, token, media, and entitlement threat model

**Issue**: #14 — Create the credential, token, media, and entitlement threat model  
**Priority**: P0  
**Milestone**: 1 — Playback Prototype  
**Status**: Complete — baseline v1.0

## Scope

This threat model covers the LibbyWatch system boundary:
- **Backend** (API gateway, auth service, token store, media proxy, sync service)
- **iOS companion app** (QR initiation, discovery UI, loan shelf sync, settings)
- **watchOS app** (loan shelf, playback, offline storage, progress sync)
- **OverDrive API integration** (Discovery, Circulation, QR auth)
- **Data flows** between all components

Out of scope: OverDrive internal infrastructure, library systems, Apple platform security.

## Assets and trust boundaries

```
┌─────────────────────────────────────────────────────────────────┐
│                        INTERNET                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ OverDrive API│  │ Apple Push   │  │ App Store / TestFlight │  │
│  │ (Trusted)    │  │ Notifications│  │ (Code signing)       │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘  │
└─────────┼─────────────────┼──────────────────────┼──────────────┘
          │                 │                      │
          ▼                 ▼                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                      BACKEND (TRUSTED)                          │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌───────────┐ │
│  │ Auth Service│ │ Token Store │ │ Media Proxy │ │ Sync Svc  │ │
│  │ (QR exchg)  │ │ (Encrypted) │ │ (Signed URLs)│ │ (Progress)│ │
│  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘ └─────┬────┘ │
└─────────┼───────────────┼────────────────┼──────────────┼──────┘
          │               │                │              │
          ▼               ▼                ▼              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      CLIENT DEVICES (SEMI-TRUSTED)              │
│  ┌─────────────────────┐          ┌─────────────────────────┐  │
│  │ iOS Companion App   │◄────────►│ watchOS App             │  │
│  │ (User auth, UI)     │  BLE/    │ (Playback, Offline,     │  │
│  │ Keychain: user JWT  │  WCSession│  Progress, Keychain)   │  │
│  └─────────────────────┘          └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

**Trust levels**:
- **Backend**: Fully trusted — runs controlled code, holds secrets
- **OverDrive API**: Trusted for auth/tokens/media; validated via TLS + certificate pinning
- **iOS/watchOS apps**: Semi-trusted — user device, subject to jailbreak, malware, physical access
- **User**: Trusted for intent; untrusted for credential handling

## Data classification

| Asset | Classification | Storage | Retention | Encryption |
|-------|----------------|---------|-----------|------------|
| OverDrive client secret | **SECRET** | Backend vault (HSM/KMS) | Indefinite | At rest: AES-256; In transit: TLS 1.3 |
| QR authorization code | **SECRET** | Backend memory (ephemeral) | <5 min | TLS 1.3 only |
| OverDrive access token | **CONFIDENTIAL** | Backend token store (encrypted) | 1 hour | At rest: AES-256-GCM |
| OverDrive refresh token | **SECRET** | Backend token store (encrypted) | ≤30 days | At rest: AES-256-GCM; key rotation |
| Patron collection token | **CONFIDENTIAL** | Backend token store (encrypted) | Session + 24h | At rest: AES-256-GCM |
| User JWT (LibbyWatch) | **CONFIDENTIAL** | iOS/watchOS Keychain | 30 days | iOS Data Protection (Class: WhenUnlocked) |
| Offline audiobook media | **CONFIDENTIAL** | watchOS app sandbox (FileProtection: CompleteUnlessOpen) | Loan duration | Per-title AES-256 (DRM) + filesystem encryption |
| Playback position / bookmarks | **INTERNAL** | Backend + watchOS Keychain | Loan duration + 30d | At rest: AES-256; In transit: TLS 1.3 |
| Session telemetry | **INTERNAL** | Backend (encrypted) | 90 days | At rest: AES-256 |
| OverDrive patron PII (name, barcode, email) | **PII** | Backend (encrypted, allowlisted fields only) | Session only | At rest: AES-256; purge on sign-out |

## Threat enumeration (STRIDE)

### Spoofing

| ID | Threat | Impact | Likelihood | Mitigation |
|----|--------|--------|------------|------------|
| S-1 | Attacker impersonates OverDrive API (MITM) | Token theft, media access | Low | Certificate pinning; TLS 1.3 only; HSTS |
| S-2 | Attacker spoofs backend to client | Credential phishing, malicious media | Medium | Mutual TLS for device enrollment; signed config; App Attest |
| S-3 | User shares QR code with attacker | Account takeover | Medium | Short QR expiry (5 min); one-time use; device binding |
| S-4 | Attacker replays QR authorization code | Token theft | Low | Single-use codes; immediate exchange; backend rate limiting |

### Tampering

| ID | Threat | Impact | Likelihood | Mitigation |
|----|--------|--------|------------|------------|
| T-1 | Modify offline media to bypass DRM/expiry | Copyright violation, license breach | High | DRM-enforced decryption; fail-closed; integrity checks on playback start |
| T-2 | Tamper with playback position sync | Progress loss, sync conflicts | Medium | Signed position payloads; server-authoritative; conflict resolution |
| T-3 | Modify client binary (jailbreak/repackage) | Bypass controls, extract keys | Medium | App Attest; code signing; runtime integrity checks; no secrets in client |
| T-4 | Tamper with token store (backend) | Token theft, privilege escalation | Low | Immutable infrastructure; WORM logs; secrets rotation; audit trail |

### Repudiation

| ID | Threat | Impact | Likelihood | Mitigation |
|----|--------|--------|------------|------------|
| R-1 | User denies borrowing/returning | Audit failure, license dispute | Low | Immutable audit log (append-only); signed API requests; OverDrive session data export |
| R-2 | Backend denies token refresh failure | Service disruption, compliance gap | Low | Structured logging; correlation IDs; monitoring alerts |

### Information Disclosure

| ID | Threat | Impact | Likelihood | Mitigation |
|----|--------|--------|------------|------------|
| I-1 | Client secret leaked via logs/repo | Full API access as vendor | Medium | Secret scanning (GitHub, CI); never in code; vault-only access; rotation policy |
| I-2 | Refresh token extracted from backup | Long-term account access | Medium | Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`; no iCloud backup |
| I-3 | Offline media extracted from device | Content piracy | High | DRM encryption; filesystem encryption; no raw media in app bundle |
| I-4 | Patron PII in logs/telemetry | Privacy violation, GDPR/CCPA | Medium | Allowlist-only fields; automatic redaction; no PII in telemetry |
| I-5 | Session data over-collection | Privacy violation, API Agreement breach | Medium | Data minimization review; schema allowlist; retention enforcement |

### Denial of Service

| ID | Threat | Impact | Likelihood | Mitigation |
|----|--------|--------|------------|------------|
| D-1 | OverDrive API rate limit exceeded | Service outage | Medium | Client-side rate limiting; exponential backoff; circuit breaker |
| D-2 | Backend token store unavailable | Auth failure for all users | Low | Multi-AZ deployment; read replicas; cached fallback (short TTL) |
| D-3 | Media proxy overwhelmed | Playback failure | Medium | CDN for signed URLs; request quotas; cache-control |
| D-4 | Malicious user loops QR initiation | Resource exhaustion | Low | Per-IP/device rate limits; CAPTCHA on repeated failures |

### Elevation of Privilege

| ID | Threat | Impact | Likelihood | Mitigation |
|----|--------|--------|------------|------------|
| E-1 | User escalates to admin/backend access | Full system compromise | Low | No admin endpoints in client; RBAC in backend; least privilege |
| E-2 | Compromised refresh token → new access tokens | Extended unauthorized access | Medium | Short access token TTL (1h); refresh token rotation; anomaly detection |
| E-3 | watchOS app accesses iOS Keychain items | Cross-app data leak | Low | App Groups with strict entitlements; Keychain access groups; no shared secrets |

## Attack surface summary

| Component | Entry points | Hardening |
|-----------|--------------|-----------|
| Backend API | HTTPS (mTLS for device enroll), Webhooks (OverDrive), Internal gRPC | WAF; rate limiting; input validation; schema enforcement; secret scanning |
| OverDrive integration | OAuth2 token endpoint, Discovery/Circulation APIs | Certificate pinning; allowlisted domains; request signing; audit logging |
| iOS app | QR scan (camera/Universal Link), Push notifications, App Store | App Attest; Keychain only; no network secrets; network extension for cert pinning |
| watchOS app | BLE/WCSession from iOS, Local playback, Background tasks | No direct network; all via iOS proxy; Keychain only; FileProtection CompleteUnlessOpen |
| Media storage | watchOS sandbox, Backend signed URLs | DRM encryption; signed URL expiry (15 min); range requests only |

## Security controls matrix

| Control | Implementation | Verification |
|---------|----------------|--------------|
| Secret management | HashiCorp Vault / AWS Secrets Manager / Azure Key Vault | Rotation test; audit log review; secret scanning in CI |
| Certificate pinning | Native (Network.framework) + TrustKit fallback | Pinning test in CI; runtime verification |
| Token encryption | AES-256-GCM with per-tenant keys; key rotation 90d | Decryption test; key rotation drill |
| DRM enforcement | OverDrive-approved adapter; fail-closed; clock-tamper detection | Playback test matrix; expiry test; time-shift test |
| Data minimization | Allowlist schema (JSON Schema); automatic purge jobs | Schema validation in CI; purge audit |
| Incident response | 24h runbook; session data export; OverDrive notification template | Tabletop exercise; quarterly drill |
| App Attest | Device integrity on enrollment; periodic re-attestation | Attestation failure handling test |
| Code signing | Apple Developer Program; notarization (macOS catalyst if used) | CI gate; release automation |

## Residual risks (accepted with mitigations)

| Risk | Acceptance rationale | Compensating control |
|------|---------------------|---------------------|
| Jailbroken device extracts Keychain items | Platform limitation; low user base | App Attest; no high-value secrets in Keychain (only user JWT) |
| OverDrive API changes break token flow | External dependency | Adapter pattern; developer-notice monitoring; integration test suite |
| Physical device theft → offline media access | Loan duration limit; DRM encryption | Auto-delete on expiry; passcode requirement; remote wipe via MDM (enterprise) |
| Insider threat (backend admin) | Operational necessity | Split duties; audit logs; vault access requires 2-person approval |

## Compliance mapping

| Requirement | Control | Evidence |
|-------------|---------|----------|
| API Agreement §3.1 (credential storage) | Vault + encryption + rotation | Vault audit log; rotation records |
| API Agreement §3.3 (compromise reporting) | 24h runbook + monitoring alerts | Runbook; alert history |
| API Agreement §4.2 (User-Agent) | Versioned registry + change process | Registry; change log |
| API Agreement §4.4 (24h suspicious use) | Detection rules + notification template | Rule config; test notifications |
| API Agreement §2.1.18 (data removal) | Allowlist + purge jobs + uninstall handler | Purge audit; uninstall test |
| General Terms (no DRM circumvention) | Approved adapter only; fail-closed | Adapter review; playback test matrix |

## Review and approval

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Security Lead | | | |
| Backend Lead | | | |
| iOS/watchOS Lead | | | |
| Compliance/Privacy | | | |
| Legal Counsel | | | |

## Version history

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-08-16 | | Baseline threat model for Milestone 1 |

---

*This threat model is a living document. Review and update at each milestone gate, after security incidents, and when architecture changes. Next review: Milestone 2 gate.*