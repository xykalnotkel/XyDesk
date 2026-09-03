# XyDesk Host (Rust)

Aplikasi sisi PC yang ditanam di komputer yang dikendalikan. Menangkap layar,
meng-encode, dan mengirim via WebRTC ke client.

## Status (jujur)

| Bagian | Status |
|---|---|
| Signaling client (daftar, pair, negosiasi) | ✅ jadi, lintas platform |
| Sesi WebRTC (answerer) + data channel "input" | ✅ implementasi tersedia |
| **Media plane: track video H264 + encode → RTP → decode** | ✅ implementasi tersedia (openh264, pola frame) |
| Sumber video: capture layar (DXGI) + encode (NVENC) | ✅ implementasi tersedia (`screen.rs` + `nvenc.rs`); ⏳ belum diverifikasi di lab Windows |

Artinya: jalur media **sudah terbukti end-to-end** — host meng-encode frame
(openh264) → kirim lewat RTP → client menerima & men-decode. Di Windows,
`screen.rs` menangkap layar via DXGI Desktop Duplication (`windows-capture`)
lalu meng-encode dengan **NVENC** bila GPU NVIDIA tersedia, dan jatuh ke
openh264 (software) bila tidak. Yang belum dilakukan: verifikasi di lab
Windows nyata (runner CI tanpa GPU — lihat `test-lab.yml`) dan jalur
zero-copy NVENC (ID3D11Texture2D → NVENC tanpa bolak-balik CPU).

## Identitas (ID + Password) — dipakai untuk connect dari HP

Saat host dibuka, dia otomatis menampilkan:

```
╔══════════════════════════════════════════╗
║   ID       : 123 456 789                  ║
║   Password : aV7kQm2d9x                   ║
╚══════════════════════════════════════════╝
```

- **ID**: 9 digit acak, unik per perangkat, disimpan permanen (`~/.xydesk/device_id`).
- **Password**: acak saat pertama dibuka, disimpan permanen (`~/.xydesk/password`).
- **Customize password**:
  ```bash
  xydesk-host --set-password "Kopi Pagi 2026"   # bebas besar/kecil, spasi boleh
  xydesk-host --new-password                     # generasi ulang password acak
  ```
  Lewat shell desktop: halaman **Hubungkan** punya kolom password kustom (jalur
  control API `set-password`). Aturan panjang & karakternya SATU sumber:
  `identity::set_password` — CLI dan control API tidak bisa berbeda pendirian.
- ID + password inilah yang diketik pengguna di aplikasi **client (HP)** untuk pairing.

### Soal besar-kecil (dan kenapa bukan ruang tebakan)

Charset generator sudah dicampur huruf besar + kecil (`PW_CHARS`) sejak
v6.4.x, TAPI `verify_password` sengaja **tidak peka besar-kecil**: `aV7k…`
dan `AV7K…` sama-sama diterima. Alasannya praktis — password dibaca dari
layar PC lalu diketik di papan ketik ponsel, yang hobi mengkapital huruf
pertama; memaksa pengguna mengetik dengan kapitalisasi persis berarti
mengunci orang dari PC-nya sendiri.

Konsekuensi yang perlu diketahui: huruf kecil **tidak menambah entropi**.
Ruang tebakan efektif tetap 31 simbol/karakter (23 huruf + 8 angka, tanpa
`I/l/1` dan `O/o/0` yang mudah tertukar) ≈ 4,95 bit → 10 karakter ≈ 49,5 bit.
Mau menjadikan besar-kecil ruang tebakan sungguhan? Dua hal wajib berubah
bersamaan, kalau tidak client lama langsung terkunci:

1. `verify_password` jadi peka-kasus (buang `to_ascii_uppercase` di kedua sisi);
2. semua tempat mengetik password — `lib/` (Flutter), `web/`, shell desktop —
   menyetel `autoCapitalization: none` / `autoCapitalize="none"` +
   `autoCorrect=off`.

Sampai dua syarat itu terpenuhi, generator huruf kecil murni soal
keterbacaan di layar, bukan kekuatan.

## Jalankan

```bash
xydesk-host \
  --url wss://signal.xystudio.my.id/ws \
  --token <TOKEN>        # dari /issue
# --id opsional: otomatis digenerasi & disimpan bila tidak diberikan
```

## Build

GitHub Actions membangun host Windows secara otomatis. Untuk build manual:

```bash
cargo build --release
```

## Sumber video (Windows) — cara kerjanya

1. **Capture** — `screen.rs` memakai crate `windows-capture` (DXGI Desktop
   Duplication / Graphics Capture API) di thread terpisah,
   `ColorFormat::Rgba8`.
2. **Encode** — `nvenc.rs` memanggil `nvEncodeAPI64.dll` langsung (NVIDIA
   Video Codec SDK 12.2, dimuat dinamis): H264 baseline CBR low-latency.
   Bila GPU NVIDIA / driver R550+ tidak ada, otomatis jatuh ke openh264
   (software) — sesi tidak mati.
3. **Kirim** — frame ter-encode didorong ke track video lewat
   `track.write_sample` di `src/session.rs`; channel frame berukuran kecil
   agar frame usang dibuang (latency diutamakan dari kelengkapan).

> NVENC zero-copy (ID3D11Texture2D → NVENC tanpa salin CPU) masih TODO —
> hari ini jalurnya CPU RGBA→NV12 (`pixfmt.rs`) → texture D3D11.
> Cross-compile dari Linux **tidak** didukung untuk bagian capture (butuh
> Win32). Verifikasi di lab Windows lewat workflow `test-lab.yml`.

## Struktur

```
host/
├── Cargo.toml
├── src/
│   ├── lib.rs       # pub mod identity; pub mod pixfmt; pub mod screen; ...
│   ├── main.rs      # CLI + signaling client + wiring sesi
│   ├── identity.rs  # ID 9 digit + password pairing (persisten, customizable)
│   ├── session.rs   # WebRTC answerer + data channel input
│   ├── screen.rs    # sumber video: DXGI capture (Windows) + pola uji (fallback)
│   ├── nvenc.rs     # encoder H264 hardware NVIDIA (dinamis, Windows-only)
│   └── pixfmt.rs    # RGBA → NV12 (lintas platform, teruji)
```

## Shell desktop: topbar, scroll, dan perangkat yang terhubung

`desktop/` (Electron + Next.js) hanya cangkang: dia men-spawn engine, membaca
control API, dan menampilkan hasilnya. Beberapa aturan yang sudah dibayar
mahal dan jangan sampai balik lagi:

**1. Yang menggulung = daerah isi, bukan jendela.**
```css
.shell { grid-template-rows: minmax(0, 100%); overflow: hidden; }
.main  { min-height: 0; }
.page-body { flex: 1 1 auto; min-height: 0; overflow-y: auto; }
```
Grid dengan baris `auto` (keadaan dulu) MEMANJANG mengikuti isinya, jadi
`overflow-y: auto` di `.page-body` tidak pernah punya tinggi untuk dipatuhi:
di layar 1100×480 halaman Pengaturan terpotong 776px dan tidak bisa digulung
sama sekali (`body` punya `overflow: hidden`). Kalau menambah layout baru,
beri `min-height: 0` di setiap tingkat antara `.shell` dan kontainer scroll.

**2. Topbar = baris judul Windows = quick surface.** `main.cjs` memakai
`titleBarStyle: 'hidden'` + `titleBarOverlay` ( warna = `--bg` ), sehingga
tombol min/maks/tutup digambar Windows di ujung kanan topbar dan UI tidak
lagi punya "garis asing" di atasnya. Konsekuensi yang wajib dijaga:
`.topbar { -webkit-app-region: drag }` dan SETIAP elemen yang bisa diklik di
dalamnya (`button`, `.chip`, `.pill`) `no-drag` — kalau tidak, tombolnya jadi
daerah seret. `padding-right` 150px untuk tempat tombol caption dipasang
hanya saat `<html>` punya class `electron` (dideduksi dari `info.platform`).
Jangan pakai `frame: false`: snap layouts, a11y, dan tombol caption asli
ikut hilang, dan drag/resize harus ditulis ulang di HTML.

**3. Info yang selalu terlihat ada di satu baris**: nama halaman, perangkat
pengendali + durasi (kalau sesi jalan), ID pairing (klik = salin), pill
status. Karena itu `.side-status` yang dulu mengulang pill status di bawah
sidebar dibuang — data yang sama dua kali = satu di antaranya basi.

**4. Chip "Redmi Note 12 (HP · Android)" — asal datanya.**
Host TIDAK membaca nama perangkat dari OS client; itu dilaporkan sendiri oleh
client lewat pesan `pair`:
```json
{ "type": "pair", "pin": "…", "name": "Redmi Note 12", "platform": "android" }
```
`name`/`platform` adalah field TAMBAHAN: client lama yang tidak mengirimnya
tetap bisa pairing, host menampilkan ID saja. Host menyimpannya di
`PairedPeers::set_label` (dibersihkan saat `revoke`) dan menuliskannya ke
`SessionStatus` → `GET /status` (`clientName`/`clientPlatform`). Nilainya boleh
dikarang peer, jadi ia tidak pernah dipakai untuk memutuskan akses — hanya
tampilan + tooltip tray/judul jendela. Yang masih perlu digarap di sisi lain:
`lib/` & `web/` harus mengirim field itu (lihat `HANDOFF.md`), dan hub
signaling Go dev (`signaling/protocol.go`) memakai struct bertipe sehingga
field asing HILANG saat relay — Cloudflare hub (`{ ...msg, from }`) lolos.

## Soal driver (mic/audio/display/GPU), C#, dan keyboard/mouse fisik

**"Siapkan driver mic/audio/display/GPU" — driver tidak diperlukan dan tidak
bisa kita kirim.** Host berjalan di atas jalur tercepat yang sudah disediakan
Windows, semuanya user-mode:

| Kebutuhan | Jalur yang dipakai host sekarang |
|---|---|
| Display / capture | DXGI Desktop Duplication (`screen.rs` via `windows-capture`) |
| GPU encode | NVENC lewat D3D11 + tekstur NV12 (`nvenc.rs`), jatuh ke openh264 |
| Audio PC → HP | WASAPI loopback → Opus 48 kHz |
| Mic HP → PC | track WebRTC, di-mix ke default render endpoint |
| Keyboard/mouse | `SendInput` (`input.rs`) — masuk ke antrean input sistem |

Driver sungguhan (kernel-mode) baru perlu untuk hal lain: **HidHide**
(ViGEmBus) untuk MENYEMBUNYIKAN perangkat fisik, **IddCx** untuk display
virtual/headless, dan semuanya butuh sertifikat EV code-signing + INF + test
signing — bertentangan dengan aturan ROADMAP "semua gratis, tanpa kartu
kredit". Jadi kalau ada yang bilang "pasang driver biar makin gacor", yang
dimaksud biasanya salah satu dari: update driver GPU dari NVIDIA/AMD (milik
vendor, bukan kita), USB Device ID mapping via Registry (satu driver per
keyboard fisik — tidak skala), atau EDID emulator fisik buat PC tanpa monitor.

Yang masih bisa menaikkan performa TANPA driver dan belum dikerjakan, sudah
dicatat sebagai opsi: zero-copy penuh DXGI→NVENC (hindari bolak-balik CPU),
preference adapter/L0 sebelum encoder dipilih, dan audio capture per-aplikasi
(`AUDIOCLIENT_ACTIVATION_PARAMS` / `PROCESS_LOOPBACK_MODE`, Windows 10+) biar
hanya suara aplikasi target yang ikut ke HP. Lihat `HANDOFF.md`.

**Keyboard & mouse fisik di PC host: aman, tidak dibajak.** `SendInput`
MENAMBAH event ke antrean input sistem, bukan mengambil alih perangkat, jadi
orang yang duduk di depan PC tetap bisa mengetik dan menggerakkan mouse selama
sesi berlangsung — keduanya campur aduk (two hands on one cursor). Yang TIDAK
kita lakukan: memasang `WH_KEYBOARD_LL`/`WH_MOUSE_LL` untuk memblokir input
lokal, karena (a) butuh fitur "mode eksklusif" yang sadar di client supaya
tidak terasa seperti PC rusak, (b) tidak bisa diuji dari CI Linux, dan (c)
hook yang salah tulis = pengguna kehilangan keyboard sendiri. Kalau fitur
"PC terkunci selama sesi" memang diinginkan, bentuknya: toggle eksplisit +
`LockWorkStation()` (satu panggilan user32, tanpa driver) ATAU hook global
dengan watchdog + tombol darurat. Bilang saja kalau mau digarap.

**"Ini apa ga butuh bahasa C#?" — tidak.** Stack ini sudah lengkap: engine
Rust (`windows` crate untuk WinRT/DXGI/WASAPI/NVENC/SendInput), cangkang
desktop Electron/Next.js, client Flutter. C# hanya masuk akal kalau mau
menulis tray WinUI/WPF sendiri atau contoh driver IddCx; itu menduplikasi FFI
yang sudah ada dan memecah aturan `host/` satu bahasa di CI (`docs/CI.md`).
Yang benar-benar butuh C/C++ bukan C#: vendor SDK (NVENC/AMF) atau kernel
driver — dua-duanya di luar rencana.
