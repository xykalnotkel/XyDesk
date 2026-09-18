# Bound session — lingkup dan bukti

Role Operator - XyDesk Team; SESI-20260918-OPERATOR-BOUNDSESSION.

## Lolos lokal

- 181/181 unit backend (171 sebelumnya +10 regresi baru).
- Dry-run bundle dan runtime admin auth/SQLite.
- Runtime member generation/OTP concurrency, history retention/delete race.
- Runtime Worker+SQLite+WebSocket nyata dan alarm DO asli, tanpa memicu alarm
  secara manual: ticket baru berawalan v2; ticket lama dari akun dicabut
  WS401/TURN403; client diam ditutup1008 dan host mendapat bye sekitar15s.
  Guest dengan expiry pendek ditutup, host serta guest sehat tidak ditutup.
- Anti-spoof header principal, id/role/audience/signature, storage outage,
  expired guest, subject index cleanup dan alarm tidak ditunda oleh koneksi
  baru diuji. Tidak menambahkan dependensi atau migrasi schema.

## Batas

Host runtime adalah simulator signaling, bukan Rust/Windows/media P2P.
Kode host menangani bye untuk menutup Session dan revoke PairGuard; belum
ada bukti video/input nyata berhenti pada VM pengguna. Pemeriksaan berkala
~15s bukan deadline keras. Bila Hub tak bisa mencapai host, butuh lease
lokal pada host untuk batas pemutusan yang kuat; belum diimplementasikan.

Koneksi legacy tanpa principal tetap hidup agar tidak memutus pengguna
massal. Sambung ulang dengan ticket baru diperlukan. Ticket legacy yang
belum kedaluwarsa serta /issue operator tetap kompatibel. Kredensial TURN
yang sudah diterbitkan tidak dicabut oleh paket ini.

Tidak ada perubahan web, host, APK, installer, secret, OAuth atau versi.
Tidak ada akun produksi diblokir/dicabut demi pengujian.
