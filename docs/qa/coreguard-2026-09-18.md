# COREGUARD — bukti dan batas

Role: Operator - XyDesk Team. Izin: SESI-20260918-OPERATOR-COREGUARD.
Operator memilih uji/push/deploy khusus patch autentikasi ini.

## Pemeriksaan lokal

- Baseline kode sebelum patch: 14 tes regresi baru, 2 PASS / 12 FAIL.
- Setelah patch: 171/171 unit backend PASS (termasuk 16 tes baru).
- `npm run test:runtime`: dry-run bundle dan runtime admin auth/SQLite PASS.
- `node tool/member-runtime-check.mjs`: Worker+SQLite nyata, legacy JWT sehat,
  5 revoke bersamaan => versi5, JWT lama401, OTP simultan =>200/401, fresh
  token ber-versi5 =>200, ban =>401 dan OTP login akun banned403.
- `node tool/history-runtime-check.mjs`: 21 write concurrent/retention20,
  account delete racing pending writes => zero orphan history PASS.
- Google RS256/JWKS lokal: audience lama dipertahankan, versi saat ini ikut
  pada JWT baru, akun banned403, audience berbeda401.
- Gangguan AuthStore pada gerbang ticket =>503, tidak fallback ke signature
  JWT saja. Tidak ada migrasi database/secret/version/konfigurasi OAuth.

## Batas keamanan dan bukti

Patch melindungi permintaan akun dan penerbitan ticket baru. Ticket yang
sudah terbit masih berlaku 5 menit; koneksi P2P aktif belum otomatis
terputus oleh account revoke/ban. /ws dan /turn-ice memerlukan penanganan
principal-bound ticket dan revocation aktif pada paket berikutnya.
Tidak ada uji Windows input/audio/video atau login akun Google produksi.
Host/web tidak berubah; bukan bukti HD/120fps/microphone selesai.

## Produksi

Hasil pascadeploy dicatat pada coreguard-production-2026-09-18.json.
Pemeriksaan produksi tidak memblokir/mencabut akun pengguna nyata.
