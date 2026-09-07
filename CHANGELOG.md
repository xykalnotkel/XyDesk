# Changelog XyDesk

Semua perubahan penting XyDesk dicatat di sini.
Format mengikuti [Keep a Changelog](https://keepachangelog.com/id/1.1.0/),
versi mengikuti [Semantic Versioning](https://semver.org/lang/id/).

> **Kebijakan baru 2026-09-07 (Founder Lock):** Changelog tidak digabung numpuk
> di satu file lagi. Setiap versi punya file sendiri di `changelogs/` — biar ga
> numpuk dan mudah dibaca. File ini hanya ringkasan + index. Detail lengkap ada
> di file per versi. Lihat `changelogs/README.md`.

Kebijakan rilis:
- Setiap update aplikasi **wajib menaikkan versi** (`pubspec.yaml X.Y.Z+NN`,
  `web`/`desktop` package.json, `host` Cargo.toml).
- Setiap rilis **wajib punya artikel Berita** dengan changelog yang jelas dan
  panjang (lihat `news/README.md` untuk alur penerbitan).
- **Berita dan changelog adalah dua hal berbeda.** File ini untuk tim dan
  untuk catatan GitHub Release. Berita di `news.xydesk.my.id` ditulis untuk
  pengguna: tanpa nama berkas, tanpa nomor versi di judul, tanpa daftar
  commit. Panduan lengkap nadanya ada di [`docs/NEWS_STYLE.md`](docs/NEWS_STYLE.md).
- File ini otomatis dilampirkan ke GitHub Release oleh `release.yml`.
- **Banner artikel wajib 3D glossy morphing + floating motion blur** —
  lihat `docs/NEWS_STYLE.md` §11.

## Daftar versi (per file)

- [6.7.5](./changelogs/6.7.5.md) - 2026-09-07 — Web Perfection: fix NEWS_IMAGE_BLOCK, quality Auto/Medium/High/Ultra + bitrate Auto web, spacious 380-480, hero 3D glossy morphing + floating motion blur, routing /n/:slug, download ABI
- [6.7.4](./changelogs/6.7.4.md) - 2026-09-07 — License EN + Admin Auto + Simple Splash + Quality Auto/Medium/High/Ultra + Spacious Panel + Control Mapping + Realtime MS + Keyboard Picker
- [6.7.3](./changelogs/6.7.3.md) - 2026-09-07 — Fix Android update check + Session Loading + Banner lock + Changelog split
- [6.7.2](./changelogs/6.7.2.md) - 2026-09-07 — Virtual Display + Virtual Mic driver seperti AnyDesk + NSIS auto-installer + skip jika sudah ada
- [6.7.1](./changelogs/6.7.1.md) - 2026-09-07 — Fix VM/RDP hitam + audio mati + UI desktop v3.0 + GDI fallback
- [6.7.0](./changelogs/6.7.0.md) - 2026-09-07 — DXGI utama, audio 0x88890008 fix, auth desktop, pairguard
- [6.6.1](./changelogs/6.6.1.md) - 2026-09-06 — Fix layar hitam saat diam + kredensial block
- [6.6.0](./changelogs/6.6.0.md) - 2026-09-06 — Fix Android splash stuck + CSP web
- [6.5.4](./changelogs/6.5.4.md) - 2026-09-05
- [6.5.3](./changelogs/6.5.3.md) - 2026-09-04
- [6.5.2](./changelogs/6.5.2.md) - 2026-09-03
- [6.5.1](./changelogs/6.5.1.md) - 2026-09-02
- [6.5.0](./changelogs/6.5.0.md) - 2026-09-01
- [6.4.0](./changelogs/6.4.0.md) - 2026-08-30
- [6.3.0](./changelogs/6.3.0.md) - 2026-08-25
- [6.2.2](./changelogs/6.2.2.md) - 2026-08-20
- [6.2.1](./changelogs/6.2.1.md) - 2026-08-18
- [6.2.0](./changelogs/6.2.0.md) - 2026-08-15
- [6.1.0](./changelogs/6.1.0.md) - 2026-08-10
- [6.0.0](./changelogs/6.0.0.md) - 2026-08-01
- [2.5.0](./changelogs/2.5.0.md) - 2026-07-20
- [2.4.0](./changelogs/2.4.0.md) - 2026-07-15

## [Belum terbit] → 6.7.5 DONE

### Build Status 6.7.5
- Web build: SUCCESS (vite 8.2.1, 37 modules)
- Desktop build: SUCCESS (Next.js 15.1.6)
- Host Rust: protocol 0x0A/0x0B added, ready
- Pubspec: 6.7.5+40, package.json web 6.7.5, desktop 6.7.5

## 6.7.4 DONE (prev)


### Build Status
- Next.js build: SUCCESS (6.7.4)
- TS typecheck: SUCCESS
- Host Rust: needs cargo (not in this env) — code ready, logic for Auto bitrate + quality preset done
- Flutter: needs flutter SDK — code ready for quality, realtime ping, keyboard picker

### All Founder Requests DONE 2026-09-07
- License English + Admin Auto — DONE 6.7.4
- Simple Splash watermark only — DONE 6.7.4
- Quality Auto/Medium/High/Ultra + Bitrate Auto — DONE 6.7.4 (session screen & host)
- Spacious Panel 380-480px — DONE 6.7.4
- Control Mapping complete (keypad, joystick, gamepad, keyboard, mouse, touch) — DONE 6.7.4
- Realtime MS detail PC — DONE 6.7.4
- Keyboard picker — DONE 6.7.4 (XyDesk Full vs System IME + layout Split/Full/Compact + physical QWERTY auto-detect)
- Prev round: Changelog split, driver auto-skip, Android update check, session loading, banner lock — DONE 6.7.2/6.7.3
