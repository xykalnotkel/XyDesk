# Virtual720 — dedicated source, not a scaled RDP screenshot

1. Install this updated host package. Audio and normal-host behaviour remain
   available through **XyDesk Host Test**.
2. For **XyDesk Virtual720**, first run `Setup-VirtualDisplay.ps1 -VerifyOnly`.
   To provision a new adapter, explicitly run `-Install` in Administrator
   PowerShell and approve its confirmation. It downloads a pinned upstream
   package, checks SHA256 and the Windows Authenticode catalog trust result.
3. Existing `C:\VirtualDisplayDriver` or a detected existing adapter is preserved:
   setup refuses to overwrite it. Use its owner's VDD Control to configure1280×720.
4. Run `xydesk-host.exe --display-probe`. This read-only JSON contains adapter and
   monitor information, not credentials. **visibleVirtual** must include the
   monitor in the same session as the host.
5. Open **XyDesk Virtual720** / `Start-Virtual720.ps1`. Exactly one known virtual
   source is required. More than one requires direct engine use with
   `--virtual-display-device '\\.\DISPLAYn'` and normal host launch arguments.

The host requests and verifies1280×720 on the virtual monitor, fixes its video
canvas to720p, rejects other monitor selections, and does not fall back to an
RDP/physical screen. If dimensions/identity change, frames are withheld or the
stream ends. This is a fail-closed profile, not a promise that Windows can never
change its topology. Restart the XyDesk host after topology/index changes.

## Critical RDP limitation

An installed adapter can belong to the console desktop while an active RDP
session exposes only its own virtual monitor. This package does not bypass
Windows session isolation, move the host to another session, unlock a desktop,
move apps between monitors, make a monitor primary, or disconnect RDP.
If `visibleVirtual` is empty in RDP, **stop**: installing again or changing bitrate
will not fix that. An interactive host session where the virtual monitor is
visible is needed. No automatic tscon/reboot/remote-access change is performed.

A16:9 source removes source-aspect padding. A non16:9 phone viewport still needs
space, crop, or stretch to display the same image; this package retains proportions.

## Installation boundary and rollback

Driver source: VirtualDrivers/Virtual-Display-Driver release25.7.23,
`VirtualDisplayDriver-x86.Driver.Only.zip`; the contained DLL is AMD64 despite
its archive name. SHA256:
`e24210692b442b39af763536330ce78b423f19342b7a7792c26de3944e418b3a`.
Source/license: https://github.com/VirtualDrivers/Virtual-Display-Driver
No upstream installer is silently executed, no certificates imported, and no
signing/secure-boot policy is bypassed. Windows can still reject device loading;
setup stops and reports failure. Setup success is NOT capture/RDP proof.

Setup creates `C:\VirtualDisplayDriver\xydesk-owner.json` with the exact newly
created device instance. On failure it attempts to remove only that new instance;
staged driver/config files remain for diagnosis. No restart is performed.

To undo a successful install, stop XyDesk Virtual720 first. In Administrator
PowerShell, inspect xydesk-owner.json and Device Manager, then remove **that exact
instance**, not a wildcard: `pnputil /remove-device "<instanceId>"`.
Only delete the XyDesk-created config directory when no other program uses it.
The driver package may remain staged in Driver Store; remove it only via Windows
supported driver management after confirming it is unused. Host uninstall does
not remove shared drivers. Do not use global device-disable or testsigning commands.

This package has no claim of physical RDP acceptance, protected-desktop capture,
zero latency, or automatic app migration. Native tests and signature checks are
reported separately from actual adapter installation/capture on a user's machine.

## Layar primary (2026-09-19)

Console-Primary.ps1 menjadikan monitor virtual 1280x720 layar primary pada sesi pemanggil supaya jendela aplikasi baru dan ikon desktop muncul di layar yang di-stream. Dipanggil otomatis oleh Start-TestHost.ps1 -VirtualDisplay720p sebelum engine berjalan, idempoten, tanpa reboot, dan tidak mengubah resolusi maupun sesi lain.
