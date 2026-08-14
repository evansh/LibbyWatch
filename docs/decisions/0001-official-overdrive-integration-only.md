# ADR 0001: Official OverDrive integration only

- Status: Accepted
- Date: 2026-08-14

## Context

The desired product needs access to library loans, audiobook media, lending entitlements, and reading position. The public Checkouts API describes hosted fulfillment but does not document a native watchOS media or DRM interface. OverDrive's API Agreement and general Terms prohibit unauthorized access methods, reverse engineering, extracting/repackaging content, and circumventing technical protections.

## Decision

LibbyWatch will use only documented OverDrive APIs and fulfillment, DRM, and synchronization mechanisms explicitly approved for this product. The prototype will use mocks and independently licensed public-domain audio until written approval is received.

The application will not:

- Inspect or reproduce Libby's private network protocol.
- Scrape OverDrive/Libby services.
- Extract or transcode OverDrive media.
- Circumvent DRM, device, geographic, or lending restrictions.
- Ship production API functionality without OverDrive's written approval.

## Consequences

- Partnership feasibility is the first critical milestone.
- Playback is represented by an interface whose OverDrive implementation remains blocked.
- Engineering can still validate the complete watch experience with legal test fixtures.
- If OverDrive declines or cannot provide a compatible playback mechanism, the standalone player stops; a separately reviewed hosted or system remote-control experience may be considered.
