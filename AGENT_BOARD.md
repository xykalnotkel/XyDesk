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
| SESI-20260903-CAKRA-CI | Cakra - XySpace Team | CI / Release | LAGI KERJA | Filter CI per-area + papan koordinasi + gerbang izin push | 2026-09-03 |

## Antrean izin push

| ID Sesi | Agent | Ringkasan perubahan | Status izin | Disetujui oleh | Kapan | Run CI |
|---|---|---|---|---|---|---|
| SESI-20260903-CAKRA-CI | Cakra - XySpace Team | Filter area di `build.yml` (job `changes` + jobs terpisah), `check-meta`/`check-news`/`check-signaling` baru, skip gracful `deploy-web.yml`, workflow `verify-push-auth.yml`, `AGENT_BOARD.md`, pembaruan `AGENT.md`/`docs/CI.md`/`CHANGELOG.md`/`CONTRIBUTORS.md` | DISETUJUI | Xyckal | 2026-09-03 | — |

## Riwayat sesi (hanya bertambah)

| ID Sesi | Agent | Area | Status | Ringkasan | Selesai |
|---|---|---|---|---|---|
| — | — | — | — | — | — |
