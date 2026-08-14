# Backlog map

The executable backlog is maintained as GitHub issues. This document records sequencing and exit criteria.

## GitHub views

- [All open backlog issues](https://github.com/evansh/LibbyWatch/issues?q=is%3Aissue%20state%3Aopen)
- [Milestones](https://github.com/evansh/LibbyWatch/milestones)
- [P0 critical path](https://github.com/evansh/LibbyWatch/issues?q=is%3Aissue%20state%3Aopen%20label%3A%22priority%3AP0%22)
- [Externally blocked work](https://github.com/evansh/LibbyWatch/issues?q=is%3Aissue%20state%3Aopen%20label%3A%22blocked%3Aexternal%22)

Primary gates: [native playback approval #3](https://github.com/evansh/LibbyWatch/issues/3), [API access #6](https://github.com/evansh/LibbyWatch/issues/6), [approved playback/DRM adapter #22](https://github.com/evansh/LibbyWatch/issues/22), and [production approval #33](https://github.com/evansh/LibbyWatch/issues/33).

## Milestone 0 — Feasibility and access

Exit: OverDrive accepts the use case in principle, the native playback/DRM path is known, a pilot library and legal applicant are identified, and integration credentials are requested or received.

- Secure written OverDrive decision on native Apple Watch playback.
- Identify legal applicant and pilot library partner.
- Submit Discovery/Circulation/QR access request.
- Resolve storage, session-data, branding, credential, and multi-library questions.
- Establish policy review and communications controls.

## Milestone 1 — Playback prototype

Exit: A physical Apple Watch independently streams and downloads licensed test audio with reliable background playback, controls, local progress, interruption recovery, and enforced mock expiry.

- Scaffold iOS/watchOS/backend boundaries and CI.
- Build deterministic service mocks and licensed audio fixtures.
- Validate watch background audio and Bluetooth routes.
- Validate offline download, protected storage, expiry, and deletion.
- Define security threat model and observability schema.
- Run battery, storage, restart, connectivity, and accessibility tests.

## Milestone 2 — Integrated MVP

Exit: All MVP flows work in OverDrive's integration environment using only approved interfaces, and every mandatory compliance control has evidence.

- QR/link authentication and refresh-token lifecycle.
- Patron/Advantage-aware shelf, metadata, search, availability, and dynamic links.
- Borrow, hold, fulfillment/open, and return flows.
- Approved native playback/DRM adapter, offline listening, and progress sync.
- Loan lifecycle, revocation, expiry, sign-out, and data deletion.
- Libby branding, samples, privacy, support, monitoring, session export, and incident response.
- Resilience, security, accessibility, and physical-device test suite.

## Milestone 3 — Approval and beta

Exit: OverDrive has given written production approval, the pilot library is configured, TestFlight succeeds, and release controls are ready.

- Assemble review/audit evidence and demo installation.
- Complete OverDrive production review and remediate findings.
- Configure pilot library and production credential ownership.
- Conduct TestFlight pilot and support rehearsal.
- Complete App Store privacy/content authorization and submit release.

## Dependency spine

`native playback decision → approved DRM/fulfillment contract → integration access → prototype validation → API integration → compliance evidence → OverDrive production approval → pilot → App Store release`

Work may proceed in parallel only when it uses mocks or independently licensed test audio and cannot be mistaken for authorization to access OverDrive content.
