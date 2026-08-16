# OverDrive Discovery, Circulation, and QR-auth access request

**Issue**: #6 — Submit the OverDrive Discovery, Circulation, and QR-auth access request  
**Priority**: P0  
**Milestone**: 0 — Feasibility & Access  
**Status**: Draft — ready to submit upon legal entity formation

## Submission target

**Form**: [Developer Portal access request](https://developer.overdrive.com/request-access)  
**Support**: [Developer Portal support](https://developer.overdrive.com/support/contact-us)

## Prerequisite

Legal entity and authorized signatory identified per [LEGAL-APPLICANT.md](LEGAL-APPLICANT.md).

## Request payload

### 1. Applicant information

| Field | Value |
|-------|-------|
| Legal entity name | [from LEGAL-APPLICANT.md] |
| Entity type / jurisdiction | [from LEGAL-APPLICANT.md] |
| Authorized signatory | [from LEGAL-APPLICANT.md] |
| Contact email | [from LEGAL-APPLICANT.md] |
| Contact phone | [from LEGAL-APPLICANT.md] |
| Website / project URL | https://evansh.github.io/libbywatch-concept/ |
| Developer account email | [to be created] |

### 2. Product description

**Product name**: LibbyWatch  
**Platform**: Apple Watch (watchOS) with iPhone companion (iOS)  
**Category**: Library audiobook companion app

**Description**:
> LibbyWatch is a companion Apple Watch experience that helps authenticated public-library patrons listen to eligible Libby audiobook loans without carrying an iPhone. It uses OverDrive-hosted QR/link authentication and documented Discovery and Circulation APIs. All client credentials reside on a secured backend. The implementation respects all publisher DRM, territorial restrictions, device limits, lending periods, returns, and expiration/deletion instructions; uses Libby branding and dynamic links; and provides required discovery, borrow, hold, sample, support, monitoring, and audit capabilities. No scraping, reverse engineering, media extraction, transcoding, or undocumented APIs will be used.

**Key differentiator**: Native Apple Watch playback and offline listening for library audiobooks — a use case not currently served by the Libby app.

### 3. API access requested

| API scope | Purpose |
|-----------|---------|
| Discovery: Library Account | Validate library membership and configuration |
| Discovery: Search | Title/author search for eligible audiobooks |
| Discovery: Metadata | Detailed title metadata, cover art, availability |
| Discovery: Library Availability | Real-time availability per library |
| Discovery: Digital Inventory | Catalog browsing and featured collections |
| Circulation: Patron Information | Authenticated user profile, loans, holds |
| Circulation: Checkouts | Borrow, return, fulfillment, loan status |
| Circulation: Holds | Place, suspend, manage holds |
| Authentication: QR/link | OverDrive-hosted auth flow; no credential handling |
| Integration environment | Test credentials, test users, sandbox library |

**Not requested**: Reporting APIs (restricted to public-library customers; not needed for MVP).

### 4. Native playback and offline listening — go/no-go questions

We require written OverDrive guidance on the following before implementing any media integration:

1. **Use-case acceptance**: Does OverDrive accept a native Apple Watch audiobook playback use case for API integration and production review?

2. **Playback mechanism**: Is there a native OverDrive Listen SDK, playback API, DRM module, or partner fulfillment interface suitable for watchOS?

3. **Hosted playback fallback**: If playback must remain hosted, is OverDrive Listen supported in a watchOS web-authentication session, including background audio and offline listening?

4. **Token lifecycle**: May the backend exchange QR authorization codes and retain encrypted refresh tokens for up to the documented 30-day refresh period?

5. **Patron data storage**: Which patron/API fields are explicitly storable, and what deletion/retention rules apply? (API Agreement §2.1.18)

6. **Progress sync**: How should playback position and bookmarks sync with Libby? Is there an approved sync API?

7. **Session data**: What session data must be supplied under API Agreement §2.1.13, in which schema and delivery mechanism?

8. **WatchOS controls**: What territorial, device-count, offline-renewal, and content-deletion controls are required for watchOS?

9. **Discovery split**: Can the required discovery/search/browse experience live primarily in the iPhone companion while the watch focuses on loans and playback?

10. **Credential model**: What library partner and client-credential model is required for a consumer-facing multi-library product?

11. **Branding approvals**: What branding and public-communications approvals are required before TestFlight, App Store submission, a website, or public announcement?

### 5. Compliance commitments

We commit to implementing all mandatory controls documented in [OVERDRIVE-COMPLIANCE.md](OVERDRIVE-COMPLIANCE.md), including:

- Official-API-only architecture (no scraping, reverse engineering, private endpoints)
- Backend-only client secret storage with managed secrets vault, rotation, TLS
- QR/link authentication so library credentials never touch the client
- Encrypted refresh-token storage with 30-day rotation per OverDrive spec
- Metadata refresh ≥24h; unavailable-content removal ≤24h (API Agreement §2.1.1–2)
- Territorial/geographic enforcement; no client-side bypass
- Approved DRM adapter; fail-closed entitlement; automatic deletion on expiry/return
- Dynamic `link.overdrive.com` links for all title records and actions
- Accurate, unaltered metadata display with provenance marking
- Samples/excerpts via API-provided links
- End-user support flow and runbooks
- Session-data export schema, retention review, privacy assessment
- Privacy notice with OverDrive policy link; purpose-limited email usage
- Data allowlist and deletion/uninstall handlers
- Unique, versioned User-Agent strings with change notification
- Monitoring endpoint integration (≤1/min polling; prefer 5-min)
- Suspicious-use detection and 24-hour OverDrive notification runbook
- Audit-ready evidence package and stable demo installation
- Production feature flag gated by written OverDrive approval
- Developer-notice review process; adapter boundaries; kill switch

### 6. Pilot library

We are actively recruiting a pilot public-library partner. Upon identification, we will provide:
- Library name and OverDrive library ID
- Library contact and sponsorship confirmation
- Integration-environment test plan with library staff

### 7. Evidence package preview

Upon integration-environment access, we will build and provide:
- Architecture and data-flow diagram
- Data inventory, retention rules, privacy notice, deletion flow
- Credential management, token lifecycle, TLS, secret scanning, incident response evidence
- DRM/entitlement/expiration/return/offline test results (with licensed test audio)
- Search, sort, filter, browse, Advantage, sample, borrow, hold, fulfill, return demonstrations
- Metadata accuracy, dynamic-link, and Libby branding checklist
- User-Agent registry and API request-volume controls
- Monitoring, suspicious-use detection, 24-hour notification runbook, session-data export
- Customer-support flow and contacts
- Physical Apple Watch playback and offline test matrix
- Stable demo installation and reviewer instructions

## Submission checklist

- [ ] Legal entity formed and recorded in LEGAL-APPLICANT.md
- [ ] Developer account created with entity email
- [ ] This request reviewed by counsel (recommended)
- [ ] Submit via Developer Portal access form
- [ ] Record submission date and confirmation
- [ ] Track correspondence in restricted compliance record
- [ ] Follow up on go/no-go questions

## Related documents

- [LEGAL-APPLICANT.md](LEGAL-APPLICANT.md) — Legal entity details
- [OVERDRIVE-ACCESS.md](OVERDRIVE-ACCESS.md) — Access plan and sequence
- [OVERDRIVE-COMPLIANCE.md](OVERDRIVE-COMPLIANCE.md) — Full compliance matrix
- [RISKS.md](RISKS.md) — Risk register and stop conditions
- [GitHub Issue #6](https://github.com/evansh/LibbyWatch/issues/6)

---

*This draft is ready for submission upon legal entity formation. Do not submit until the legal applicant is established and authorized to accept the API Agreement.*