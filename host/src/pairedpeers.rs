//! Daftar peer yang sudah lulus pairing — gerbang untuk `offer` dan `ice`.
//!
//! ## Kenapa modul ini ada
//!
//! [`crate::pairguard`] menjaga pintu depan: ia membatasi laju tebakan password
//! pada pesan `pair`. Tapi menjaga pintu depan tidak ada gunanya kalau jendela
//! di sampingnya terbuka.
//!
//! Sampai modul ini ada, host memproses `offer` dari peer mana pun yang
//! mengirimnya. Penyerang tidak perlu menebak password satu kali pun: cukup
//! `hello`, lalu langsung `offer`. Host menjawab, membuka data channel `input`,
//! dan `SendInput` mulai mengeksekusi gerakan mouse serta ketukan keyboard di
//! mesin korban. Seluruh pertahanan brute force di `pairguard` dilewati begitu
//! saja karena jalur yang dijaga bukan jalur yang dipakai.
//!
//! `record_success` di `pairguard` tidak bisa dipakai untuk ini: fungsinya
//! hanya MENGHAPUS catatan kegagalan peer. Ketiadaan catatan kegagalan tidak
//! sama dengan bukti keberhasilan — peer yang belum pernah mencoba sama sekali
//! juga tidak punya catatan. Keputusan "boleh membuka sesi media" butuh state
//! positif tersendiri, dan itulah yang disimpan di sini.
//!
//! ## Model
//!
//! Setiap peer melewati paling banyak tiga keadaan:
//!
//! ```text
//!   (tidak dikenal) --pair sukses--> Granted --offer--> Active --bye--> (hapus)
//!                                       |
//!                                  OFFER_WINDOW habis
//!                                       v
//!                                   (hapus)
//! ```
//!
//! - **Granted** berumur pendek ([`OFFER_WINDOW`]). Pairing yang sukses adalah
//!   izin untuk MEMULAI sesi sekarang, bukan kunci permanen. Kalau client tidak
//!   melanjutkan ke `offer` dalam jendela itu, izinnya hangus dan ia harus
//!   memasukkan password lagi. Ini membatasi nilai sebuah pairing yang berhasil
//!   dicuri (misalnya lewat log signaling) menjadi hitungan detik.
//! - **Active** tidak kedaluwarsa selama sesi berjalan. Sesi remote desktop
//!   yang sah bisa berlangsung berjam-jam; memutusnya di tengah karena timer
//!   izin akan jadi bug, bukan fitur keamanan.
//!
//! Kandidat ICE diperiksa terhadap keadaan **Active** saja. Kandidat dari peer
//! yang belum pernah mengirim offer tidak punya alasan sah untuk ada, dan
//! menyuntikkan kandidat ke sesi milik orang lain adalah cara paling murah
//! untuk mengganggu koneksi yang sedang berjalan.
//!
//! ## Yang sengaja TIDAK dilakukan di sini
//!
//! Modul ini tidak menyentuh password sama sekali, tidak tahu isinya, dan tidak
//! membandingkan apa pun. Ia hanya mencatat keputusan yang sudah diambil di
//! tempat lain. Pemisahan ini disengaja supaya kebijakan sesi bisa diuji tanpa
//! kripto, dan supaya tidak ada dua tempat berbeda yang mengklaim tahu apakah
//! sebuah password benar.

use std::collections::HashMap;
use std::time::{Duration, Instant};

/// Lama izin `offer` berlaku setelah pairing sukses.
///
/// Cukup longgar untuk jaringan lambat (client masih perlu mengambil kredensial
/// TURN dan menyusun SDP), cukup ketat supaya izin yang bocor cepat basi.
pub const OFFER_WINDOW: Duration = Duration::from_secs(120);

/// Batas jumlah peer yang dilacak sekaligus.
///
/// Hanya peer yang LULUS pairing yang bisa masuk peta ini, jadi mengisinya
/// menuntut penyerang mengetahui password — jauh lebih mahal daripada mengisi
/// peta di `pairguard`. Batas ini tetap dipasang sebagai jaring pengaman
/// terhadap client sah yang bermasalah dan menyambung ulang berkali-kali.
pub const MAX_TRACKED_PEERS: usize = 256;

/// Keadaan satu peer yang sudah lulus pairing.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum PeerPhase {
    /// Lulus pairing, menunggu `offer`. Kedaluwarsa pada waktu tercatat.
    Granted { expires_at: Instant },
    /// Offer diterima, sesi media berjalan. Tidak kedaluwarsa.
    Active,
}

/// Alasan sebuah `offer` atau `ice` ditolak. Dipakai untuk log yang jujur.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RejectReason {
    /// Peer tidak pernah lulus pairing.
    NotPaired,
    /// Peer pernah lulus, tetapi jendela `offer` sudah lewat.
    Expired,
    /// Host sudah melayani sesi aktif milik peer lain.
    HostBusy,
}

impl RejectReason {
    pub fn as_str(self) -> &'static str {
        match self {
            RejectReason::NotPaired => "belum-pairing",
            RejectReason::Expired => "izin-kedaluwarsa",
            RejectReason::HostBusy => "host-sibuk",
        }
    }
}

/// Label yang dilaporkan sendiri oleh satu peer, dari pesan `pair`
/// (`name` + `platform`). Hanya untuk tampilan: host memakai ini untuk
/// menunjukkan SIAPA yang sedang menonton layarnya (mis. "Redmi Note 12 ·
/// Android" di panel host dan di tooltip tray), bukan untuk membuat keputusan
/// keamanan apa pun. Nilainya boleh dikarang peer — karena itu ia tidak pernah
/// masuk log keputusan pairing.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct PeerLabel {
    pub name: Option<String>,
    pub platform: Option<String>,
}

impl PeerLabel {
    /// `None` bila peer tidak mengirim apa yang layak ditampilkan.
    pub fn new(name: Option<String>, platform: Option<String>) -> Option<Self> {
        let clean = |v: Option<String>| {
            v.map(|s| s.trim().chars().take(48).collect::<String>())
                .filter(|s| !s.is_empty())
        };
        let (name, platform) = (clean(name), clean(platform));
        if name.is_none() && platform.is_none() {
            return None;
        }
        Some(Self { name, platform })
    }
}

/// Registri peer yang berhak membuka sesi media. Satu instance per proses host.
///
/// Seperti [`crate::pairguard::PairGuard`], semua metode menerima `now` secara
/// eksplisit agar kedaluwarsa dapat diuji tanpa menunggu waktu nyata.
#[derive(Debug, Default)]
pub struct PairedPeers {
    peers: HashMap<String, PeerPhase>,
    /// Label per peer, hidup sepanjang izin peer itu (dibuang bersama `revoke`).
    labels: HashMap<String, PeerLabel>,
}

impl PairedPeers {
    pub fn new() -> Self {
        Self {
            peers: HashMap::new(),
            labels: HashMap::new(),
        }
    }

    /// Catat pairing yang berhasil: peer boleh mengirim `offer` sampai
    /// [`OFFER_WINDOW`] berlalu.
    ///
    /// Memanggil ini pada peer yang sudah `Active` TIDAK menurunkan statusnya
    /// kembali menjadi `Granted`. Client sah yang mengirim ulang `pair` di
    /// tengah sesi (misalnya karena UI-nya di-reload) tidak boleh membuat sesi
    /// yang sedang berjalan jadi rapuh.
    pub fn grant(&mut self, peer: &str, now: Instant) {
        if matches!(self.peers.get(peer), Some(PeerPhase::Active)) {
            return;
        }
        self.evict_if_needed(now);
        self.peers.insert(
            peer.to_string(),
            PeerPhase::Granted {
                expires_at: now + OFFER_WINDOW,
            },
        );
    }

    /// Periksa apakah `peer` boleh membuka sesi dengan `offer`.
    ///
    /// Bila boleh, peer langsung dinaikkan ke `Active` dan `Ok(())` dikembalikan
    /// — pemanggil tidak perlu melakukan pembukuan tambahan.
    pub fn authorize_offer(&mut self, peer: &str, now: Instant) -> Result<(), RejectReason> {
        // Sesi milik orang lain tidak boleh diambil alih diam-diam. Host PoC ini
        // melayani satu sesi pada satu waktu; tanpa pemeriksaan ini, peer kedua
        // yang tahu password bisa menendang peer pertama tanpa jejak.
        if let Some(other) = self.active_peer() {
            if other != peer {
                return Err(RejectReason::HostBusy);
            }
        }

        match self.peers.get(peer).copied() {
            None => Err(RejectReason::NotPaired),
            Some(PeerPhase::Granted { expires_at }) => {
                if now >= expires_at {
                    // Izin basi dibuang, bukan dibiarkan menumpuk.
                    self.peers.remove(peer);
                    Err(RejectReason::Expired)
                } else {
                    self.peers.insert(peer.to_string(), PeerPhase::Active);
                    Ok(())
                }
            }
            // Renegosiasi dari peer yang sesinya sedang aktif tetap sah.
            Some(PeerPhase::Active) => Ok(()),
        }
    }

    /// Benar bila `peer` sedang memegang sesi aktif — syarat untuk menerima
    /// kandidat ICE darinya.
    pub fn is_active(&self, peer: &str) -> bool {
        matches!(self.peers.get(peer), Some(PeerPhase::Active))
    }

    /// Peer yang sedang memegang sesi aktif, bila ada.
    pub fn active_peer(&self) -> Option<&str> {
        self.peers
            .iter()
            .find(|(_, phase)| matches!(phase, PeerPhase::Active))
            .map(|(peer, _)| peer.as_str())
    }

    /// Catat label peer (nama perangkat + platform) untuk ditampilkan host.
    pub fn set_label(&mut self, peer: &str, label: Option<PeerLabel>) {
        match label {
            Some(l) => {
                // Label hanya untuk peer yang dikenal; kalau daftarnya sudah
                // penuh, tampilan boleh kalah dibanding memorinya.
                if self.peers.contains_key(peer) || self.labels.len() < MAX_TRACKED_PEERS {
                    self.labels.insert(peer.to_string(), l);
                }
            }
            None => {
                self.labels.remove(peer);
            }
        }
    }

    /// Label peer, bila ada.
    pub fn label_of(&self, peer: &str) -> Option<&PeerLabel> {
        self.labels.get(peer)
    }

    /// Cabut seluruh hak `peer` (dipanggil saat `bye` atau sesi ditutup).
    ///
    /// Setelah ini, peer harus memasukkan password lagi untuk menyambung ulang.
    /// Sesi yang sudah berakhir bukan alasan untuk mempercayai peer selamanya.
    pub fn revoke(&mut self, peer: &str) {
        self.peers.remove(peer);
        self.labels.remove(peer);
    }

    /// Buang izin `Granted` yang sudah kedaluwarsa. Aman dipanggil kapan saja;
    /// peer `Active` tidak pernah tersentuh.
    pub fn sweep_expired(&mut self, now: Instant) {
        self.peers.retain(|_, phase| match phase {
            PeerPhase::Granted { expires_at } => now < *expires_at,
            PeerPhase::Active => true,
        });
        self.drop_orphan_labels();
    }

    /// Label tanpa izin adalah sampah: peer-nya sudah revoker/kedaluwarsa.
    fn drop_orphan_labels(&mut self) {
        self.labels.retain(|peer, _| self.peers.contains_key(peer));
    }

    /// Jumlah peer yang sedang dilacak (dipakai test dan diagnostik).
    pub fn tracked(&self) -> usize {
        self.peers.len()
    }

    /// Jaga ukuran peta. Yang dibuang hanya izin `Granted` — sesi `Active`
    /// tidak boleh diputus oleh housekeeping.
    fn evict_if_needed(&mut self, now: Instant) {
        if self.peers.len() < MAX_TRACKED_PEERS {
            return;
        }
        self.sweep_expired(now);
        if self.peers.len() < MAX_TRACKED_PEERS {
            return;
        }
        let oldest = self
            .peers
            .iter()
            .filter_map(|(peer, phase)| match phase {
                PeerPhase::Granted { expires_at } => Some((peer.clone(), *expires_at)),
                PeerPhase::Active => None,
            })
            .min_by_key(|(_, expires_at)| *expires_at)
            .map(|(peer, _)| peer);
        if let Some(peer) = oldest {
            self.peers.remove(&peer);
            self.labels.remove(&peer);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn t0() -> Instant {
        Instant::now()
    }

    #[test]
    fn offer_tanpa_pairing_ditolak() {
        let now = t0();
        let mut p = PairedPeers::new();
        assert_eq!(
            p.authorize_offer("penyusup", now),
            Err(RejectReason::NotPaired)
        );
    }

    #[test]
    fn offer_setelah_pairing_diterima() {
        let now = t0();
        let mut p = PairedPeers::new();
        p.grant("sah", now);
        assert_eq!(p.authorize_offer("sah", now), Ok(()));
        assert!(p.is_active("sah"));
    }

    #[test]
    fn izin_offer_kedaluwarsa() {
        let now = t0();
        let mut p = PairedPeers::new();
        p.grant("lambat", now);
        let telat = now + OFFER_WINDOW + Duration::from_secs(1);
        assert_eq!(
            p.authorize_offer("lambat", telat),
            Err(RejectReason::Expired)
        );
        // Izin basi ikut dibersihkan, bukan menumpuk di memori.
        assert_eq!(p.tracked(), 0);
    }

    #[test]
    fn izin_masih_berlaku_tepat_sebelum_batas() {
        let now = t0();
        let mut p = PairedPeers::new();
        p.grant("mepet", now);
        let hampir = now + OFFER_WINDOW - Duration::from_millis(1);
        assert_eq!(p.authorize_offer("mepet", hampir), Ok(()));
    }

    #[test]
    fn pairing_peer_lain_tidak_memberi_hak_pada_penyusup() {
        let now = t0();
        let mut p = PairedPeers::new();
        p.grant("sah", now);
        assert_eq!(
            p.authorize_offer("penyusup", now),
            Err(RejectReason::NotPaired)
        );
    }

    #[test]
    fn ice_hanya_diterima_dari_sesi_aktif() {
        let now = t0();
        let mut p = PairedPeers::new();
        p.grant("sah", now);
        // Sudah lulus pairing, tetapi belum mengirim offer.
        assert!(!p.is_active("sah"));
        assert!(p.authorize_offer("sah", now).is_ok());
        assert!(p.is_active("sah"));
        assert!(!p.is_active("orang-lain"));
    }

    #[test]
    fn sesi_aktif_tidak_bisa_direbut_peer_lain() {
        let now = t0();
        let mut p = PairedPeers::new();
        p.grant("pertama", now);
        assert!(p.authorize_offer("pertama", now).is_ok());
        // Peer kedua bahkan yang sudah lulus pairing tetap harus menunggu.
        p.grant("kedua", now);
        assert_eq!(p.authorize_offer("kedua", now), Err(RejectReason::HostBusy));
    }

    #[test]
    fn renegosiasi_dari_peer_aktif_tetap_sah() {
        let now = t0();
        let mut p = PairedPeers::new();
        p.grant("sah", now);
        assert!(p.authorize_offer("sah", now).is_ok());
        let nanti = now + OFFER_WINDOW * 10;
        // Sesi aktif tidak kedaluwarsa; offer ulang (ICE restart) tetap boleh.
        assert_eq!(p.authorize_offer("sah", nanti), Ok(()));
    }

    #[test]
    fn pair_ulang_tidak_menurunkan_sesi_aktif() {
        let now = t0();
        let mut p = PairedPeers::new();
        p.grant("sah", now);
        assert!(p.authorize_offer("sah", now).is_ok());
        p.grant("sah", now);
        assert!(
            p.is_active("sah"),
            "sesi aktif tidak boleh turun jadi granted"
        );
    }

    #[test]
    fn bye_mencabut_hak_dan_membebaskan_host() {
        let now = t0();
        let mut p = PairedPeers::new();
        p.grant("pertama", now);
        assert!(p.authorize_offer("pertama", now).is_ok());
        p.revoke("pertama");
        assert!(!p.is_active("pertama"));
        assert_eq!(
            p.authorize_offer("pertama", now),
            Err(RejectReason::NotPaired),
            "menyambung ulang wajib pairing lagi"
        );
        // Host kembali bebas untuk peer lain.
        p.grant("kedua", now);
        assert_eq!(p.authorize_offer("kedua", now), Ok(()));
    }

    #[test]
    fn sweep_membuang_yang_basi_tapi_menjaga_yang_aktif() {
        let now = t0();
        let mut p = PairedPeers::new();
        p.grant("aktif", now);
        assert!(p.authorize_offer("aktif", now).is_ok());
        p.grant("nganggur", now);
        p.sweep_expired(now + OFFER_WINDOW + Duration::from_secs(1));
        assert!(p.is_active("aktif"));
        assert_eq!(p.tracked(), 1);
    }

    #[test]
    fn peta_tidak_tumbuh_tanpa_batas() {
        let now = t0();
        let mut p = PairedPeers::new();
        for i in 0..(MAX_TRACKED_PEERS * 2) {
            p.grant(&format!("peer-{i}"), now);
        }
        assert!(p.tracked() <= MAX_TRACKED_PEERS);
    }

    #[test]
    fn sesi_aktif_selamat_dari_tekanan_memori() {
        let now = t0();
        let mut p = PairedPeers::new();
        p.grant("aktif", now);
        assert!(p.authorize_offer("aktif", now).is_ok());
        for i in 0..(MAX_TRACKED_PEERS * 2) {
            p.grant(&format!("banjir-{i}"), now);
        }
        assert!(
            p.is_active("aktif"),
            "sesi berjalan tidak boleh tergusur oleh banjir pairing"
        );
    }
}

#[cfg(test)]
mod label_tests {
    use super::*;

    #[test]
    fn label_hidup_bersama_izin_dan_mati_bersama_revoke() {
        let now = Instant::now();
        let mut p = PairedPeers::new();
        p.grant("hp-1", now);
        p.set_label(
            "hp-1",
            PeerLabel::new(Some("Redmi Note 12".into()), Some("android".into())),
        );
        assert!(p.authorize_offer("hp-1", now).is_ok());
        let l = p.label_of("hp-1").expect("label tercatat");
        assert_eq!(l.name.as_deref(), Some("Redmi Note 12"));
        assert_eq!(l.platform.as_deref(), Some("android"));

        p.revoke("hp-1");
        assert!(p.label_of("hp-1").is_none(), "label tidak boleh bertahan");
    }

    #[test]
    fn label_kosong_dianggap_tidak_ada() {
        // Client lama tidak mengirim name/platform sama sekali; host harus
        // jatuh ke tampilan ID, bukan "• " dengan nama kosong.
        assert!(PeerLabel::new(None, None).is_none());
        assert!(PeerLabel::new(Some("   ".into()), Some("".into())).is_none());
    }

    #[test]
    fn label_dipangkas_dan_tidak_membesar_sesuka_peer() {
        let l = PeerLabel::new(Some("x".repeat(400)), Some("y".repeat(900))).expect("ada");
        assert_eq!(l.name.unwrap().chars().count(), 48);
        assert_eq!(l.platform.unwrap().chars().count(), 48);

        let now = Instant::now();
        let mut p = PairedPeers::new();
        for i in 0..(MAX_TRACKED_PEERS * 2) {
            p.grant(&format!("peer-{i}"), now);
            p.set_label(
                &format!("peer-{i}"),
                PeerLabel::new(Some("hp".into()), None),
            );
        }
        assert!(p.labels.len() <= MAX_TRACKED_PEERS);
        assert!(p.tracked() <= MAX_TRACKED_PEERS);
    }

    #[test]
    fn izin_basi_membawa_labelnya_pergi() {
        let now = Instant::now();
        let mut p = PairedPeers::new();
        p.grant("lambat", now);
        p.set_label("lambat", PeerLabel::new(Some("HP lama".into()), None));
        p.sweep_expired(now + OFFER_WINDOW + Duration::from_secs(1));
        assert!(p.label_of("lambat").is_none());
    }
}
