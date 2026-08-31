# XyDesk — Dokumen Legal & Lisensi Lengkap

> Berlaku sejak: 31 Agustus 2026 · Versi dokumen: 1.0 (rilis 6.0)
> Dokumen ini adalah sumber kebenaran legal untuk aplikasi XyDesk
> (Android, Desktop Windows, dan Web) di semua platform.

---

## 1. Sifat lisensi XyDesk — PROPRIETARY

XyDesk adalah perangkat lunak **proprietary (bukan sumber terbuka)** milik
**XySpace Tech (xykalnotkel)**. Kode sumber XyDesk adalah rahasia dagang
dan dilindungi hukum hak cipta (UU No. 28 Tahun 2014 tentang Hak Cipta,
serta perjanjian hak cipta internasional yang berlaku).

**DIPERBOLEHKAN:**

- Memakai aplikasi XyDesk (biner/APK/installer resmi) untuk keperluan
  pribadi maupun bisnis pada perangkat milikmu sendiri atau yang kamu
  berwenang kelola.
- Membagikan tautan unduhan resmi ke rilis XyDesk.

**DILARANG — tanpa izin tertulis dari XySpace Tech:**

1. **Meng-clone, menyalin, atau mendistribusikan ulang kode sumber**,
   sebagian maupun seluruhnya, untuk tujuan apa pun.
2. Menggandakan, memodifikasi, merekayasa balik (reverse engineering),
   mendekompilasi, atau membongkar aplikasi.
3. Memakai nama, logo, atau merek XyDesk pada produk atau layanan lain.
4. Menjual, menyewakan, atau menyublisensikan XyDesk atau turunannya.
5. Menghapus atau mengubah pemberitahuan hak cipta.

Pelanggaran akan ditindak sesuai hukum yang berlaku, termasuk tuntutan
atas pelanggaran hak cipta dan rahasia dagang.

---

## 2. Kebijakan Privasi (Privacy Policy)

### 2.1 Data yang diproses

| Data | Tujuan | Penyimpanan |
|---|---|---|
| ID host & password pairing | Menghubungkan perangkat | Dihasilkan lokal; diverifikasi di sisi host |
| Email (opsional) | Login OTP + langganan berita | Hash OTP sementara; email di basis berita |
| Nama tampilan akun (opsional) | Profil | Basis pengguna layanan |
| Sidik jari perangkat (fingerprint lokal) | Like & komentar berita (anti ganda) | Disimpan LOKAL di perangkat |
| Media sesi (layar + audio) | Streaming remote | **TIDAK disimpan** — peer-to-peer (WebRTC, DTLS-SRTP) |
| Statistik agregat (anonim) | Peningkatan layanan | Tanpa identitas pengguna |

### 2.2 Yang TIDAK kami lakukan

- **Tidak menyimpan, merekam, atau melihat media sesi** — media mengalir
  langsung antar perangkat lewat WebRTC; server hanya mempertemukan.
- Tidak menjual data pengguna.
- Tidak memindai isi layar atau isi berkas pengguna.

### 2.3 Notifikasi

- Push notifikasi (OneSignal) hanya untuk: rilis aplikasi, berita XyDesk,
  dan pengumuman keamanan penting.
- Email berita hanya dikirim bila kamu berlangganan; bisa berhenti kapan
  saja (balas email berhenti atau lewat aplikasi).

### 2.4 Hak pengguna

- Meminta salinan, perbaikan, atau penghapusan data akun:
  legal@xydesk.app.
- Data media sesi tidak pernah kami miliki, sehingga tidak dapat
  diminta — karena memang tidak disimpan.

---

## 3. Syarat & Ketentuan (Terms of Service)

1. **Penerimaan** — dengan memakai XyDesk kamu setuju pada ketentuan ini.
2. **Penggunaan yang diizinkan** — hanya untuk perangkat milik sendiri
   atau yang pemiliknya memberi izin sadar dan sukarela.
3. **Larangan** — akses tanpa izin; penipuan (termasuk berpura-pura
   menjadi petugas bank/layanan resmi untuk meminta akses remote);
   penyalahgunaan infrastruktur.
4. **Peringatan penipuan** — layanan resmi TIDAK PERNAH meminta kamu
   memasang aplikasi remote lalu menyebutkan ID & password. Itu penipuan.
5. **Ketersediaan** — layanan "sebagaimana adanya"; kami berusaha menjaga
   ketersediaan tanpa jaminan bebas gangguan.
6. **Batasan tanggung jawab** — sejauh diizinkan hukum, kami tidak
   bertanggung jawab atas kerugian tidak langsung.
7. **Perubahan** — ketentuan dapat berubah; perubahan penting
   diumumkan di aplikasi minimal 14 hari sebelumnya.

---

## 4. Lisensi Pihak Ketiga — lengkap dengan penjelasan

Semua UI/UX XyDesk dirancang sendiri oleh tim XyDesk. Berikut seluruh
komponen pihak ketiga yang dipakai, lisensinya, dan apa fungsinya.
Pencantuman di sini TIDAK mengubah status proprietary XyDesk.

### Android (Flutter)

| Komponen | Lisensi | Fungsi di XyDesk |
|---|---|---|
| Flutter SDK | BSD-3-Clause (Google) | Kerangka UI lintas platform |
| Dart SDK | BSD-3-Clause (Google) | Bahasa pemrograman aplikasi |
| flutter_riverpod | MIT (Remi Rousselet) | Manajemen state reaktif |
| go_router | BSD-3-Clause (Flutter Team) | Navigasi deklaratif |
| lucide_icons_flutter | ISC (Lucide Contributors) | Set ikon garis konsisten |
| Inter (font) | SIL Open Font License 1.1 (Rasmus Andersson) | Font antarmuka |
| shared_preferences | BSD-3-Clause (Flutter Team) | Penyimpanan key-value lokal |
| http | BSD-3-Clause (Dart Team) | Klien HTTP (berita, update) |
| google_sign_in | BSD-3-Clause (Flutter Team) | Masuk dengan Google |
| flutter_secure_storage | BSD-3-Clause (Flutter Team) | Penyimpanan kredensial terenkripsi |
| flutter_webrtc | MIT (Flutter WebRTC) | Binding WebRTC untuk sesi |
| libwebrtc | BSD-3-Clause (Google) | Implementasi media peer-to-peer |
| web_socket_channel | BSD-3-Clause (Dart Team) | Kanal signaling |
| package_info_plus | BSD-3-Clause (Flutter Community) | Metadata versi aplikasi |
| url_launcher | BSD-3-Clause (Flutter Team) | Membuka tautan eksternal |
| mobile_scanner | BSD-3-Clause (Mobile Scanner) | Pemindai QR (CameraX/MLKit) |
| onesignal_flutter | Ketentuan OneSignal | Notifikasi push |
| share_plus | BSD-3-Clause (Flutter Community) | Berbagi tautan berita |

### Desktop Windows (Electron + Next.js)

| Komponen | Lisensi | Fungsi di XyDesk |
|---|---|---|
| Electron | MIT (OpenJS Foundation) | Cangkang aplikasi desktop |
| Next.js | MIT (Vercel) | Render UI panel |
| React | MIT (Meta) | Komponen UI |
| lucide-react | ISC (Lucide Contributors) | Ikon panel |
| TypeScript | Apache-2.0 (Microsoft) | Bahasa pengembangan shell |
| NVENC SDK | Lisensi SDK NVIDIA | Encode video hardware (engine Rust) |

### Host (Rust)

| Komponen | Lisensi | Fungsi di XyDesk |
|---|---|---|
| tokio | MIT | Runtime asinkron |
| tokio-tungstenite | MIT | WebSocket signaling |
| webrtc (webrtc-rs) | MIT / Apache-2.0 | Media WebRTC host |
| serde / serde_json | MIT / Apache-2.0 | Serialisasi protokol |
| openh264 | BSD-2-Clause (Cisco) | Encode fallback CPU |
| windows-rs | MIT / Apache-2.0 (Microsoft) | Akses API Windows (DXGI, dll.) |
| tracing | MIT | Log terstruktur |

### Web (Vite + React) & Infrastruktur

| Komponen | Lisensi | Fungsi di XyDesk |
|---|---|---|
| React | MIT (Meta) | Komponen UI web |
| Vite | MIT | Bundler aplikasi web |
| TypeScript | Apache-2.0 (Microsoft) | Bahasa pengembangan |
| lucide-react | ISC | Ikon |
| Inter (font) | SIL OFL 1.1 | Font antarmuka |
| Cloudflare Workers | Layanan Cloudflare | Signaling + API berita + hosting |
| Cloudflare D1 | Layanan Cloudflare | Basis data berita |
| Cloudflare Durable Objects | Layanan Cloudflare | Hub signaling |
| Resend | Layanan Resend | Email langganan berita |
| OneSignal | Layanan OneSignal | Push notifikasi |

**Catatan lisensi layanan:** Cloudflare, Resend, OneSignal, dan NVIDIA
bukan pustaka kode — penggunaannya tunduk pada Ketentuan Layanan
masing-masing penyedia, bukan lisensi sumber terbuka.

---

## 5. Kontak

- Legal & privasi: legal@xydesk.app
- Keamanan (laporan kerentanan): legal@xydesk.app (subjek: SECURITY)
