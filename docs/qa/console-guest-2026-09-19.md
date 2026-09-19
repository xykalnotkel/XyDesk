# Console / guest repair — 2026-09-19

Operator authorization: fix cursor/reconnect; no guest session duration limit; browser remembers host access until site data cleared/forgotten or host owner revokes. Technical access tickets may rotate automatically. No permanent administrator/host bearer token in browser.

## Field evidence supplied by user
- Driver ROOT\MTTVDD\0000 + MTT1337 monitor ready. RDP kall/session1 cannot see virtual monitor; runneradmin/console2 sees DISPLAY3 at1280×720@60, origin1024,0, with primary Hyper-V1024×768.
- User confirms streaming720 works. Trackpad clicks work but pointer invisible.
- Cursor probe in console2: flags2 (suppressed), null shape, position2140,45 inside DISPLAY3. Not an out-of-monitor input error. Sample position stationary; test does not prove motion timing.
- Intermittent disconnect and peer-offline; root cause of first transport loss unproven. Previous one-shot launcher lacked an engine supervisor/token renewal; web retried only ended, not transport error.

## Changes and limits
- SendInput virtual-desktop absolute pixel centers, including negative origins. Native cursor composition handles suppression with Windows standard arrow only if current shape missing. Deliberately hidden application cursor(flags0) remains hidden. Standard arrow is a fallback, not proof of current application I-beam shape. No client-side fabricated cursor.
- Managed host authentication renews a short ticket per connection with stored device refresh credential. Uses only official HTTPS endpoint and existing identity; no global secret/password rotation. Heartbeat detects silent signaling loss. Console worker supervises exits, owns children via kill-on-close Job Object, and records allow-listed operational messages without tokens/passwords.
- Explicit console manager Start/Stop/Status/Credentials/RevokeAccess. No scheduled triggers/boot autostart, RDP disconnect, session transfer, reboot, service or driver changes. Stop disables its own task and only cleans matching account/path/console processes; no global taskkill.
- Browser-only guest identity refresh credential is purpose-bound and cannot serve as JWT/host/admin credential. Fresh short guest JWT and signaling ticket required on admission; admitted guest media has no duration timer. Member expiry/version/bans unchanged.
- Host-issued256-bit browser grant stored in localStorage, only hash persisted on host; 64 grants maximum, no silent eviction. Password never saved in browser history or localStorage. Owner --revoke-remembered clears grants; changing password revokes them. Active remembered connections checked every20sec. Grant rejection removes local copy, does not auto-retry revoked authorization. Deleting only HTTP/image cache does not clear localStorage; private browsing/browser eviction may lose access sooner.
- Existing hosts remain compatible but cannot issue saved grants until upgraded. Fresh guest pairing required once. Remembering browser access is explicitly shown; user can opt out/forget. Shared browser profiles can use saved grants; do not enable on shared devices.
- Web automatic transport retry capped10 attempts, delay2s increasing to30s. No re-pair on owner/account revocation or manual stop. Guest session duration is not the same as network availability or unlimited retry budget.

## Validation
Linux176, web84, backend188, NSIS builder7 PASS. Browser controls (two viewports) and remembered-access/revoke fixture PASS. Real Worker/SQLite/WebSocket runtime authorization PASS. Windows first run35420994164 caught two missing mouse-flag imports; fixed before delivery, rerun pending. Backend/web deployed separately after tests; package proof pending. No claim of Windows field cursor/reconnect success before the new binary is installed by user.
