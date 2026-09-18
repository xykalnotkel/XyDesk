# Audio repair — source validation, 18 September 2026

Session: `SESI-20260918-OPERATOR-AUDIO-REPAIR`  
Contributor: Operator - XyDesk Team  
Base: `add67c0a564d9e87b9d712d9271e06226060edb4`

## Confirmed user context

RDP app audio works; XyDesk audio is inaudible. Desired direction is PC sound
→ phone and phone mic → input for Windows applications, not speaker playback.
No physical device was accessed or changed in this validation.

## Implemented

- WASAPI initialization retains the complete `GetMixFormat` allocation,
  including WAVEFORMATEXTENSIBLE extension bytes. RAII frees it on failure
  as well as success; unsupported/truncated formats fail explicitly.
- A streaming resampler retains fractional phase across capture buffers and
  emits exactly 960 frames at 48 kHz per Opus packet. It replaces the incorrect
  assumption that 960 source frames are always 20 ms.
- Capture drains by repeatedly asking `GetNextPacketSize`, which reports
  **frames**, not a number of packets. Both capture paths handle silent/null
  buffers; device buffers are released before conversion/encoding.
- Phone mic receiver remains available past the former ~30-second deadline,
  checks session closure even while RTP is idle, and can observe a new remote
  track. The unbounded intermediary queue is removed: one four-packet queue
  feeds the decoder. A full queue drops the incoming packet rather than
  accumulating unlimited history. This is bounded FIFO, not latest-first.
- Render duration request corrected from one second to 100 ms. Device-format
  PCM is queued after conversion, and render space is counted in device frames,
  not divided by channel count. PCM is bounded to 100 ms, dropping old PCM;
  decoder accepts up to 120 ms Opus packets. Receiver disconnect stops rendering.
- Phone mic requires an existing virtual-cable render endpoint. Missing or
  inaccessible endpoints do not fall back to host speakers. No driver install.
  Optional `micInput` metadata reports endpoint detection; web reports a missing
  endpoint before asking phone permission. Old hosts lacking the field remain
  compatible. Endpoint detection does not prove driver health or app selection.
- Web mic uses the negotiated sender's `replaceTrack`, detaches on disable,
  serializes sender updates, and cleans up late permission/replacement results.

## Executed checks

| Check | Result | Scope |
|---|---|---|
| `cargo test --locked --manifest-path host/Cargo.toml --lib --tests -j2` | **156 passed** | Linux; 146 library + 10 binary/integration tests |
| `cargo fmt --manifest-path host/Cargo.toml --check` | PASS | Host formatting |
| `cargo check --locked --manifest-path tool/audio-check/Cargo.toml --target x86_64-pc-windows-gnu -j1` | PASS | Real audio/PCM/Opus source Windows ABI compile; virtual routing stubbed; six existing warnings |
| `npm test --prefix web` (Node 22) | **76 passed** | Includes six new actual RtcSession microphone tests |
| `npm run build --prefix web` | PASS | Local TypeScript/Vite validation, not production deployment |

New Rust tests cover exact packet counts, chunk-boundary invariance for
8/11.025/22.05/44.1/48/96 kHz with mono/stereo/six-channel sources, silence,
and device-frame accounting at 44.1/48/96 kHz. A real-time lifecycle test waits
**32 seconds** with no remote mic, verifies the receiver is still alive, then
closes the session and verifies task exit within two seconds. This test does
**not** transmit live microphone RTP or exercise a physical WASAPI device.

Web tests cover repeated enable/disable without `addTrack`, late permission
on session close, double enable, rejected replacement cleanup, missing virtual
input/old-host compatibility, and disable during an in-flight replacement.

## Not proven or unfinished

- No Windows runtime/device test, actual Opus encode/decode roundtrip, RDP audio
  audition, mobile-browser microphone trial, or Discord/Zoom/game recording test.
  The compile-only checker is not a complete Windows host build.
- Actual endpoint selection/permissions and browser playback must be verified
  on the user's environment after a separately authorized test package.
- No measured input RTT/encode/decode or glass-to-glass latency. Keyboard and
  trackpad complaints remain open. Host injection queue overflow and video
  encode latency need their own changes/tests; this patch does not fix them.
- Automatic supported 16:9 desktop mode selection remains unimplemented. No
  Windows mode, scaling, driver, RDP connection or restart changed. A 16:9 source
  cannot fill a non-16:9 viewport without cropping/stretching.
- Forward-audio capture still has the existing blocking bounded queue/bridge;
  quiet-source cancellation and backlog freshness remain follow-up work. COM
  initialization balancing and device hotplug/reopen also remain follow-ups.
- The render buffer is a requested duration, not measured end-to-end latency;
  device/backend may round it. Four Opus packets can represent more than 80 ms
  when sender packet durations exceed 20 ms.
- No version bump, installer, Windows Build/Release dispatch, production deploy,
  OAuth/config change, or secret change. Live web/backend remain the previous
  CONTROL-REFINE rollout. Existing installer does not contain this patch.

## Windows acceptance gate before replacement installer is trusted

1. Complete native Windows build/tests; exercise regular WAVEFORMATEX and
   EXTENSIBLE float/PCM sources and both 44.1/48 kHz devices where available.
2. In the user's RDP session, play PC audio and confirm browser RTP bytes/energy
   and audible playback after explicit sound activation.
3. Enable phone mic after >32 seconds, then disable/re-enable repeatedly.
4. With a user-approved existing cable, choose its recording endpoint in the
   target app and confirm actual recorded speech, not just an activity meter.
5. Without a cable, verify an explicit unavailable message and no speaker leak.
6. Disconnect while audio/mic are idle and active; monitor thread/device release.

## Release-note material (not published)

Audio processing now respects the Windows device format, including non-48 kHz
sources. Phone microphone activation no longer expires shortly after connecting,
and repeated toggles reuse the existing connection. Missing Windows virtual
input is explained instead of playing phone mic through PC speakers. No visual
layout change; no release screenshot or field-success claim is supplied.
