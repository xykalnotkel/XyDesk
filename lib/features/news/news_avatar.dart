//! Identitas visual berita — diport 1:1 dari web (`web/src/news.ts`).
//!
//! Tujuannya bukan sekadar "biar mirip": nama dan wajah komentator harus
//! dibangkitkan lewat aturan yang sama di setiap platform, supaya perangkat
//! yang sama selalu memunculkan identitas yang sama, dan nama sama tidak
//! pernah bisa memalsukan wajah resmi.
//!
//! Satu-satunya yang boleh "menyentuh" keputusan ini adalah server
//! (`news/src/worker.js`) lewat tanda `official`; file ini hanya menggambar
//! hasil keputusan itu, tidak pernah menebak dari nama.

/// Foto pendiri XySpace — dipakai untuk penulis artikel & komentar resmi.
/// Web memuat `/team/founder.jpg` dari domain ini; Flutter mengambil lewat
/// URL penuh karena tidak punya jaminan path relatif terhadap lokasi deploy.
const newsFounderAvatar = 'https://app.xydesk.my.id/team/founder.jpg';

/// Foto profil komentator — DiceBear `adventurer` SVG dari nama penulis
/// (gratis, tanpa kunci API, tanpa backend): nama sama = wajah sama, di
/// perangkat maupun platform mana pun.
///
/// Komentar resmi (`official`) TIDAK lewat sini — mereka memakai
/// [newsFounderAvatar]. Dipisah di sini supaya widget tidak perlu tahu
/// bahwa keputusan resmi berasal dari server.
String newsAvatarUrl(String author) {
  // `Uri.encodeComponent` setara `encodeURIComponent` di web; `&` dan `,`
  // di query harus tetap terbaca sebagai parameter oleh DiceBear.
  final seed = Uri.encodeComponent(author);
  return 'https://api.dicebear.com/9.x/adventurer/svg'
      '?seed=$seed'
      '&backgroundColor=ede9fe,fde68a,bbf7d0,bae6fd';
}
