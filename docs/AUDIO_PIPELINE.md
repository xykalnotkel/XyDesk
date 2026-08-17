# XyDesk audio and voice pipeline

## Current implementation status

The current Flutter client and Rust host do **not** transport audio. The host
publishes an H.264 video track and receives the input data channel only. The UI
therefore treats `audioEnabled` and `micPassthrough` as saved preferences, not
as proof that a media path is active.

`lib/features/session/media_capabilities.dart` is the source of runtime truth
for the UI. In the current build both media paths are `notImplemented`:

- PC system audio to the client
- Phone microphone to a selectable Windows microphone endpoint

The controls are included in the free beta experience, but entitlement and
technical availability are separate concepts. `freeDuringBeta` must never be
used as an audio-ready signal.

## Target media graph

### PC system audio to phone

```text
Windows render endpoint
  -> WASAPI loopback capture
  -> channel conversion / resampling (48 kHz)
  -> Opus encoder
  -> WebRTC RTP audio track (host -> client)
  -> jitter buffer / Opus decoder
  -> client audio output
```

Host responsibilities:

1. Enumerate active Windows render endpoints and track the default endpoint.
2. Capture the selected endpoint with WASAPI loopback.
3. Convert the captured format to the WebRTC audio format without blocking the
   video capture or signaling loops.
4. Publish a real Opus audio track and expose negotiated state to the client.
5. Handle device changes, endpoint removal, silence, mute, and reconnects.

Client responsibilities:

1. Receive and render the negotiated remote audio track.
2. Select the output route supported by the operating system.
3. Apply user volume/mute without describing a preference as an active stream.
4. Surface real track, packet-loss, jitter-buffer, and underrun state.

### Phone microphone to Windows

```text
Phone microphone
  -> high-pass filter
  -> acoustic echo cancellation (AEC)
  -> noise suppression (NS)
  -> automatic gain control (AGC, optional)
  -> input gain / send level
  -> Opus encoder
  -> WebRTC RTP audio track (client -> host)
  -> jitter buffer / Opus decoder
  -> XyDesk virtual microphone endpoint
  -> game / Discord / conferencing application
```

AEC must receive a reference of the audio rendered by the phone. Processing
options are capture constraints/runtime audio-processing settings, not visual
filters. Their actual negotiated values must be reported back to the UI.

The host must not inject decoded microphone PCM into a speaker/render device.
It must write to the backing stream of a Windows virtual capture endpoint so
applications see **XyDesk Virtual Microphone** as a normal microphone.

## Windows virtual microphone boundary

The virtual microphone is a separately installed, signed Windows component.
It is not part of the Flutter app and should not be hidden inside the Rust
session module.

Recommended boundary:

```text
host/session audio receiver
  -> bounded PCM ring buffer
  -> versioned local IPC contract
  -> signed virtual-audio service/driver
  -> Windows capture endpoint
```

The component needs:

- a stable 48 kHz PCM contract and explicit channel layout;
- bounded buffering with overrun/underrun counters;
- access control so unrelated local processes cannot inject microphone audio;
- lifecycle handling when the host exits or the phone disconnects;
- an installer, upgrade/rollback path, and uninstall cleanup;
- production driver signing and Windows compatibility validation.

A development prototype may begin from Microsoft's virtual-audio driver
patterns, but shipping requires a supported, signed package and legal/security
review. The UI must show “Virtual Mic required” until the endpoint is installed
and opened successfully.

## Latency modes

The UI exposes three desired modes. Final values must be tuned using measured
end-to-end latency rather than hard-coded marketing numbers.

| Mode | Intended behavior |
|---|---|
| Gaming | Small capture and jitter buffers; recover quickly; tolerate quality variation |
| Balanced | Moderate jitter protection and normal audio processing |
| Quality | Larger safety margin and stronger processing where useful |

AEC, NS, AGC, Opus frame size, network jitter, and the virtual-device buffer
all contribute to latency. Report the measured path when telemetry exists;
never display sample/demo milliseconds as live data.

## Capability negotiation

The host should include a versioned media-capability object in session
signaling. At minimum it should describe:

- system-audio capture availability and selected render endpoint;
- remote and local Opus track states;
- microphone permission/capture state on the client;
- supported AEC/NS/AGC controls and their applied values;
- virtual microphone installation/open state;
- output/input device identifiers that are safe to display;
- recoverable error code and human-readable remediation.

Suggested lifecycle for each path:

```text
notImplemented -> available -> active
                       |          |
                       +-> error <-+
```

A saved request does not change this lifecycle. The UI may say “preference
saved”, but only negotiated `active` state may say audio is playing or the
microphone is being sent.

## Beta entitlement

During beta, both audio paths and all processing controls are included without
a subscription. Future gating belongs on the server/host authorization path,
not only in Flutter widgets. Capability negotiation should eventually combine:

1. build/platform support;
2. installed host components;
3. permissions and device availability;
4. session transport state;
5. server-issued entitlement.

Until a future product decision changes this, entitlement must remain
permissive and must not disable otherwise working beta audio controls.

## Delivery sequence

1. Add a client WebRTC media implementation and remote Opus playback.
2. Add host WASAPI loopback capture and publish the host-to-client Opus track.
3. Add phone microphone capture, permission flow, and AEC/NS/AGC reporting.
4. Add the client-to-host Opus track and host decode/jitter handling.
5. Prototype the local PCM/IPC boundary and virtual capture endpoint.
6. Package and sign the Windows component; add install/repair diagnostics.
7. Replace `currentBuild` constants with negotiated runtime capability state.
8. Add measured telemetry, recovery flows, device pickers, and latency tuning.

Each stage must keep the UI honest when only part of the graph is available.
