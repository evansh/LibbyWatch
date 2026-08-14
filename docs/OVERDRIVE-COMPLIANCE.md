# OverDrive requirements and compliance matrix

Reviewed August 14, 2026. This is an engineering interpretation, not legal advice. The API agreement and incorporated policies can change; re-review them before accepting credentials, requesting production approval, or releasing.

## Primary official sources

- [API overview](https://developer.overdrive.com/getting-started/api-overview)
- [Application process and production-review criteria](https://developer.overdrive.com/getting-started/application-process)
- [API License Agreement](https://developer.overdrive.com/terms-and-conditions)
- [OverDrive Terms and Conditions](https://www.overdrive.com/policies/terms-and-conditions)
- [OverDrive Privacy Policy](https://www.overdrive.com/policies/privacy-policy)
- [Authentication](https://developer.overdrive.com/api-docs/authentication)
- [QR code authentication](https://developer.overdrive.com/api-docs/authentication/qr-code-authentication)
- [Patron Information API](https://developer.overdrive.com/api-docs/circulation-apis/patron-information)
- [Checkouts API](https://developer.overdrive.com/api-docs/circulation-apis/checkouts)
- [Holds API](https://developer.overdrive.com/api-docs/circulation-apis/holds)
- [Integration environment](https://developer.overdrive.com/getting-started/integration-library)
- [Libby branding](https://developer.overdrive.com/resources/api-style-guide/libby-branding)
- [Formats](https://developer.overdrive.com/resources/overdrive-information/content-formats)
- [Lending models](https://developer.overdrive.com/resources/overdrive-information/lending-models)
- [Advantage accounts](https://developer.overdrive.com/resources/overdrive-information/advantage-accounts)
- [Monitoring endpoint](https://developer.overdrive.com/support/monitoring-endpoint)
- [Developer notices](https://developer.overdrive.com/blog)

## Critical finding: playback is not granted by the public documentation

The Checkouts API exposes a `downloadRedirect` that returns an OverDrive-hosted fulfillment interface. The formats documentation says an `audiobook-overdrive` title opens as an OverDrive Listen audiobook in the browser. The public documentation does not describe a raw media URL, native-player SDK, watchOS DRM module, or permission to extract or repackage media.

The general Terms prohibit reverse engineering or separating OverDrive software, extracting or repackaging content, and circumventing technological controls. The API Agreement also requires use of authorized API methods and honoring DRM. Therefore:

- Native watch playback is **blocked pending written OverDrive approval and an approved technical mechanism**.
- A browser redirect may be prototyped only in the integration environment if OverDrive confirms the target platform is supported.
- Network inspection, scraping, stream capture, URL extraction, transcoding, and DRM workarounds are out of scope.

## Mandatory implementation controls

| Requirement | Source | Planned control/evidence | Gate |
|---|---|---|---|
| Use the API only for the permitted, approved purpose and no unauthorized access method | API Agreement §§1.1, 1.3 | Official-API-only ADR; architecture review; dependency allowlist | Feasibility |
| Customers/library partners follow OverDrive's application and terms process | API Agreement §1.4 | Library-partner onboarding checklist | Production |
| Follow OverDrive Privacy Policy and applicable privacy/children's laws | API Agreement preamble, §1.5 | Privacy assessment, age/COPPA decision, data inventory, policy links | MVP |
| Refresh metadata at least every 24 hours | API Agreement §2.1.1 | Scheduled refresh job and freshness alert | MVP |
| Apply title changes/remove unavailable content within 24 hours | API Agreement §2.1.2 | Tombstone/removal job with SLA evidence | MVP |
| Enforce territorial/geographic restrictions | API Agreement §2.1.3 | Approved entitlement policy; no client-side bypass | MVP |
| Honor all DRM permissions, loan expiration, and sharing restrictions | API Agreement §2.1.4; Terms digital-content license | Approved DRM adapter; fail-closed entitlement; deletion tests | Feasibility/MVP |
| Prominent link to OverDrive-hosted title record | API Agreement §2.1.5 | API-provided dynamic title link in detail UI | MVP |
| Search, title/author and advanced discovery | API Agreement §2.1.6 | iPhone discovery UI and integration tests | MVP |
| Featured/subject browsing | API Agreement §2.1.7 | Browse sections based on supplied metadata | MVP |
| Link to hosted site and provide checkout access | API Agreement §2.1.8 | Dynamic links and API action-driven checkout | MVP |
| Display accurate, unaltered metadata | API Agreement §§2.1.9, 2.2.4 | Snapshot/contract tests; provenance marking | MVP |
| Display supplied samples/excerpts and link full truncated metadata/reviews | API Agreement §§2.1.10–11 | Sample/dynamic-link rendering tests | MVP |
| Supply end-user customer and technical support | API Agreement §2.1.12; §4.1 | In-app support, runbooks, support ownership | Beta |
| Supply session data to OverDrive on demand | API Agreement §§1.6, 2.1.13 | Documented event schema, export, retention and privacy review | MVP |
| Supply non-OverDrive catalog data if available | API Agreement §2.1.14 | Mark not applicable unless product later ingests it | Review |
| Display mutually agreed attribution | API Agreement §2.1.15 | Branding review evidence | MVP |
| Include privacy link and incorporate/notify about OverDrive policy as applicable | API Agreement §2.1.16 | User-facing privacy notice with OverDrive link | MVP |
| Restrict email usage to requested OverDrive-service information | API Agreement §§2.1.17, 2.2.13 | Purpose limitation; no marketing pipeline | MVP |
| Immediately remove API-derived user data not identified as storable | API Agreement §2.1.18 | Data allowlist and deletion/uninstall handlers | MVP |
| Provide an installation to OverDrive on request | API Agreement §2.1.19 | Stable demo/TestFlight and test account process | Approval |
| Do not benchmark, reverse engineer, modify, repackage, or enable third-party downloads | API Agreement §2.2; general Terms | Policy guardrail, code review checklist, no private API dependencies | Always |
| No public statements about the API integration without approval | API Agreement §2.2.7 | Communications approval checklist; private repository | Always |
| Do not create identities/profiles or disclose API metrics/analysis | API Agreement §§2.2.6, 2.2.11 | Minimal telemetry and analytics review | MVP |
| Do not intercept OverDrive communications; seek approval for product notifications | API Agreement §2.2.12 | Notification inventory and approval gate | MVP |
| Store credentials on a secure server; conceal/encrypt them; use TLS | API Agreement §3.1 | Managed secrets vault, key rotation, TLS, secret scanning | MVP |
| Report suspected credential compromise | API Agreement §3.3 | Incident runbook and contact escalation | MVP |
| Unique, consistent, attributable User-Agent strings; notify before changes | API Agreement §4.2 | Versioned User-Agent registry and change process | MVP |
| No live use before OverDrive review and written approval | API Agreement §4.3 | Production feature flag requiring approval artifact | Production |
| Monitor suspicious use and notify OverDrive within 24 hours of prohibited activity | API Agreement §4.4 | Alerts, on-call runbook, 24-hour SLA exercise | MVP |
| Cooperate with emergency/routine audits | API Agreement §4.5 | Evidence index, demo environment, audit owner | Approval |
| Tolerate API changes, suspension, fees and lack of guaranteed support | API Agreement §§6–8 | Adapter boundaries, kill switch, degraded UX, risk review | MVP |
| Personal, noncommercial patron use; no extraction/redistribution; delete at loan end | General Terms | Product terms, DRM controls, expiry deletion tests | MVP |
| Do not circumvent security/technological controls | General Terms security section | Explicit prohibition and security review | Always |

## Production-review criteria from the Developer Portal

OverDrive says a Circulation implementation must be built in the integration environment and submitted for production review. The published criteria require:

- Accurate and secure authentication.
- OverDrive Advantage support.
- Search, sort, and filtering.
- Accurate cover art and metadata.
- Samples when available.
- Borrow and hold functionality.
- Open/download fulfillment after borrowing.
- Libby branding for public-library content.

The backlog includes evidence for every item. We must ask whether a focused watch companion can satisfy some discovery criteria via its iPhone component or dynamic Libby links.

## Authentication and token requirements

- Prefer QR/link authentication so library credentials remain on an OverDrive/library-hosted flow.
- The QR initiation URL includes redirect, abandon, and error URLs, website ID, and client ID.
- Exchange the returned authorization code on the backend using the client secret.
- Access tokens expire after one hour; QR refresh tokens can refresh access for up to 30 days and are rotated on refresh.
- Use the patron collection token for user-specific Discovery calls so Advantage and other entitled holdings are represented.
- The Patron Information docs recommend refreshing user collection tokens every session rather than storing them.
- Current 2026 developer notices require integrations to adopt refreshed collection and patron-token values; the old library token values remain supported only through September 2026.

## Circulation and catalog behavior

- Treat API-provided links and actions as authoritative; do not infer that an operation is available.
- Support both borrow and hold flows because lending models change availability behavior.
- Respect checkout/hold limits, pickup windows, suspensions, due dates, and format-lock behavior.
- A ready hold is indicated by the checkout action, not only by queue position.
- OverDrive Listen fulfillment is currently browser-hosted; native playback needs additional approval.
- Defensively decode nullable/omitted fields and tolerate newly added fields.

## Branding requirements

For production access, the product must:

- Refer to Libby wherever the vendor platform is referenced, such as “Borrow with Libby” and “Place hold with Libby.”
- Call formats “Libby ebook,” “Libby audiobook,” or “Libby magazine.”
- Use API/MARC dynamic `link.overdrive.com` links.
- Use supplied OverDrive Read/Listen sample links.

Logo use and watch-specific presentation should be confirmed in writing. General Terms otherwise prohibit unapproved use of OverDrive trademarks.

## Operational requirements

- Use the authenticated monitoring endpoint for service health.
- The monitoring response is cached for one minute; do not poll more often than once a minute, and prefer every five minutes for frequent checks.
- Maintain a developer-notice review process because API and token behavior changes.
- Provide an integration demo, security/privacy controls, lending enforcement evidence, incident response, and session-data export for review or audit.

## Decisions requiring counsel or written OverDrive clarification

- Whether the proposed native playback service and offline storage are within the API license's permitted purpose.
- Whether the general Terms' restriction on using OverDrive software to develop like software applies to a separately approved API client/player and what written permission resolves it.
- Which API-derived patron fields may be stored, for how long, and in which regions.
- Exact content-license, DRM, geofencing, device, offline, and deletion requirements.
- Session-data scope, legal basis, retention, anonymization, and secure transfer.
- Children's access/COPPA design and whether the initial product should be 13+.
- Trademark and public-communications approval.
- Library-specific versus centralized credentials and contractual relationships.
