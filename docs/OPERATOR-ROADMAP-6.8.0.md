# Operator Roadmap 6.8.0 — Prioritas Pasca-6.7.0

> Disusun Operator - XyDesk Team, 2026-09-07, sesi SESI-20260907-OPERATOR-ALL
> Sumber kebenaran teknis tetap ROADMAP.md; ini adalah turunan operasional untuk 1 rilis ke depan.

## Prinsip
1. **Bukti dulu, baru poles** — Fase 0 belum lulus sampai angka latency ada.
2. **Semua gratis, tanpa kartu kredit** — TURN static dulu, jangan Cloudflare Realtime.
3. **Satu sesi = satu role, kecuali Operator** — Operator boleh lintas area, tapi versi/berita/deploy tetap minta restu founder.

---

## P0 — WAJIB sebelum 6.8.0 (blokir rilis kalau belum)

### P0.1 TURN Static Live
- **Kenapa:** tanpa TURN, user CGNAT (mayoritas Indo) tidak pernah connect. Ini churn #1.
- **Apa:** daftar ExpressTurn free → dapat URL + secret → isi GitHub Secrets `TURN_STATIC_URLS` + `TURN_STATIC_SECRET` → dispatch `Deploy Signaling` → verifikasi `tool/check_turn_live.js`
- **Bukti selesai:** `curl -H "X-Admin: $ADMIN" https://signal.xydesk.my.id/turn-ice | jq .providers` → `statis.ok=true`, `iceServers` tidak kosong.
- **Role:** Backend/Edge (Tara) + CI/Release (Cakra)

### P0.2 Latency Glass-to-Glass Terukur
- **Kenapa:** klaim "low-latency untuk gaming" tanpa angka = bohong. README sendiri bilang belum.
- **Apa:** 
  - Host: tambah overlay timestamp (ms) di pojok layar saat `--bench` atau mode debug
  - Client: foto 2 layar berjejer (host + client) 10x LAN kabel, 10x WiFi rumah, 10x internet via TURN
  - Catat di `docs/LATENCY.md` + tabel di `README.md`: avg/p50/p95/max, plus video 30 detik
- **Target go/no-go Fase 0:** 1080p60, <40ms LAN, <80ms via TURN, stabil 30 menit tanpa re-buffer
- **Role:** Host Engine (Galih) + Client Flutter (Laras) + Docs & Audit (Sena)

### P0.3 Lab Windows 5 Blok
- **Kenapa:** sebagian besar `host/` cuma terbukti di Linux CI, bukan Windows nyata. Bug hidup-mati, capture gantung, mic, dll cuma ketahuan di lab.
- **Apa:** jalankan `host/TEST-LAB-WINDOWS.md` lengkap:
  1. Blip WiFi ≤10 detik → sesi lanjut tanpa pairing ulang
  2. Capture berhenti saat sesi tutup (GPU turun di Task Manager)
  3. Ketikan 2000 char + emoji masuk utuh
  4. Satu sesi media pada satu waktu (reload client tidak bikin 2 encoder)
  5. Papan klip 200x tidak bocor memori
- **Bukti:** log asli + screenshot Task Manager, tulis ke HANDOFF.md (bukan "udah oke")
- **Role:** Host Engine + Desktop Shell

---

## P1 — Penting, masuk 6.8.0 kalau P0 hijau

### P1.1 Watchdog "Connected tapi Belum Ada Gambar"
- **Masalah:** `RtcPhase.connected` dari ICE/DTLS, bukan dari frame pertama. User bisa tatap hitam selamanya.
- **Solusi:** setelah `connected`, timer 10 detik; kalau `SessionStats.hasVideo==false`, tampilkan banner jujur: "Tersambung tapi belum ada gambar — coba ganti layar atau retry" + tombol `selectDisplay`. Jangan runtuhkan sesi.
- **File:** `lib/webrtc/rtc_service.dart`, `web/src/rtc.ts`, `lib/features/session/session_page.dart`
- **Role:** Client Flutter + Web

### P1.2 Audit URL update.json
- **Masalah:** `update.json` cuma di GitHub Release, tidak di `app.xydesk.my.id/update.json`. Kalau client hardcode domain, update tidak pernah ditawarkan.
- **Solusi:** grep semua `update.json` di `lib/`, `web/src/`, `desktop/`; pastikan baca dari `https://github.com/xykalnotkel/XyDesk/releases/download/v.../update.json` atau proxy di Worker. Tambah test.
- **Role:** Client Flutter + Web + Docs

### P1.3 Per-App Audio Capture (Win10 2004+)
- **Nilai:** gamer cuma mau suara game, bukan notifikasi Windows / musik.
- **Solusi:** `AUDIOCLIENT_ACTIVATION_PARAMS` + `PROCESS_LOOPBACK_MODE_TARGET` → pilih PID target. Fallback ke loopback global kalau OS lama.
- **Tanpa driver**, murni user-mode.
- **Role:** Host Engine

---

## P2 — Nice to have, bisa geser ke 6.9.0

### P2.1 Zero-Copy DXGI → NVENC
- **Gain:** 15-20ms (buang RGBA→NV12 CPU + copy ke D3D11)
- **Cara:** `IDXGIResource::GetSharedHandle` → `OpenSharedResource` → `NV_ENC_INPUT_RESOURCE_TYPE_DIRECTX`
- **Risiko:** butuh lab Windows + GPU Nvidia. Test loopback tidak cover.
- **Role:** Host Engine

### P2.2 Pilih Adapter Diskrit
- **Gain:** di laptop hybrid, encoder harus di dGPU, bukan iGPU yang render UI.
- **Cara:** `CreateDXGIFactory1` + `EnumAdapters1` + cek `NvEncodeAPIGetMaxSupportedVersion`
- **Role:** Host Engine

### P2.3 Signed Installer + Auto-Update Host
- **Kenapa:** SmartScreen Windows blokir exe unsigned.
- **Tapi:** butuh EV cert berbayar → nabrak ROADMAP. Tahan sampai ada revenue.
- **Sementara:** `update.json` + OneSignal push + manual download tetap jalan.

### P2.4 Alias untuk 6 Slug 404
- **Masalah:** `changelog-v6-5-4` dll 404.
- **Solusi paling bersih:** tambah `aliases` map di `news/src/worker.js` → redirect 301 ke slug asli (`p-...` / `rilis-...`). Tidak mutus link lama yang udah kesebar di push notification.
- **Butuh keputusan founder.**

---

## Yang TIDAK dikerjakan di 6.8.0

- Dark mode Android (sengaja Paper saja)
- C++ (keputusan final: JANGAN, lihat AUDIT-2026-09-06 §C)
- Driver kernel HidHide/IddCx (butuh EV signing, nabrak gratis)
- Hapus garis pemisah web/desktop (300+ pemakaian, butuh design pass terpisah)

---

## Urutan Eksekusi Saran

```
Hari 1-2: P0.1 TURN static (1 jam daftar + deploy + verifikasi)
Hari 2-4: P0.2 latency ukur (butuh 2 device + kamera HP)
Hari 3-5: P0.3 lab Windows (5 blok, 1 hari penuh)
Hari 6:   P1.1 watchdog + P1.2 update.json audit
Hari 7:   Bump versi 6.8.0 + bahan artikel + dispatch Build → Release → Deploy
```

Kalau P0 gagal (latency >40ms LAN), pivot positioning: "XyDesk untuk kerja remote low-latency, gaming = beta". Jujur lebih mahal daripada janji palsu.

---

> Operator - XyDesk Team, 2026-09-07
> Izin: SESI-20260907-OPERATOR-ALL
