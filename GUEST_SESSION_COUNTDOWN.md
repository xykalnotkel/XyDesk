# Guest Session Countdown - Task #29

## Status
✅ **SELESAI** — 2026-09-03

## Deskripsi
Implementasi countdown 2 jam untuk sesi tamu (guest session) yang menampilkan total durasi dan sisa waktu, matching dengan web version.

## Perubahan File

### 1. `lib/features/session/session_page.dart`
**Ditambahkan:**
- `_guestSessionTotal = 7200` (2 jam dalam detik)
- `_isGuestSession` getter untuk cek apakah user tamu
- Pass `isGuestSession` dan `guestSessionTotal` ke `SessionControlPanel`

```dart
static const int _guestSessionTotal = 2 * 60 * 60; // 2 jam
bool get _isGuestSession => ref.read(authProvider).isGuest;
```

### 2. `lib/features/session/session_panels.dart`
**SessionControlPanel:**
- Tambah parameter `isGuestSession` dan `guestSessionTotal`
- Pass ke `_SessionPanel`

**_SessionPanel:**
- Tambah countdown card yang muncul hanya untuk sesi tamu
- Hitung `remaining = guestSessionTotal - elapsedSec`
- 3 state visual:
  - **Normal**: Icon clock, warna neutral
  - **Critical** (≤5 menit): Icon timer, warna warning (orange), pesan peringatan
  - **Expired** (≤0): Icon circleX, warna danger (red), pesan "sesi berakhir"
- Display "TOTAL" dan "SISA" dengan format `Xj Xm Xd`
- Border dan background berubah sesuai state

## Visual Design

### Normal State (sisa > 5 menit)
```
┌─────────────────────────────────┐
│ ⏰ Sesi tamu                    │
├─────────────────────────────────┤
│ TOTAL          │  SISA          │
│ 2j 00m 00d     │  1j 45m 30d    │
└─────────────────────────────────┘
```

### Critical State (≤5 menit)
```
┌─────────────────────────────────┐
│ ⏱️ Sesaat lagi berakhir!        │
├─────────────────────────────────┤
│ TOTAL          │  SISA          │
│ 2j 00m 00d     │  0j 04m 59d    │
├─────────────────────────────────┤
│ Sesi akan berakhir dalam kurang │
│ dari 5 menit. Segera simpan     │
│ pekerjaanmu.                    │
└─────────────────────────────────┘
```
**Style:** Background orange tint, border orange

### Expired State (≤0)
```
┌─────────────────────────────────┐
│ ❌ Sesi tamu berakhir           │
├─────────────────────────────────┤
│ TOTAL          │  SISA          │
│ 2j 00m 00d     │  00m 00d       │
├─────────────────────────────────┤
│ Sesi tamu telah berakhir.       │
│ Silakan login untuk melanjutkan.│
└─────────────────────────────────┘
```
**Style:** Background red tint, border red, text red

## Logic Flow

```
elapsedSec (dari session_page.dart Timer)
  ↓
isGuestSession? 
  ↓ YES
remaining = guestSessionTotal - elapsedSec
  ↓
remaining > 300? → Normal state
remaining ≤ 300 && > 0? → Critical state (warning)
remaining ≤ 0? → Expired state (danger)
```

## Testing Checklist

- [ ] Login sebagai tamu → masuk session → countdown muncul
- [ ] Countdown menampilkan "Total: 2j 00m 00d" dengan benar
- [ ] Countdown "Sisa" berkurang setiap detik
- [ ] Saat sisa ≤ 5 menit → card berubah warna orange + pesan warning
- [ ] Saat sisa = 0 → card berubah warna red + pesan expired
- [ ] Login sebagai user biasa → countdown TIDAK muncul
- [ ] Format waktu benar: `Xj Xm Xd` dengan padding 2 digit
- [ ] Countdown tetap update saat user pindah tab di panel
- [ ] Countdown tetap update saat app di-background (PiP mode)

## Notes

- Countdown **hanya muncul** untuk guest session (`authProvider.isGuest == true`)
- User biasa (logged in) tidak melihat countdown card
- Countdown dihitung dari `elapsedSec` yang sudah ada (timer session)
- Tidak ada auto-disconnect saat expired (user harus manual disconnect atau backend yang terminate)
- Design matching dengan web version (Total/Sisa display)

## Related Files

- `lib/features/auth/auth_controller.dart` — `isGuest` property
- `lib/features/session/session_page.dart` — elapsedSec timer
- `lib/features/session/session_panels.dart` — UI countdown

## Backend Requirements

Tidak ada. Countdown dihitung client-side dari `elapsedSec` yang sudah di-track oleh session_page.dart.

## Future Enhancements

1. **Auto-disconnect**: Saat remaining = 0, otomatis disconnect dan navigate ke home
2. **Push notification**: Warning notification saat sisa 10 menit, 5 menit, 1 menit
3. **Extend session**: Tombol "Perpanjang sesi" yang navigate ke login/register page
4. **Persistent timer**: Simpan start time di SharedPreferences, resume setelah app restart
5. **Server-side validation**: Backend juga track guest session duration dan force disconnect
