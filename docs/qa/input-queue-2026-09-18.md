# Input queue repair — 18 September 2026

Operator - XyDesk Team; session SESI-20260918-OPERATOR-INPUT-LATENCY.
Base bd75757bfb625974ca76fe89d503c434b40ff5a0.

## Implemented

The previous injection channel held 256 events. `try_send` treated a full
queue as fatal and broke the input handler. It is now a bounded 32-event Tokio
channel: sending awaits capacity without blocking the async runtime, and session
closure cancels that wait. The blocking injector uses `blocking_recv`.

Each drain examines at most 32 ready events. Only adjacent absolute positions
are replaced by their latest position. Keys, clicks, scroll, text and relative
movement are ordering barriers. Relative deltas are not merged because Windows
acceleration may depend on individual events. On close, pending actions are
skipped and the existing InputLease releases only successfully injected holds.

This lowers the pending injection queue's capacity; it does not cap the whole
input path to 32 events. The incoming data-channel queue (128), SCTP buffers,
and up to 32 events in the local drain batch still exist. Backpressure does not
remove bytes already queued on the network. There is no zero-lag guarantee.

## Validation

`cargo test --locked --manifest-path host/Cargo.toml --lib --tests -j2`:
**161 passed**, including five new queue tests. `cargo fmt --check` and
`git diff --check`: PASS. These are Linux tests, not Windows device trials.

New tests verify a 32-position burst becomes one latest absolute position;
ordering barriers preserve keys, relative deltas, clicks and text; a saturated
queue waits and delivers key release plus a subsequent move rather than dying;
session close cancels a saturated send; and receiver disconnect returns failure.

Initial test invocation hit the tool timeout during cold compilation. Its
surviving child overlapped the first retry log. A separate final invocation with
a new log completed cleanly; only that final result is counted above.

## Remaining acceptance work

- Native Windows compilation/runtime and physical mouse/keyboard/trackpad tests.
- Measure input/network and capture/encode/decode latency separately. This is a
  correctness/backlog fix, not proof that the user's perceived delay is solved.
- Automatic supported 16:9 desktop mode selection remains unimplemented. No
  mode/scaling/RDP/driver changes have been made.
- Audio patch from bd75757 still needs its documented Windows/RDP acceptance
  checks; forward-audio freshness and idle cancellation remain open.
- No installer, production deployment, version bump or release was performed.

Release-note material (unpublished): a saturated host input queue no longer
stops receiving controls; queued absolute pointer positions are condensed without
reordering clicks or key releases. No visual change or screenshot claim.
