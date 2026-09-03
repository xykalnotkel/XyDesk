# Control Mapping & Profile Improvements

## Status
✅ **SELESAI** — 2026-09-03

## Deskripsi
Implementasi control mapping system yang bisa disimpan per akun, virtual keyboard yang lebih responsif, dan perbaikan profile avatar dengan foto Google/email.

## Perubahan

### 1. Control Mapping System
**File baru:** `lib/features/session/control_mapping.dart`

- **ControlMapping model**: Mapping dari input (keyboard/joystick/mouse/touch) ke aksi
- **ControlProfile model**: Kumpulan mapping yang bisa disimpan per akun
- **ControlMappingManager**: StateNotifier untuk CRUD profil mapping per akun (scoped)
- **Default profiles**:
  - Gaming Default: WASD + mouse (FPS style)
  - Desktop Default: Ctrl+C/V/X/Z dll (produktivitas)

**File baru:** `lib/features/session/control_mapping_page.dart`

- UI untuk melihat, edit, tambah, hapus profil mapping
- 2 tab: "Daftar Mapping" dan "Preview"
- Profile card dengan info jumlah mapping, icon, dan quick actions
- Detail view untuk setiap mapping (input key → action)

### 2. Virtual Keyboard Improvements
**File:** `lib/features/session/virtual_keyboard.dart`

- Touch target lebih besar (height: 44px, sebelumnya 40px)
- Border radius lebih besar (8px) untuk feel yang lebih natural
- Animated scale yang lebih smooth (Curves.easeOutCubic, 60ms)
- Visual feedback yang lebih jelas saat ditekan:
  - Border thickness 1.5px saat pressed
  - Background color accent dengan alpha 0.45
  - Shadow hilang saat pressed (simulasi tombol ditekan)
- Haptic feedback tetap `lightImpact()` untuk konsistensi

### 3. Profile Avatar dengan Foto Google
**File:** `lib/widgets/profile_avatar.dart`

- Tambah parameter `pictureUrl` untuk foto dari Google/backend
- Prioritas loading:
  1. pictureUrl (foto Google/account)
  2. Preset DiceBear (dari local preference)
  3. URL custom (dari local preference)
  4. Fallback ke inisial nama

**File:** `lib/features/account/account_page.dart`
- Pass `user.picture` ke `_ProfileHero` → `ProfileAvatar`

**File:** `lib/app.dart`
- Pass `user.picture` ke `TopbarAvatarButton`

### 4. Guest Identity (Nama Random Manusia)
**File baru:** `lib/features/auth/guest_identity.dart`

- `generateGuestName()`: Menghasilkan nama manusia Indonesia yang natural
  - Contoh: "Aditya Pratama", "Kirana Wijaya", "Budi Santoso"
  - 64 nama depan + 31 nama belakang = 1984 kombinasi
- `generateGuestAvatarSeed()`: Seed untuk avatar DiceBear dari nama

**File:** `lib/core/store.dart`
- `signInGuest()` sekarang generate nama random dan simpan
- Guest session restoration juga restore nama yang tersimpan

### 5. Control Mapping di Account Page
**File:** `lib/features/account/account_page.dart`

- Tambah row "Control Mapping" di section "Akun & informasi"
- Navigate ke `ControlMappingPage`

## Storage Strategy

Control mapping disimpan per akun menggunakan `accountScopeProvider`:
- Key: `control_profiles:{scope}`
- Logged in user: scope dari hash email
- Guest: scope = 'guest'

Ini memastikan setiap akun punya control mapping sendiri yang tidak bercampur.

## Default Mappings

### Gaming (FPS Style)
| Input | Action | Deskripsi |
|-------|--------|-----------|
| W | move_forward | Gerak ke depan |
| S | move_backward | Gerak ke belakang |
| A | move_left | Gerak ke kiri |
| D | move_right | Gerak ke kanan |
| Space | jump | Lompat |
| Ctrl | crouch | Jongkok |
| Shift | sprint | Lari cepat |
| LeftClick | shoot | Tembak |
| RightClick | aim | Bidik/ADS |
| R | reload | Isi ulang |
| E | interact | Interaksi |
| Tab | inventory | Buka inventory |
| M | map | Buka peta |

### Desktop (Produktivitas)
| Input | Action | Deskripsi |
|-------|--------|-----------|
| Ctrl+C | copy | Salin |
| Ctrl+V | paste | Tempel |
| Ctrl+X | cut | Potong |
| Ctrl+Z | undo | Batalkan |
| Ctrl+Y | redo | Ulangi |
| Ctrl+S | save | Simpan |
| Ctrl+A | select_all | Pilih semua |
| Ctrl+T | new_tab | Tab baru |
| Ctrl+W | close_tab | Tutup tab |

## Testing Checklist

- [ ] Login sebagai tamu → nama random muncul di profil (contoh: "Aditya Pratama")
- [ ] Logout → login lagi sebagai tamu → nama random baru (berbeda)
- [ ] Login dengan Google → foto profil Google muncul di topbar & account page
- [ ] Login dengan email → inisial nama muncul (tidak ada foto)
- [ ] Buka Account → Control Mapping → halaman terbuka
- [ ] Default profiles (Gaming & Desktop) muncul
- [ ] Tambah profil baru → masuk ke list
- [ ] Edit profile → preview tab menampilkan mappings
- [ ] Hapus profil custom → hilang dari list
- [ ] Set default profile → badge "DEFAULT" pindah
- [ ] Reset ke default → semua custom profile hilang, default kembali
- [ ] Virtual keyboard di session → tombol lebih mudah dipencet
- [ ] Virtual keyboard → animasi press lebih smooth
- [ ] Control mapping tersimpan per akun (login akun A → profile A, login akun B → profile B)

## Files Changed

- `lib/features/session/control_mapping.dart` (new, 406 lines)
- `lib/features/session/control_mapping_page.dart` (new, 589 lines)
- `lib/features/auth/guest_identity.dart` (new, 67 lines)
- `lib/features/session/virtual_keyboard.dart` (modified, improved _PressableKey)
- `lib/widgets/profile_avatar.dart` (modified, added pictureUrl)
- `lib/features/account/account_page.dart` (modified, pass pictureUrl, add Control Mapping row)
- `lib/app.dart` (modified, pass pictureUrl to TopbarAvatarButton)
- `lib/core/store.dart` (modified, guest name generation & restore)

Total: 8 files changed, ~1100 lines added
