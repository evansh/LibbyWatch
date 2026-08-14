# LibbyWatch

LibbyWatch is an independent Apple Watch audiobook experience for public-library loans, designed for an eventual **official** OverDrive/Libby integration.

> Status: discovery and feasibility. No production OverDrive access or native audiobook playback permission has been granted.

## Product goal

Let a patron leave their iPhone behind and listen to an eligible Libby audiobook from Apple Watch over Bluetooth, with streaming, offline downloads, playback controls, and position synchronization.

## Non-negotiable boundary

This project uses only documented OverDrive APIs and explicitly approved fulfillment/DRM mechanisms. It will not scrape Libby, reverse engineer OverDrive software or private endpoints, extract audiobook files, bypass DRM, or retain content after a loan expires.

The public Circulation API currently fulfills an `audiobook-overdrive` loan by redirecting to an OverDrive-hosted browser experience. Native watch playback therefore remains an external dependency that requires written approval and technical enablement from OverDrive.

## Documents

- [MVP definition](docs/MVP.md)
- [Architecture](docs/ARCHITECTURE.md)
- [OverDrive requirements and compliance matrix](docs/OVERDRIVE-COMPLIANCE.md)
- [API access and partnership plan](docs/OVERDRIVE-ACCESS.md)
- [Risk register](docs/RISKS.md)
- [Backlog map](docs/BACKLOG.md)
- [Architecture decision: official API only](docs/decisions/0001-official-overdrive-integration-only.md)

## Delivery gates

1. **Feasibility:** OverDrive confirms that native Apple Watch playback is an approved use and supplies or approves a playback/DRM interface.
2. **Integration access:** OverDrive grants Discovery and Circulation API access and integration-environment credentials.
3. **MVP:** The watch app meets the product, security, privacy, lending, branding, and support acceptance criteria.
4. **Production:** OverDrive reviews the implementation and gives written launch approval.
5. **Release:** A library partner, TestFlight validation, and App Store review are complete.

## Source policy

Requirements are based on the official OverDrive Developer Portal and OverDrive policies, reviewed on **August 14, 2026**. The compliance document links each requirement to its source. Requirements and policies may change, so they must be re-reviewed before each approval or release gate.

This repository's analysis is product and engineering guidance, not legal advice.
