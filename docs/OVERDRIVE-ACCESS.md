# OverDrive access and partnership plan

## Access requested

- Discovery APIs: Library Account, Search, Metadata, Library Availability, Magazine Issues, and Digital Inventory as applicable.
- Circulation APIs: Patron Information, Checkouts, and Holds.
- QR/link authentication.
- Integration-environment client credentials and test users.
- Written guidance and technical enablement for native Apple Watch playback, offline listening, DRM, and progress synchronization.
- A path to production review for one pilot public-library partner, then clarification of multi-library credentialing.

Reporting API access is not requested; the Developer Portal limits it to public-library customers and it is unnecessary for the MVP.

## Proposed application description

LibbyWatch is a companion and independent Apple Watch experience that helps authenticated public-library patrons listen to eligible Libby audiobook loans without carrying an iPhone. It will use OverDrive-hosted QR/link authentication and documented Discovery/Circulation APIs. Client credentials will remain on a secured backend. The implementation will respect all publisher DRM, territorial restrictions, device limits, lending periods, returns, and expiration/deletion instructions; use Libby branding and dynamic links; and provide required discovery, borrow, hold, sample, support, monitoring, and audit capabilities. No scraping, reverse engineering, media extraction, transcoding, or undocumented APIs will be used.

Native playback and offline listening will not be implemented against OverDrive content unless OverDrive confirms the use in writing and supplies or approves the fulfillment/DRM mechanism.

## Questions for the initial request

1. Does OverDrive accept this Apple Watch use case for API integration and production review?
2. Is there a native OverDrive Listen SDK, playback API, DRM module, or partner fulfillment interface suitable for watchOS?
3. If playback must remain hosted, is OverDrive Listen supported in a watchOS web-authentication session, including background audio and offline listening?
4. May the backend exchange QR authorization codes and retain encrypted refresh tokens for up to the documented 30-day refresh period?
5. Which patron/API fields are explicitly storable, and what deletion/retention rules apply?
6. How should playback position and bookmarks sync with Libby?
7. What session data must be supplied under API Agreement §2.1.13, in which schema and delivery mechanism?
8. What territorial, device-count, offline-renewal, and content-deletion controls are required for watchOS?
9. Can the required discovery/search/browse experience live primarily in the iPhone companion while the watch focuses on loans and playback?
10. What library partner and client-credential model is required for a consumer-facing multi-library product?
11. What branding and public-communications approvals are required before TestFlight, App Store submission, a website, or public announcement?

## Application sequence

1. Identify the legal applicant and person authorized to accept the API Agreement.
2. Identify a pilot public library willing to sponsor/test the integration.
3. Submit the developer/vendor request describing Discovery, Circulation, QR authentication, and native watch playback.
4. Obtain written answers to the go/no-go questions and archive them in a restricted compliance record, not in public documentation.
5. Receive client credentials and integration access.
6. Build and validate in the integration environment.
7. Assemble the production-review evidence package and demo installation.
8. Submit for OverDrive review with the pilot production library.
9. Resolve findings and receive written production-launch approval.
10. Enable production only through a controlled feature flag tied to the approval record.

## Evidence package

- Architecture and data-flow diagram.
- Data inventory, retention rules, privacy notice, and deletion flow.
- Credential management, token lifecycle, TLS, secret scanning, and incident response evidence.
- DRM/entitlement/expiration/return/offline test results.
- Search, sort, filter, browse, Advantage, sample, borrow, hold, fulfill, and return demonstrations.
- Metadata accuracy, dynamic-link, and Libby branding checklist.
- User-Agent registry and API request-volume controls.
- Monitoring, suspicious-use detection, 24-hour notification runbook, and session-data export.
- Customer-support flow and contacts.
- Physical Apple Watch playback and offline test matrix.
- Stable demo installation and reviewer instructions.

## Contacts and records

Use the [Developer Portal access form](https://developer.overdrive.com/request-access) for the initial request and [Developer Portal support](https://developer.overdrive.com/support/contact-us) for implementation questions. Record submission dates, correspondence, approvals, credential ownership, approved User-Agent strings, and approved production libraries in a restricted system.
