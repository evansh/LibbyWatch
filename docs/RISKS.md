# Risk register

| Risk | Likelihood | Impact | Mitigation / decision |
|---|---|---:|---|
| OverDrive does not approve native watch playback | High | Critical | Obtain written decision before media integration; keep prototype media-agnostic |
| No watch-compatible DRM/fulfillment mechanism exists | High | Critical | Ask for SDK/API/partner interface; do not reverse engineer; stop or pivot to hosted/remote-control UX |
| General Terms conflict with building a native playback client without separate permission | High | Critical | Seek explicit written permission and legal review |
| Library-specific credentials prevent a broad consumer launch | Medium–High | High | Begin with one pilot library; ask about centralized vendor access |
| Full discovery requirements make a watch-only product impractical | Medium | High | Put rich discovery on iPhone; seek approval for loan-focused watch UX |
| Credential or token exposure | Medium | Critical | Backend-only client secret, vault, redaction, rotation, secret scanning, incident response |
| Offline media remains usable after expiry/return | Medium | Critical | Approved DRM, fail-closed entitlement state, clock-tamper tests, automatic deletion |
| Required session-data collection conflicts with minimization/privacy obligations | Medium | High | Clarify schema/legal basis; document field-level retention; obtain privacy review |
| API/terms change after implementation | High | Medium–High | Adapter boundaries, developer-notice monitoring, scheduled policy review, kill switch |
| Watch storage, battery, networking, or Bluetooth constraints degrade UX | Medium | Medium | Physical-device spikes, chapter downloads, storage budgeting, telemetry and graceful degradation |
| Position sync conflicts with Libby's reading journey | Medium | High | Use only approved sync API; otherwise make limitation explicit and keep local-only prototype state |
| Branding/trademark use is rejected | Low–Medium | Medium | Use official assets/guidelines and submit screens for approval |
| App Store rejects content-access or privacy design | Medium | High | Early policy review, clear account/data controls, TestFlight feedback, proof of content authorization |

## Stop conditions

The project must not progress from licensed test audio to OverDrive content if any of these remain unresolved:

- No written approval for native Apple Watch playback.
- No approved media/DRM/expiration mechanism.
- No approved credential and patron-token architecture.
- No legal owner able to accept the API Agreement.
- No integration-environment access for Circulation testing.
- A required control would necessitate scraping, reverse engineering, extracting content, or bypassing DRM.
