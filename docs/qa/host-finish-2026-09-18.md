# Host finish — 18 September 2026

Operator - XyDesk Team, SESI-20260918-OPERATOR-HOST-FINISH.
User explicitly authorized push, build, packaging and deployment for the requested
work. No RDP access, restart/disconnect, scaling change, global credential change,
or driver install was performed on the user's machine.

## Source and behaviour

Functional source: `43fc35ccd849046dc210659ff540f29d11fd0c18`.
Final packaging source: `56317a2339b43c3ecd0bd42d91757a10c79fa9f5` (installer
instructions corrected and reproducible browser fixture added; runtime unchanged).
Includes audio repair bd75757 and input repair ec0f047.

On an authorized session offer, the Windows host requests exact1920×1080 when
H264 negotiation permits, otherwise1280×720. Only modes enumerated by Windows,
matching colour depth/orientation, are candidates; current refresh is preferred.
The request must pass CDS_TEST. A successful API return alone is not success:
physical monitor dimensions are read back. Refusal/unavailable/unverified states
are explicit. Later metadata refresh detects a changed-back mode. No invented
resolution, driver install, registry persistence, or forced reconnect/restart.
A missing exact mode is not replaced by a fabricated mode or a silent fallback.

The new default applies when a user starts the supplied host and connects an
authorized client. It has NOT been applied remotely by this workspace.
`Start-TestHost.ps1 -KeepDesktopResolution` / `--keep-desktop-resolution` opts out.
The process does not automatically restore the earlier desktop mode on exit.
It does not repeatedly fight RDP if RDP reasserts its chosen mode. The request
runs at session negotiation, not on every frame or every monitor-selection event.

Web Gambar panel reports requested/observed dimensions and status, while decoded
video dimensions remain separate. A16:9 source cannot fill a non16:9 viewport
without either cropping, stretching, or leaving space. Existing proportional
rendering and native cursor/input mapping are retained.

## Audio/input regression scope

- Real complete WASAPI mix allocation, 960-frame streaming PCM packetizer,
  correct packet drain/silence and device-frame render accounting.
- No mic activation deadline; bounded phone-mic queue; sender replaceTrack and
  cleanup on disable/permission races. Virtual recording endpoint is required;
  there is no speaker fallback or driver installation.
- Full injection queues wait without blocking the async runtime instead of
  stopping input. Adjacent absolute positions coalesce; key/click/release/text
  and relative movements remain ordering barriers.
- Windows native tests now exercise actual vendored Opus encode/decode for
  44.1/48/96 kHz source packetization; these do not open physical WASAPI devices.

## Evidence

- Functional-source Windows run35403290371 succeeded: Linux164, Windows153,
  including real Opus roundtrip. Its NSIS run35403760349 also succeeded, but
  the candidate was superseded after stale installed instructions were found.
- Final installer run IDs, hashes and final-source tests are recorded in
  `host-finish-package-2026-09-18.json` after the final artifact is verified.
- Web76 tests and production-config build PASS; actual deployed assets checked
  byte-for-byte. Existing public OAuth client and Worker bindings preserved.
- Real Chromium React handlers at390×844 and844×390: controls, mapping/editor,
  wallpaper privacy, playback retry/mute, history and inline reconnect PASS.
  Transport/canvas are fixtures, not physical Windows/Android proof.
- Added rejection-state panel assertion and screenshot. A fixture initially
  referenced a viewport variable outside its loop; the test was corrected and
  rerun successfully. No product change was needed for that fixture error.
- Production browser history/reconnect smoke at both sizes PASS using isolated
  local guest data, no pairing, password submission or account writes.
- Web production version1d669576-3d69-4fb5-8019-ad7c41d80942, prior rollback
  version740345c3-356f-4f25-bc63-634c2ebe1401. Backend55cdda7c unchanged.
  Details: `host-finish-production-2026-09-18.json`.

## Deployment verification notes

Initial dry-run setup used a wrong backend script name and a missing npm prefix
directory; both failed before deployment and were corrected. An immediate
post-upload asset fetch briefly differed during propagation; subsequent exact
asset checks on both hostnames passed. Health/history probes initially used
incorrect paths; final documented /healthz, /auth/session-history and protected
signal-token probes returned200/401/401. No access-control workaround was used.

## Boundaries and follow-up

Native compilation/unit/codec tests and installer lifecycle tests are not a
field test of the user's PC, mic hardware, desktop driver or internet path.
Actual RDP mode acceptance, audible playback, app-recorded mic speech, raw-input
compatibility and end-to-end latency remain unmeasured. No zero-lag,1080p60 or
GPU availability claim is made. Virtual cable installation/app selection may
still be needed; the installer intentionally does not perform it.

Forward audio's existing blocking bridge/quiet-source cancellation, COM lifetime
balancing, device hotplug/reopen and more latency profiling remain engineering
follow-ups. This release of the test package does not claim they were implemented.
The preceding audio/input QA documents retain their detailed implementation scope.

No version bump, official release tag, APK release or signed-installer claim.
This is a new source-identified Windows host test package and a web update.

## Unpublished release-note material

Host audio now respects the endpoint format; mic can be enabled later and toggled
without new negotiation. Saturated host input no longer stops controls. Desktop
16:9 is requested only when supported, with honest refusal/readback status.
Instructions now match these defaults. Browser fixture screenshots are labelled
QA evidence, not photos of the user's desktop or proof of physical performance.
