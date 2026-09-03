# Uji lab Windows — host (sesi, injeksi, papan klip)

Kode di `host/` sebagian besar hidup di balik `cfg(target_os = "windows")`:
DXGI (capture), WASAPI (audio), `SendInput` (keyboard/mouse), papan klip.
CI maupun `tool/check-host-windows.sh` cuma membuktikan kode itu **terkompilasi
dan logikanya benar di unit test** — bukan bahwa perilakunya benar di mesin
nyata. File ini daftar yang terakhir itu. Tidak ada alat di repo ini yang bisa
menggantikannya.

Ditulis untuk SESI-20260903-GALIH-HOST-AUDIT (perubahan: masa tenggang
koneksi, penutupan peer connection saat slot dilepas, injeksi teks per batch).
Kalau hasil sebuah uji menyimpang, catat di `HANDOFF.md` bagian
"Untuk: Host Engine" beserta log mentahnya — jangan dibiarkan hanya di chat.

## 0. Persiapan

**Lewat aplikasi (paling mirip pemakaian nyata).** Pasang XyDesk untuk Windows
hasil `Build` CI (job `windows`). Shell Electron yang men-spawn
`xydesk-host.exe`, jadi log engine ada di **tab Log** pada jendela XyDesk.

**Lewat engine saja (untuk mengontrol sendiri).** Build lalu jalankan manual:

```powershell
cd host
cargo build --release --bin xydesk-host

# Token signaling host: ditukar dari ID (9 digit, TANPA spasi) + password pairing
$resp = Invoke-WebRequest -Method POST -Uri 'https://signal.xystudio.my.id/host-token' `
  -ContentType 'application/json' -Body '{"id":"123456789","claim":"PASSWORDPAIRING"}'
& .\target\release\xydesk-host.exe --url wss://signal.xystudio.my.id/ws `
  --token $resp.Content --control-port 45123
```

Baris pertama stdout engine memberi alamat + token control API:

```text
[control] http://127.0.0.1:45123 token=9f3c...
```

Pakai itu untuk membaca keadaan tanpa menebak dari log:

```powershell
$h = @{ 'x-xydesk-token' = '9f3c...' }
Invoke-RestMethod -Uri 'http://127.0.0.1:45123/status' -Headers $h |
  Select-Object state, @{n='klien';e={$_.session.clientId}},
                @{n='frame';e={$_.video.framesSent}},
                @{n='fps';e={$_.video.fps}},
                @{n='encoder';e={$_.video.encoder}},
                @{n='latensiMs';e={$_.video.latencyMs}}
```

Buka sesi dari HP (aplikasi XyDesk, ID + password), dan biarkan Task Manager
terbuka di tab **Performance → GPU** + **Processes** (kolom GPU Mode).

## 1. Blip jaringan tidak boleh memutus sesi

Sisi host yang berubah: `Disconnected` bukan lagi vonis mati, tapi diberi masa
tenggang 15 detik.

| # | Lakukan | Harus terlihat |
|---|---|---|
| 1.1 | Saat sesi berjalan, matikan Wi-Fi HP **5–10 detik**, lalu nyalakan | Di PC: `… <id-klien> pulih sendiri — sesi lanjut`. `state` di `/status` tetap `streaming`, `video.framesSent` **naik terus**, gambar di HP lanjut — TANPA minta password ulang |
| 1.2 | Ulangi, tapi putuskan **lebih dari 15 detik** | `<id-klien> tidak pulih dalam 15 detik (keadaan disconnected) — slot dilepas`, lalu `state` → `ready` dan `session` kosong |

Kalau 1.1 justru memutuskan sesi: catat log mulai dari `data channel input
terbuka` sampai baris pertama yang menyebut `slot dilepas`.

## 2. Capture & encoder berhenti saat sesi benar-benar dilepas

Ini yang dulu bocor: slot dicabut, tapi thread capture tetap merekam untuk
penonton yang sudah pergi.

| # | Lakukan | Harus terlihat |
|---|---|---|
| 2.1 | Tutup sesi dari HP (tombol keluar / `bye`) | Dalam ≤ 2 detik penggunaan GPU/CPU `xydesk-host.exe` turun ke tingkat idle; `framesSent` berhenti naik |
| 2.2 | Setelah 2.1, buka sesi baru dari HP yang sama | Gambar muncul ≤ 3 detik, TIDAK layar hitam. Layar hitam di langkah ini = duplikasi DXGI sesi lama masih dipegang — itu regresi yang paling harus diwaspadai |
| 2.3 | Matikan HP (listrik habis / paksa berhenti app), tanpa `bye` | Host melepas slot sendiri paling lama ±15 detik setelah koneksi ICE dinyatakan mati, dan langkah 2.2 tetap lolos |

## 3. Ketikan panjang & emoji (jalur 0x06 TEXT)

Host kini meng-inject teks per 32 karakter dan mengirim ulang sisa yang belum
masuk, dengan batas 4.096 unit UTF-16 per pesan.

| # | Lakukan | Harus terlihat |
|---|---|---|
| 3.1 | Buka Notepad di PC, dari papan ketik XyDesk ketik 3 baris biasa | Semua karakter masuk, urutan benar, Enter menghasilkan baris baru |
| 3.2 | Tempel paragraf ±2.000 karakter (campur `é`, `ñ`, emoji 🔥😀) ke kolom teks di HP lalu kirim | Notepad menampilkan SELURUH teks, urutan sama, tidak ada `?` / kotak / karakter rusak — terutama di sekitar emoji |
| 3.3 | Tempel teks ±10.000 karakter | Yang lewat 4.096 unit dibuang; sisanya TIDAK muncul sebagai karakter rusak. Di log wajar muncul `[xydesk-host] inject gagal: Text(...)` bila jendela target menolak — itu laporan, bukan crash |
| 3.4 | Ketik cepat dan beruntun (tahan spasi / tempel 20 baris) | Tidak ada kehilangan karakter di tengah; antrean injeksi boleh melambat, tapi sesi tidak boleh mati |

## 4. Satu sesi media pada satu waktu

| # | Lakukan | Harus terlihat |
|---|---|---|
| 4.1 | Saat sesi aktif, muat ulang halaman sesi di HP (atau putuskan lalu sambung lagi sampai `offer` baru terkirim) | Hanya ada SATU pasang "track video siap — streaming" yang aktif: `framesSent` naik satu-satu, dan sesudahnya penggunaan GPU setara satu sesi, bukan dua |
| 4.2 | Selama 4.1, biarkan sesi lama tetap terbuka di perangkat kedua (ID lain) | Perangkat kedua mendapat penolakan (`host-sibuk` / harus pairing), TIDAK ikut streaming |

## 5. Papan klip (perubahan kecil, sekalian)

| # | Lakukan | Harus terlihat |
|---|---|---|
| 5.1 | Salin teks di HP → di panel sesi pilih "Kirim papan klip ke PC" → Ctrl+V di Notepad | Isi sama persis, termasuk emoji; log: `papan klip PC diisi dari client` |
| 5.2 | kosongkan papan klip HP → kirim lagi → cek Win+V di PC | Papan klip PC jadi kosong (pesan 0x08 kosong itu keadaan sah, bukan diabaikan) |
| 5.3 | Sesudah 5.1, biarkan host berjalan 1 jam sambil menekan kirim-papan-klip 200× | Penggunaan memori `xydesk-host.exe` tidak naik terus. (Ini menguji `GlobalFree` di jalur gagal — kalau ada penolakan sistem, memori dulu bocor permanen) |

## Yang dianggap lolos

Sebut keempat blok di atas lolos bila: sesi tahan blip ≤ 10 detik, semua
penlepasan slot membuat capture berhenti, teks 2.000 karakter masuk utuh, dan
tidak pernah ada dua sesi media hidup bersamaan. Setelah itu, tulis hasilnya ke
`HANDOFF.md` (perbarui item verifikasi lab Windows) — angka dan baris log
aslinya, bukan hanya "udah oke".
