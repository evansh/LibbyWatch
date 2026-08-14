# MVP definition

## Outcome

A patron can authenticate through an OverDrive-approved flow, see eligible Libby audiobook loans on Apple Watch, stream or download an approved audiobook to the watch, listen without an iPhone nearby, and resume at the correct position. Access stops and local media is deleted when the loan ends or is returned.

## Target user journey

1. The patron installs LibbyWatch and starts sign-in on iPhone or Apple Watch.
2. Authentication occurs on an OverDrive-hosted QR/link flow; LibbyWatch never receives the library-card PIN.
3. The patron sees their audiobook loans and expiration dates.
4. They choose an eligible loan, select Bluetooth headphones, and either play immediately or download for offline use.
5. They can pause, resume, seek, skip, change speed, navigate chapters, and use a sleep timer.
6. Playback continues with the wrist lowered and without the iPhone nearby.
7. Position is checkpointed locally and synchronized through an approved mechanism when connectivity returns.
8. A return, expiration, entitlement change, or DRM instruction immediately prevents further playback and removes inaccessible local media.

## MVP scope

### Authentication and account

- OverDrive QR/link authentication with an OverDrive-hosted consent experience.
- Server-side exchange and refresh of patron tokens; no client secret in either app.
- Support for the authenticated patron collection token and OverDrive Advantage holdings.
- Sign out and deletion of locally stored user data.

### Shelf and title information

- Current audiobook loans, cover art, creator, narrator when supplied, duration when supplied, and expiration.
- Accurate, unaltered OverDrive metadata with a prominent dynamic link to the OverDrive-hosted title record.
- Libby terminology and attribution required by the branding guide.
- Clear unavailable, expired, returned, offline, and degraded-service states.

### Playback

- Only an OverDrive-approved media manifest, SDK, stream, or fulfillment mechanism.
- Long-form background audio over a Bluetooth route.
- Play/pause, 15-second skip, scrub, chapter navigation, 0.75–2.0× speed, and sleep timer.
- Recovery after interruption, route change, app termination, and watch restart.
- Local checkpointing and conflict-safe position synchronization.

### Offline listening

- User-initiated download with progress, storage estimate, cancellation, and retry.
- Encrypted or DRM-protected storage as directed by OverDrive.
- Entitlement validation before playback and periodically while a loan is active.
- Automatic deletion on expiration, return, entitlement revocation, or sign-out.

### Required circulation and discovery surfaces

OverDrive's production-review criteria extend beyond a “loans-only” player. The approval build must therefore provide, on iPhone if the watch surface is too constrained:

- Search by keyword/title/author, sorting, filtering, and subject/featured browsing.
- Availability and correct borrow-versus-hold behavior across supported lending models.
- Borrow, place hold, view holds, fulfill/open, return, and relevant hold-management actions.
- Available title samples through the links supplied by OverDrive.
- Accurate cover art and metadata, dynamic OverDrive title links, and Libby branding.

### Operations, privacy, and support

- Unique, consistent, attributable User-Agent strings.
- Rate limiting, retry with backoff, tolerant decoding, and service-status handling.
- Security telemetry and detection of suspicious activity without using API data to build user profiles.
- Ability to supply required session data to OverDrive on demand.
- A documented 24-hour incident-notification process for suspected permission, DRM, or lending violations.
- User-facing privacy notice, data deletion, support contact, and troubleshooting flow.
- A demo installation and evidence package suitable for OverDrive review/audit.

## Explicit non-goals

- Scraping `libbyapp.com`, capturing private network traffic, or calling undocumented endpoints.
- Extracting, transcoding, repackaging, sharing, or exporting OverDrive audiobook files.
- Circumventing DRM, geographic rules, checkout limits, device limits, or lending periods.
- Shipping against production OverDrive services without written approval.
- Replacing the Libby catalog experience on the watch; complex discovery can live on iPhone.
- Supporting ebooks, magazines, Sora, or non-OverDrive providers in the first release.
- Public announcements about an OverDrive integration before OverDrive approves them.

## Success criteria

- A signed-in patron can start eligible audio on a physical Apple Watch within 30 seconds on a healthy network.
- Playback survives wrist-down/background operation and common audio interruptions.
- Offline playback works in airplane mode after an authorized download.
- Position recovery is within 15 seconds after restart or device handoff.
- Expired or returned content cannot play, and its local media is removed within one minute of detection and no later than the next foreground/background entitlement check.
- Client credentials never appear in app binaries, logs, crash reports, or repository history.
- Accessibility labels, Dynamic Type where applicable, VoiceOver, and reduced-motion behavior pass manual review.
- All mandatory items in the compliance matrix have evidence and an owner.
- OverDrive gives written production-launch approval.

## Go/no-go questions

These require written answers from OverDrive before native playback integration begins:

1. Is standalone Apple Watch playback of `audiobook-overdrive` loans an approved use of the APIs and content licenses?
2. What native media, manifest, SDK, DRM, license-renewal, and secure-storage mechanism must be used?
3. May an approved backend proxy entitlement or media requests, and what data may it retain?
4. What position/bookmark synchronization interface is approved?
5. What offline window, renewal cadence, deletion behavior, device limits, and geographic checks apply?
6. Does the production-review requirement demand full catalog discovery in this product, or may the app focus on authenticated loans while linking to Libby for discovery?
7. Can one vendor integration support multiple libraries centrally, or are library-specific credentials required?
8. What watch-specific Libby branding, title links, analytics/session data, and support expectations apply?
