# LETTERBOX-LATENCY — source checkpoint, 18 September 2026

Session: SESI-20260918-OPERATOR-LETTERBOX-LATENCY. Operator - XyDesk Team.
Base: 6817fb803f019674b6daf97bb708d9d129849b52. Version remains 6.8.5.
**Source validated locally; new Windows binary/NSIS not built, production not deployed.**
The previous installer 4a3e75a does not contain this revision.

## Implemented

- HD output canvases are exactly 1280×720 / 1920×1080, subject to the negotiated decoder level. Desktop content keeps its aspect ratio, without crop, stretch, display-mode change, or artificial upscale. A 2336×1080 source becomes content 1280×592 at (0,64), or 1920×888 at (0,96). Smaller sources remain centered without invented detail. Native mode retains source detail within 4096×2160 and 15 fps; 720/1080 modes have a 30 fps software ceiling, not a guaranteed throughput.
- Content rectangle travels in existing video metadata. Both host input mapping and web direct/trackpad mapping account for encoded padding. Host rejects absolute positions in bars and subsequent button-down; releases remain allowed. Legacy frame-normalized clients still map through the host.
- WGC keeps its native cursor. GDI composites the Windows cursor (GetCursorInfo / CopyIcon / GetIconInfo / DrawIconEx), including hotspot, clipping, and monochrome mask behavior, into a bounded cursor-sized BGRA tile. DXGI composites only when PointerPosition.Visible indicates a separate pointer. DXGI output is converted BGRA→RGBA before the shared encoder. Owned bitmap/icon/DC handles are released. Web no longer renders a local replacement arrow or exposes its size control.
- Wallpaper is requested automatically once per connected session after the control metadata arrives. Visible opt-out remains available. Revoking it cancels client reassembly; late chunks cannot save a preview. Session/account token checks and disconnect cancellation remain. No app screenshot or window minimization. Previously saved previews are not erased by the opt-out; delete them in history if needed.
- Wallpaper background sends wait below 32 KiB channel buffering, pace chunks by 80 ms, and have a 12-second send budget. This bounds background queuing; it is not bandwidth adaptation or a guarantee on poor links. Client cancellation does not undo bytes already sent or stop the already-started bounded Windows wallpaper decode.
- Encoded frame sequence numbers detect gaps caused by bounded-queue drops. Predictive frames are withheld until a fresh IDR. Frames waiting over 100 ms **after encode** are discarded; slow encode itself is not mistaken for old queued work. Bridge uses nonblocking try_send, and capture queue overflow requests a keyframe.
- RTP timestamps follow capture-time deltas, including skipped frames, instead of a fixed nominal frame interval. webrtc 0.11 advances timestamps after packetization; empty samples advance its clock without sending packets, before the actual frame. Rescue IDRs remain outside live-frame latency measurements.
- Host control API now separates latest encodeMs / queueMs / rtpWriteMs and droppedFrames. latencyMs includes capture through completed track-write; it is **not receiver arrival or glass-to-glass latency**. Browser diagnostics separate network RTT, RTP jitter, interval jitter-buffer residence / decoded-frame time / loss, and cumulative dropped/frozen frames. Unsupported counters show unavailable, not fabricated zeroes. Optional browser jitterBufferTarget=40 ms is a hint only.

## Executed validation

- `cargo test --locked --manifest-path host/Cargo.toml -j 2`: **152 passed** (143 library, 5 main, 4 integration), zero failures. Includes actual OpenH264 decode and black-padding pixel checks, gap/IDR recovery policy, and real RTP timestamp delta: a 120 ms capture interval yields 10,800 ticks at 90 kHz.
- Narrow actual-source Windows cross-check: `cargo check --manifest-path tool/geometry-check/Cargo.toml --target x86_64-pc-windows-gnu -j 1`: PASS, including native cursor, GDI, DXGI, input, geometry, NVENC and wallpaper modules. **Not a full Windows link/runtime test.**
- Web unit tests: **66 passed**, including encoded-content mapping and independent interval jitter/decode/loss metrics. TypeScript + Vite build PASS (not a production OAuth-configured deployment artifact).
- Real Chromium ↔ Rust production Session / SoftwareEncoder / pump_video: Level 5.1, at least 3 decoded frames in each mode, actual dimensions **1920×1080**, **2336×1080**, **1280×720**. Source is 2336×1080 in all three cases. Encoded top-padding pixels black in both HD modes, content nonblack. Evidence: `letterbox-chromium-2026-09-18.json/png`.
- Real React + Chromium touch at 390×844 and 844×390: direct/trackpad, click/drag/release/scroll, fullscreen, keyboard/chords/mapping, hidden local cursor, automatic wallpaper exactly once despite duplicate metadata, independent 1920×1080 wallpaper, and history PASS. Additional opt-out-before-connect and revoke-pending-transfer cases PASS. No page errors in the two full interaction scenarios. Transport and pixels are fixtures, not Windows input injection. Evidence: `letterbox-ui-2026-09-18.json` and screenshots.
- No dependencies added, no version bump, no backend/auth/OAuth changes. Existing license lockfiles unchanged.

## Boundaries / remaining gates

1. New dedicated Windows compile/test and source-bound NSIS install/reinstall/uninstall validation still require dispatch approval. Do not reuse the prior executable as this revision.
2. Native cursor shape/hotspot, custom/animated cursors, DPI/multi-monitor, rotated DXGI surfaces, RDP reconnect/resize, and real game input need Windows/manual runtime verification. Secure desktop/UAC/raw-input game constraints remain.
3. Metadata is not acknowledged per displayed video frame. Switching monitor or changing content geometry can still have a short old-frame/new-metadata window. This revision does not claim a frame-synchronized geometry ACK.
4. No guaranteed 1080p60, zero jitter, or <40 ms end-to-end. Software encode, GPU availability, network loss/RTT, decode and display refresh all matter. Native “super HD” means supported source resolution, not added detail. NVENC currently falls back to software when resizing/letterboxing is needed; AMF/QSV and GPU composition are not implemented here.
5. Browser JSON metrics are short local synthetic samples, not network/VM/Android benchmarks. Do not generalize their latency to the user's connection. No automatic congestion/bitrate controller has been added; use actual diagnostics and lower target bitrate/resolution when necessary.
6. Production web/backend are unchanged. A new host alone does not update the production web controls or wallpaper history endpoints. Deploy requires separate explicit approval and preservation of existing public OAuth configuration/bindings.

## Draft release material (not published)

Desktop streaming can use exact HD/Full HD canvases while retaining the whole desktop. The Windows cursor is carried in the video instead of a replacement local arrow. Connection history can obtain a wallpaper-only preview automatically, with an opt-out. Frame-gap recovery, capture-based RTP timing and separate network/decode diagnostics make latency failures easier to identify. These changes remain a test package until Windows validation and manual device checks complete; no zero-lag claim is made.
