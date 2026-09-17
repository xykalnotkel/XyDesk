# Session follow-up — 17 September 2026

## Field evidence

- User: panah tidak terlihat pada normal maupun fullscreen Android. Kontrol
  lain belum dikonfirmasi gagal; audio belum diuji. Root cause di perangkat
  belum teridentifikasi (tidak ada screenshot/DOM diagnostics dari HP).
- Live sebelum patch: JS index-BKgmZPbY.js dan CSS index-DMLqdJzN.css memang
  berisi overlay lama. Ini tidak membuktikan tab HP memuat berkas tersebut.

## Diterapkan pada tahap web

- Overlay HTML + SVG36x48, compositing terpisah, hotspot tetap tepat saat
  panah dibalik di tepi agar bentuk tidak terpotong seluruhnya. Fallback
  posisi saat metadata belum ada; pemulihan layout1Hz dan DOM writes lewat
  RAF; tombol Temukan panah. Diagnostik Penunjuk kontrol = pointer-v2.
- Audio play eksplisit, error autoplay terlihat + retry gesture; mute elemen
  dan receiver.track.enabled, bukan direction tanpa SDP renegosiasi. Mic
  sender tidak dihentikan. Byte/energi audio serta state pemutar ditampilkan;
  bukan klaim suara benar-benar terdengar di HP.
- Preferensi quality/bitrate dikirim sekali setelah meta/channel tersedia,
  bukan hanya pilihan UI di localStorage. Host bisa membatasi target. Tidak
  ada ACK encoder efektif pada protokol lama; jangan klaim semua setelan
  sudah diterapkan/dibuktikan di host hanya karena data terkirim.
- Label adaptif dibetulkan: auto lama hanya mengatur default8Mbps, bukan
  algoritma adaptive bitrate. Label baru Bawaan host.
- URL #session/<64-hex> memakai256bit CSPRNG, tidak memuat ID/password/JWT.
  Ini ID tampilan saja, BUKAN otorisasi atau pemulihan sesi. Tidak menyimpan
  PIN pairing di browser untuk membuat reconnect palsu.

## Belum diterapkan — jangan ditandai selesai

### Refresh resume

Refresh menghancurkan PeerConnection browser. RtcSession baru mengganti ID
client; Hub close mengirim bye; host melepas pairing. URL acak tidak bisa
mengubah itu. Kontrak berikut perlu implementasi lintas host/Hub/web + tes:

1. Host menerbitkan tiket resume acak setelah pairing yang sah, terikat ke
   sesi/host dan kedaluwarsa pendek, disimpan sebagai hash di host. Tiket
   browser hanya sessionStorage tab, bukan URL/localStorage/PIN tersimpan.
2. Pair-resume baru memvalidasi tiket, memutar token sekali pakai dan hanya
   mengganti sesi milik tiket tersebut. Tidak melonggarkan duplicate-ID guard.
3. Bedakan putus eksplisit/revoke (cabut tiket) dari transport refresh (grace).
   Close callback lama tidak boleh meruntuhkan generasi sesi pengganti.
4. Uji replay, expiry, host lain, token salah, dua tab bersaing, revoke,
   restart host, tab refresh/network drop dan kontrol/media setelah resume.

### 120fps dan pengaturan efektif

- Software production dibatasi1280x720/30fps/14Mbps, H264Level3.1. NVENC saat
  ini masih nominal60fps termasuk durasi input encoder. Mengganti label/UI
  atau menaikkan konstanta saja mengulangi risiko SPS/SDP mismatch.
- Butuh kemampuan decoder + encoder/driver, negosiasi profil/level yang cocok,
  FPS120 di capture/encoder/RTP timestamps, ACK effective settings dan fallback
 30/60 bila tidak didukung. Wajib decode/RTP/input regresi dan uji hardware.
- Tidak ada klaim 120fps di VM GDI/OpenH264 pengguna. Tidak ada driver/RDP
  changes atau penggantian jalur software yang sudah menampilkan gambar.

### Audio Windows

Frontend playback/mute teruji, WASAPI/Opus output/mic Windows belum diuji pada
VM pengguna. Butuh log status audio singkat serta uji sumber suara PC dan
counter audio; jangan menganggap zero energy saat sumber diam sebagai bug.
