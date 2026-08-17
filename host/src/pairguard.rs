//! Pertahanan brute force untuk pairing.
//!
//! ## Kenapa modul ini ada
//!
//! Password pairing 8 karakter dari charset 32 simbol punya ruang 32^8 ~ 1.1
//! triliun kombinasi. Terdengar aman, dan memang aman TERHADAP tebakan acak
//! satu per satu. Tapi entropi bukan satu-satunya pertahanan yang dibutuhkan.
//!
//! Device ID host disiarkan ke SEMUA client lewat pesan `devices` di signaling.
//! Artinya penyerang tidak perlu menebak ID: dia login sebagai pengguna biasa,
//! menerima daftar lengkap host yang online, lalu menggempur `pair` pada target
//! pilihannya. Tanpa rem, laju percobaan hanya dibatasi kecepatan jaringan.
//! Pada 1.000 percobaan per detik, ruang 32^8 habis dalam ~35 tahun; tetapi
//! password yang dipilih manusia lewat `--set-password` (diizinkan mulai 6
//! karakter, sering kata biasa) bisa jatuh dalam hitungan menit.
//!
//! Pairing yang berhasil membuka data channel `input`, yang berarti `SendInput`
//! di mesin korban. Itu kendali keyboard dan mouse penuh, bukan sekadar melihat
//! layar. Jadi biaya kegagalan di sini setara dengan kompromi total host.
//!
//! ## Model pertahanan
//!
//! Tiga lapis, masing-masing menutup celah yang tidak ditutup lapis lain:
//!
//! 1. **Lockout per peer.** Setelah [`MAX_FAILURES_PER_PEER`] kegagalan, peer
//!    itu diblokir selama [`PEER_LOCKOUT`]. Menghentikan penyerang tunggal.
//! 2. **Lockout global.** Setelah [`MAX_FAILURES_GLOBAL`] kegagalan dari peer
//!    mana pun dalam [`GLOBAL_WINDOW`], SEMUA pairing ditolak selama
//!    [`GLOBAL_LOCKOUT`]. Ini yang menutup serangan terdistribusi: penyerang
//!    yang berganti-ganti device ID client tidak bisa mengakali batas per peer,
//!    karena identitas client di signaling bebas dipilih penyerang sendiri.
//! 3. **Penundaan tetap.** Setiap respons gagal ditunda [`FAILURE_DELAY`].
//!    Nilainya TETAP, tidak bergantung pada isi password maupun sejauh mana
//!    tebakan cocok, supaya waktu respons tidak membocorkan informasi.
//!
//! Keberhasilan pairing menghapus catatan kegagalan peer tersebut, sehingga
//! pengguna sah yang sempat salah ketik tidak dihukum berkepanjangan.
//!
//! ## Yang sengaja TIDAK dilakukan di sini
//!
//! Modul ini tidak menyentuh perbandingan password itu sendiri. Perbandingan
//! timing-safe adalah tanggung jawab [`crate::identity::verify_password`].
//! Pemisahan ini disengaja: kebijakan laju dan primitif kripto diuji terpisah.

use std::collections::HashMap;
use std::time::{Duration, Instant};

/// Kegagalan berturut-turut dari satu peer sebelum peer itu dikunci.
pub const MAX_FAILURES_PER_PEER: u32 = 3;
/// Lama penguncian satu peer setelah melewati batas.
pub const PEER_LOCKOUT: Duration = Duration::from_secs(300);
/// Kegagalan total lintas peer sebelum penguncian global.
pub const MAX_FAILURES_GLOBAL: u32 = 10;
/// Jendela pengamatan untuk hitungan global.
pub const GLOBAL_WINDOW: Duration = Duration::from_secs(600);
/// Lama penguncian global.
pub const GLOBAL_LOCKOUT: Duration = Duration::from_secs(900);
/// Penundaan tetap sebelum membalas percobaan yang gagal.
pub const FAILURE_DELAY: Duration = Duration::from_millis(1000);
/// Batas jumlah peer yang dilacak, mencegah pertumbuhan memori tak terbatas
/// bila penyerang mengarang identitas baru tiap percobaan.
pub const MAX_TRACKED_PEERS: usize = 1024;

/// Keputusan penjaga untuk satu permintaan pairing.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Decision {
    /// Boleh memverifikasi password.
    Allow,
    /// Ditolak tanpa memverifikasi password. `retry_in` untuk pesan log.
    Denied {
        reason: DenyReason,
        retry_in: Duration,
    },
}

/// Alasan penolakan, dipisah supaya log bisa membedakan serangan tunggal dari
/// serangan terdistribusi.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DenyReason {
    /// Peer ini melewati batas kegagalannya sendiri.
    PeerLocked,
    /// Host sedang dalam penguncian global.
    GlobalLocked,
}

impl DenyReason {
    pub fn as_str(self) -> &'static str {
        match self {
            DenyReason::PeerLocked => "peer terkunci",
            DenyReason::GlobalLocked => "penguncian global",
        }
    }
}

#[derive(Debug, Clone)]
struct PeerState {
    failures: u32,
    locked_until: Option<Instant>,
    last_seen: Instant,
}

/// Penjaga laju pairing. Satu instance per proses host.
///
/// Semua metode menerima `now` secara eksplisit agar perilakunya dapat diuji
/// tanpa menunggu waktu nyata berlalu.
#[derive(Debug)]
pub struct PairGuard {
    peers: HashMap<String, PeerState>,
    global_failures: u32,
    global_window_start: Instant,
    global_locked_until: Option<Instant>,
}

impl PairGuard {
    pub fn new(now: Instant) -> Self {
        Self {
            peers: HashMap::new(),
            global_failures: 0,
            global_window_start: now,
            global_locked_until: None,
        }
    }

    /// Periksa apakah `peer` boleh mencoba pairing sekarang.
    ///
    /// Penguncian global diperiksa lebih dulu: bila host sedang dikunci, tidak
    /// ada gunanya membedakan peer.
    pub fn check(&mut self, peer: &str, now: Instant) -> Decision {
        if let Some(until) = self.global_locked_until {
            if now < until {
                return Decision::Denied {
                    reason: DenyReason::GlobalLocked,
                    retry_in: until.saturating_duration_since(now),
                };
            }
            // Penguncian global habis: mulai jendela pengamatan baru.
            self.global_locked_until = None;
            self.global_failures = 0;
            self.global_window_start = now;
        }

        if let Some(state) = self.peers.get_mut(peer) {
            if let Some(until) = state.locked_until {
                if now < until {
                    return Decision::Denied {
                        reason: DenyReason::PeerLocked,
                        retry_in: until.saturating_duration_since(now),
                    };
                }
                // Masa hukuman lewat: beri kesempatan bersih.
                state.locked_until = None;
                state.failures = 0;
            }
            state.last_seen = now;
        }

        Decision::Allow
    }

    /// Catat percobaan yang gagal. Mengembalikan `true` bila percobaan ini
    /// membuat peer terkunci, supaya pemanggil dapat menuliskan log tegas.
    pub fn record_failure(&mut self, peer: &str, now: Instant) -> bool {
        // Jendela global bergulir: reset hitungan bila sudah lewat.
        if now.duration_since(self.global_window_start) > GLOBAL_WINDOW {
            self.global_window_start = now;
            self.global_failures = 0;
        }
        self.global_failures += 1;
        if self.global_failures >= MAX_FAILURES_GLOBAL {
            self.global_locked_until = Some(now + GLOBAL_LOCKOUT);
        }

        self.evict_if_needed(now);

        let state = self.peers.entry(peer.to_string()).or_insert(PeerState {
            failures: 0,
            locked_until: None,
            last_seen: now,
        });
        state.failures += 1;
        state.last_seen = now;
        if state.failures >= MAX_FAILURES_PER_PEER && state.locked_until.is_none() {
            state.locked_until = Some(now + PEER_LOCKOUT);
            return true;
        }
        false
    }

    /// Catat pairing yang berhasil: bersihkan catatan peer tersebut.
    ///
    /// Hitungan global sengaja TIDAK direset. Satu keberhasilan tidak
    /// membuktikan bahwa gempuran dari peer lain sudah berhenti.
    pub fn record_success(&mut self, peer: &str) {
        self.peers.remove(peer);
    }

    /// Benar bila host sedang dalam penguncian global.
    pub fn is_globally_locked(&self, now: Instant) -> bool {
        self.global_locked_until.is_some_and(|until| now < until)
    }

    /// Buang peer terlama bila peta sudah penuh. Penyerang yang mengarang
    /// identitas baru setiap percobaan tidak boleh bisa menghabiskan memori
    /// host; batas global tetap menangkapnya.
    fn evict_if_needed(&mut self, now: Instant) {
        if self.peers.len() < MAX_TRACKED_PEERS {
            return;
        }
        // Peer yang masih terkunci tidak boleh dibuang, karena membuangnya
        // sama dengan membebaskan hukumannya lebih awal.
        let oldest = self
            .peers
            .iter()
            .filter(|(_, s)| s.locked_until.is_none_or(|until| now >= until))
            .min_by_key(|(_, s)| s.last_seen)
            .map(|(k, _)| k.clone());
        if let Some(key) = oldest {
            self.peers.remove(&key);
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
    fn mengizinkan_percobaan_pertama() {
        let now = t0();
        let mut g = PairGuard::new(now);
        assert_eq!(g.check("client-a", now), Decision::Allow);
    }

    #[test]
    fn mengunci_peer_setelah_batas_kegagalan() {
        let now = t0();
        let mut g = PairGuard::new(now);
        for _ in 0..MAX_FAILURES_PER_PEER {
            assert_eq!(g.check("penyerang", now), Decision::Allow);
            g.record_failure("penyerang", now);
        }
        match g.check("penyerang", now) {
            Decision::Denied { reason, .. } => assert_eq!(reason, DenyReason::PeerLocked),
            other => panic!("harusnya ditolak, dapat {other:?}"),
        }
    }

    #[test]
    fn peer_lain_tidak_ikut_terkunci() {
        let now = t0();
        let mut g = PairGuard::new(now);
        for _ in 0..MAX_FAILURES_PER_PEER {
            g.record_failure("penyerang", now);
        }
        assert_eq!(g.check("pengguna-sah", now), Decision::Allow);
    }

    #[test]
    fn peer_bebas_setelah_masa_hukuman() {
        let now = t0();
        let mut g = PairGuard::new(now);
        for _ in 0..MAX_FAILURES_PER_PEER {
            g.record_failure("penyerang", now);
        }
        let nanti = now + PEER_LOCKOUT + Duration::from_secs(1);
        assert_eq!(g.check("penyerang", nanti), Decision::Allow);
    }

    #[test]
    fn keberhasilan_menghapus_catatan_kegagalan() {
        let now = t0();
        let mut g = PairGuard::new(now);
        g.record_failure("pelupa", now);
        g.record_failure("pelupa", now);
        g.record_success("pelupa");
        // Setelah sukses, jatah kegagalan pulih penuh.
        for _ in 0..(MAX_FAILURES_PER_PEER - 1) {
            g.record_failure("pelupa", now);
        }
        assert_eq!(g.check("pelupa", now), Decision::Allow);
    }

    #[test]
    fn penguncian_global_menahan_serangan_terdistribusi() {
        let now = t0();
        let mut g = PairGuard::new(now);
        // Penyerang berganti identitas tiap percobaan supaya lolos batas per
        // peer. Batas global harus tetap menangkapnya.
        for i in 0..MAX_FAILURES_GLOBAL {
            let peer = format!("bayangan-{i}");
            g.record_failure(&peer, now);
        }
        assert!(g.is_globally_locked(now));
        match g.check("identitas-baru", now) {
            Decision::Denied { reason, .. } => assert_eq!(reason, DenyReason::GlobalLocked),
            other => panic!("harusnya ditolak global, dapat {other:?}"),
        }
    }

    #[test]
    fn penguncian_global_berakhir_dan_menyetel_ulang_hitungan() {
        let now = t0();
        let mut g = PairGuard::new(now);
        for i in 0..MAX_FAILURES_GLOBAL {
            g.record_failure(&format!("bayangan-{i}"), now);
        }
        let nanti = now + GLOBAL_LOCKOUT + Duration::from_secs(1);
        assert_eq!(g.check("siapa-pun", nanti), Decision::Allow);
        assert!(!g.is_globally_locked(nanti));
    }

    #[test]
    fn jendela_global_bergulir_tidak_menghukum_kesalahan_yang_jarang() {
        let now = t0();
        let mut g = PairGuard::new(now);
        // Kegagalan sesekali yang tersebar jauh melewati jendela tidak boleh
        // menumpuk sampai memicu penguncian global.
        let mut waktu = now;
        for i in 0..(MAX_FAILURES_GLOBAL * 2) {
            g.record_failure(&format!("peer-{i}"), waktu);
            waktu += GLOBAL_WINDOW + Duration::from_secs(1);
            assert!(!g.is_globally_locked(waktu), "terkunci pada iterasi {i}");
        }
    }

    #[test]
    fn peta_peer_tidak_tumbuh_tanpa_batas() {
        let now = t0();
        let mut g = PairGuard::new(now);
        for i in 0..(MAX_TRACKED_PEERS + 50) {
            g.record_failure(&format!("peer-{i}"), now + Duration::from_millis(i as u64));
        }
        assert!(g.peers.len() <= MAX_TRACKED_PEERS);
    }
}
