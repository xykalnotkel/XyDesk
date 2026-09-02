# AGENT_BOARD.md — Papan Koordinasi Agent XyDesk

Papan ini adalah satu-satunya sumber kebenaran **siapa lagi kerja apa** dan
**push siapa yang sudah diizinkan**. `AGENT.md` mewajibkan: baca papan ini di
awal sesi, **kunci** areamu, barulah kerja. `HANDOFF.md` mencatat *hasil*
lintas role; papan ini mencatat *keadaan saat ini* (real-time).

> Papan ini ikut berkembang lewat commit ke `main`. Karena agent baru boleh
> push setelah diizinkan, alur persetujuannya:
> 1. Agent menyampaikan permintaan izin (chat/laporan sesi) berisi ID sesi +
>    ringkasan, dan menulis baris `MENUNGGU` di antrean bawah.
> 2. Operator mengubah status baris itu menjadi `DISETUJUI` pada commit
>    kecil di `main`.
> 3. Agent push dengan setiap commit memuat `Izin: <ID-SESI>` di body.
>    Workflow `verify-push-auth.yml` memeriksa ini di setiap push.

## Alur sesi (3 langkah)

1. **Kunci sesi** — tambah baris di tabel *Sesi aktif*, status `LAGI KERJA`.
   Format ID: `SESI-<YYYYMMDD>-<NAMA>-<AREA>`, contoh `SESI-20260903-CAKRA-CI`.
   Satu area hanya boleh dikunci satu agent. Area yang terkunci = jangan
   masuk tanpa menunggu.
2. **Minta izin push** — setelah CI area-mu hijau, pindahkan baris ke
   *Antrean izin push* (`MENUNGGU`) + ringkasan. Operator menulis
   `DISETUJUI` (atau `DITOLAK` + alasan).
3. **Tutup sesi** — setelah push hijau, pindahkan baris ke *Riwayat sesi*
   (`SELESAI` + tautan run CI). Riwayat tidak boleh dihapus.

## Sesi aktif (LOCK)

| ID Sesi | Agent | Role / Area | Status | Sedang mengerjakan | Mulai |
|---|---|---|---|---|---|
| SESI-20260903-TARA-BACKEND | Tara - XySpace Team | Backend / Edge | LAGI KERJA | Paritas keamanan signaling Go (role di token, arah relay, privasi daftar) + email berita + pin Node ≥ 22 | 2026-09-03 |
| SESI-20260903-CAKRA-GOTEST | Cakra - XySpace Team | CI / Release | LAGI KERJA | Integrasi `go vet` + `go test` ke check-signaling | 2026-09-03 |

## Antrean izin push

| ID Sesi | Agent | Ringkasan perubahan | Status izin | Disetujui oleh | Kapan | Run CI |
|---|---|---|---|---|---|---|
| SESI-20260903-CAKRA-CI | Cakra - XySpace Team | Filter area di `build.yml` (job `changes` + jobs terpisah), `check-meta`/`check-news`/`check-signaling` baru, skip gracful `deploy-web.yml`, workflow `verify-push-auth.yml`, `AGENT_BOARD.md`, pembaruan `AGENT.md`/`docs/CI.md`/`CHANGELOG.md`/`CONTRIBUTORS.md` | DISETUJUI | Xyckal | 2026-09-03 | Run 1: Build 33663421875 + Verifikasi 33663421843 · Run 2: Build 33663874463 + Verifikasi 33663874589 |
| SESI-20260903-CAKRA-NOTIF | Cakra - XySpace Team | Notifikasi push tanpa izin ke ntfy/Telegram pada `verify-push-auth.yml` + dokumentasi `docs/CI.md` + `CHANGELOG.md` | DISETUJUI | Xyckal | 2026-09-03 | Build 33664638977 + Verifikasi 33664638941 |
| SESI-20260903-GALIH-HOST | Galih - XySpace Team | Host Engine: bitrate video live lewat control API (aksi `video-bitrate` 1–50 Mbps, `targetBitrateBps` di `/status`), perbaikan E0308 build Windows (satu sumber tipe NVENC), pindah konstanta/perakit NVENC ke `nvenc_config.rs` + uji | DISETUJUI | Xyckal (chat) | 2026-09-03 | Build 33665824839 + Verifikasi 33665824719 |
| SESI-20260903-TARA-BACKEND | Tara - XySpace Team | Paritas keamanan signaling Go (token bind role, middleware tolak penyamar, relayAllowed, daftar host saja) + uji Go + email berita (badge 404) + engines Node ≥ 22 + dokumentasi protokol | DISETUJUI | Xyckal | 2026-09-03 | — |
| SESI-20260903-CAKRA-GOTEST | Cakra - XySpace Team | `go vet` + `go test` signaling ditambahkan ke `check-signaling` + docs/CI.md | DISETUJUI | Xyckal | 2026-09-03 | — |

## Riwayat sesi (hanya bertambah)

| ID Sesi | Agent | Area | Status | Ringkasan | Selesai |
|---|---|---|---|---|---|
| SESI-20260903-CAKRA-CI | Cakra - XySpace Team | CI / Release | SELESAI | Filter area CI (build.yml), skip pintar deploy-web.yml, gerbang verify-push-auth.yml, papan koordinasi, pembaruan AGENT.md/docs/CI.md/CHANGELOG/CONTRIBUTORS/HANDOFF | 2026-09-03 |
| SESI-20260903-CAKRA-NOTIF | Cakra - XySpace Team | CI / Release | SELESAI | Notifikasi push tanpa izin (ntfy/Telegram) di verify-push-auth.yml + docs/CI.md | 2026-09-03 |
| SESI-20260903-GALIH-HOST | Galih - XySpace Team | Host Engine | SELESAI | Bitrate video live via control API (video-bitrate 1–50 Mbps + targetBitrateBps di /status) + uji; perbaikan E0308 build Windows; pindah konstanta/perakit NVENC ke nvenc_config.rs + uji | 2026-09-03 |
