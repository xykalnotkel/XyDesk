# CONTROL-REFINE — 18 September 2026

**Follow-up:** web-only deployment approved via deploy_web and completed at source87427ae / Worker740345c3. See `control-refine-production-2026-09-18.json`. Pending-deploy statements below describe the source checkpoint. User selected mobile Windows App/RD Client; no RDP settings changed.

Operator - XyDesk Team; SESI-20260918-OPERATOR-CONTROL-REFINE.
Base 0fd4c0f65f785ab1093d7fa720cea7d643c5648e. Web source revision; no host/backend change, version bump, production deploy or RDP setting change at this checkpoint.

## User decisions
- User now prefers making the **source desktop 16:9**, rather than retaining a non-16:9 desktop inside a 16:9 canvas. Actual RDP client/platform and target supported display mode have not been confirmed; no Windows/RDP mode is changed by this web revision.
- Confirmed mouse HUD: left/right, scroll up/down, Windows, direct/trackpad switch. Mapping buttons must be transparent, border + text only.

## Implemented
- Mapping buttons have no fill in normal/pressed/edit/selected states; immediate pointerdown/up injection retained. Labels such as D and F1; CSS transition removed. Keyboard Enter/Space activation works without also forwarding that UI activation key to the desktop.
- Custom action/key/mouse/scroll/shortcut button pickers replace every native select in the mapping editor. Search, selected states, 6-key limit, modifier order, no empty shortcut saves. Added left/right modifiers and media keys to existing F1–F24/numpad/navigation/punctuation/side-mouse/horizontal-wheel choices. Drag, size, orientation-specific persistence and shared key ownership remain.
- Touch tap = left click on release, with no additional click timer. Stationary 500 ms hold = right click once, no preceding/following left click. Movement, multitouch, cancellation and reset cancel the hold timer. Both direct and trackpad supported. Physical mouse remains immediate down/up; direct touch drag begins after movement threshold. HUD drag remains available. The 500 ms gesture recognition is deliberate, **not network latency**.
- Rounded host-mouse HUD: left/right hold, repeatable wheel (100 ms while held), Windows press/release, mode switch and center. OS cursor in the video remains native Windows, not a new fake local arrow. Toast moved above controls and made pointer-transparent after browser testing caught it intercepting HUD input. Landscape HUD avoids the right-side tool panel.
- History rows follow [wallpaper thumbnail][device name / ID] ›. Thumbnail fills its slot with cover; this may crop a non-16:9 wallpaper thumbnail but never changes desktop streaming. Reconnect opens inline pairing for the selected device, preserves /history through connection/disconnect, and tears down on close. Password is not stored and must be entered again. Custom delete confirmation replaces window.confirm on history. Account change clears old history/reconnect state.
- Under client DataChannel congestion (>1024 queued bytes), unsent absolute movement is latest-only, flushed on buffer-low or before mouse transitions. Relative deltas, keys and releases are not coalesced. Healthy input is sent immediately. Metadata changes invalidate unsent coordinates. This does not remove bytes already queued in SCTP or guarantee zero input/video lag. Browser panel includes input buffered bytes and actual coalesced movement count.

## Executed checks
- Web unit tests: **70/70 PASS** (including gesture exclusivity/cancel/reset and bounded movement/order).
- TypeScript + Vite build: PASS. Local default build is not a production OAuth-configured artifact.
- `web/e2e/session_ux_smoke.mjs`: real Chromium CDP touch, React and canvas media fixture at 390×844 and 844×390. Left tap/right hold in both modes, HUD Windows/wheel, held drag, scroll, custom pickers, F1 selection and keydown before pointerup, border-only computed style, chords, orientation UI, automatic wallpaper/privacy, inline history reconnect and cleanup PASS. Zero page errors in both full scenarios.
- Evidence: `control-refine-ui-2026-09-18.json`; screenshots `control-refine-{mapping,editor,history,ui,keyboard}-2026-09-18.png`. Transport/capture are synthetic fixtures, not Windows/Android input/runtime performance.

## Remaining / limits
- No diagnosis of the user's delay without their RTT/jitter/buffer/decode/FPS readings and host encode/capture log. The cause may be source encoding, network, buffering, receiver or more than one. UI handler tests are not glass-to-glass measurements.
- A 1920×1080 Windows desktop removes internal aspect padding when encoded at720p/1080p; a phone viewport wider/narrower than16:9 can still have external contain bars. Do not promise every black margin disappears on every screen.
- Confirm the user's RDP client and supported display size before giving/applying precise display-mode steps; RDP may require a deliberate reconnect. Do not change scaling, drivers or terminate the user's session implicitly.
- This revision needs a separately approved **web-only** deployment. Backend55cdda7c/web8f093d6d and installer37c5eea remain the current delivered package until that approval. No new installer is needed for these web controls.

## Draft release material (not published)

Game mappings leave the desktop visible with border-only buttons and a searchable custom editor. Touch adds a right-click hold gesture, and rounded mouse controls collect wheel, Windows and mode switching in one place. History reconnect keeps the selected device in context rather than opening a blank connect page. Congested mouse movement is bounded, without claiming the network or video pipeline is delay-free.
