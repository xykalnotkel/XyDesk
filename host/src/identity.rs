//! Identitas host — ID perangkat (9 digit) + password pairing.
//!
//! - **Device ID**: 9 digit acak, unik per perangkat, disimpan permanen ke
//!   `~/.xydesk/device_id` (Windows: `%USERPROFILE%\.xydesk\device_id`).
//!   Ditampilkan berkelompok `123 456 789` agar mudah diketik di HP.
//!   Nilai kanonik (tanpa spasi) dipakai sebagai id di signaling.
//! - **Password**: acak saat pertama kali host dibuka, disimpan permanen ke
//!   `~/.xydesk/password`. Bisa diganti kapan saja (customize) lewat
//!   `--set-password` atau digenerasi ulang lewat `--new-password`.
//!
//! ID + password inilah yang diketik pengguna di aplikasi client (HP) untuk
//! pairing.

use std::fs;
use std::path::PathBuf;

use rand::Rng;
use sha2::{Digest, Sha256};

/// Panjang ID perangkat (digit).
pub const ID_LEN: usize = 9;
/// Panjang minimum password kustom yang boleh disetel pengguna.
///
/// Sengaja dibiarkan 6 agar pengguna tetap bebas memilih, tetapi password
/// sependek ini hanya aman karena ada [`crate::pairguard`] yang membatasi laju
/// percobaan. Tanpa penjaga itu, 6 karakter bisa jatuh dalam hitungan menit.
pub const PW_MIN_LEN: usize = 6;
/// Panjang password yang DIHASILKAN otomatis.
///
/// Dinaikkan dari 8 ke 10. Dengan charset [`PW_CHARS`] (54 simbol, besar-kecil
/// dihitung) tiap karakter menyumbang ≈ 5,75 bit: 8 karakter lama ≈ 46 bit,
/// 10 karakter ≈ 57,5 bit. Biayanya cuma dua karakter tambahan yang diketik
/// sekali saat pairing.
pub const PW_GEN_LEN: usize = 10;

/// Charset password yang digenerasi: huruf besar + huruf kecil + angka.
///
/// Yang dibuang adalah pasangan yang mudah tertukar di kedua kasus — `I`/`l`/`1`,
/// `O`/`o`/`0` — karena password ini dibaca dari kejauhan lalu diketik di
/// ponsel. Dulu charset-nya hanya huruf besar; di layar password itu terlihat
/// seperti teriakan dan tetap saja `L` mirip `I` di font mono.
///
/// Besar-kecil dihitung: [`verify_password`] peka-kasus untuk password campuran,
/// jadi ruang tebakannya penuh 54 simbol (23 besar + 23 kecil + 8 angka) ≈ 5,75
/// bit per karakter → [`PW_GEN_LEN`] = 10 karakter ≈ 57,5 bit. Bandingkan
/// dengan keadaan lama (hanya huruf besar, 31 simbol ≈ 4,95 bit, ~49,5 bit).
///
/// Password yang diketik pengguna TIDAK dibatasi ke charset ini — `set_password`
/// menerima apa saja (min. [`PW_MIN_LEN`] karakter, tanpa karakter kontrol).
/// Aturan charset ini hanya untuk yang kita generasi.
///
/// Kalau pengguna memilih password yang tidak punya huruf kecil sama sekali,
/// host memperlakukannya sebagai password lama: besar-kecil tidak dihitung
/// (lihat [`verify_password`]). Itu disengaja supaya HP/APK lama tidak terkunci
/// — dan itu berarti password semacam itu hanya punya ~4,95 bit per karakter.
const PW_CHARS: &[u8] = b"ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";

/// Muat ID perangkat yang sudah ada, atau buat + simpan yang baru.
/// Mengembalikan 9 digit (tanpa spasi).
pub fn load_or_create_device_id() -> String {
    let path = config_dir().join("device_id");
    if let Ok(raw) = fs::read_to_string(&path) {
        let id: String = raw.chars().filter(|c| c.is_ascii_digit()).collect();
        if id.len() == ID_LEN {
            return id;
        }
    }
    let id = generate_id();
    let _ = fs::create_dir_all(config_dir());
    let _ = fs::write(&path, &id);
    id
}

/// Generate ID perangkat 9 digit acak.
pub fn generate_id() -> String {
    let mut rng = rand::thread_rng();
    let mut s = String::with_capacity(ID_LEN);
    for _ in 0..ID_LEN {
        s.push(char::from(b'0' + rng.gen_range(0..10)));
    }
    s
}

/// Format "123456789" → "123 456 789" (untuk ditampilkan).
pub fn format_id(id: &str) -> String {
    let digits: String = id.chars().filter(|c| c.is_ascii_digit()).collect();
    digits
        .as_bytes()
        .chunks(3)
        .map(|c| std::str::from_utf8(c).unwrap_or("").to_string())
        .collect::<Vec<_>>()
        .join(" ")
}

/// Muat password yang sudah ada, atau buat + simpan yang baru.
pub fn load_or_create_password() -> String {
    let path = config_dir().join("password");
    if let Ok(raw) = fs::read_to_string(&path) {
        let pw = raw.trim().to_string();
        if pw.len() >= PW_MIN_LEN {
            return pw;
        }
    }
    let pw = generate_password();
    let _ = fs::create_dir_all(config_dir());
    let _ = fs::write(&path, &pw);
    pw
}

/// Generate password acak ([`PW_GEN_LEN`] karakter, tanpa karakter
/// membingungkan).
pub fn generate_password() -> String {
    let mut rng = rand::thread_rng();
    (0..PW_GEN_LEN)
        .map(|_| PW_CHARS[rng.gen_range(0..PW_CHARS.len())] as char)
        .collect()
}

/// Bandingkan password yang dikirim client dengan password host.
///
/// ## Kenapa tidak memakai `==` atau `eq_ignore_ascii_case`
///
/// Kedua operator itu short-circuit: mereka berhenti pada byte pertama yang
/// berbeda. Selisih waktu antara "salah di karakter pertama" dan "salah di
/// karakter terakhir" dapat diukur, dan penyerang yang sabar bisa memulihkan
/// password karakter demi karakter. Itu mengubah serangan 32^8 menjadi 32*8.
///
/// Fungsi ini membandingkan hash SHA-256 dari kedua nilai, bukan teks aslinya.
/// Dua keuntungan: panjang yang dibandingkan selalu 32 byte (panjang password
/// asli tidak bocor), dan akumulasi XOR memastikan seluruh byte selalu dibaca.
///
/// Perbandingan TIDAK peka besar-kecil, dan itu pilihan, bukan kelalaian:
/// password dibaca dari layar PC lalu diketik di papan ketik ponsel, dan
/// papan ketik ponsel sering-modal mengkapital huruf pertama. Efek sampingnya
/// harus disadari: `abcd` dan `ABCD` adalah password yang sama, jadi generator
/// di [`PW_CHARS`] tidak mengambil manfaat entropi dari huruf kecil (lihat
/// komentar di sana untuk syarat kalau mau dibalik jadi peka-kasus).
///
/// Password kustom disimpan apa adanya, jadi yang tampil di layar host persis
/// yang diketik pengguna; yang longgar hanya pembandingnya. Konsekuensinya
/// perlu diketahui: memilih `Rahasia123` dan `rahasia123` menghasilkan efek
/// Bandingkan password yang diketik client dengan password host.
///
/// PEKA-KASUS sejak 3 Sep 2026: `aV7k…` dan `AV7k…` adalah dua password yang
/// berbeda. Konsekuensi yang harus diterima: semua tempat mengetik password
/// (APK, web, shell desktop) WAJIB menonaktifkan auto-kapital & koreksi
/// otomatis — kalau tidak, huruf pertama yang dikapital otomatis membuat
/// pairing gagal. Sudah dilakukan di `lib/features/connect/connect_page.dart`,
/// `web/src/App.tsx`, dan halaman Hubungkan shell desktop.
///
/// Untuk password yang tersimpan seluruhnya huruf besar tanpa satu pun huruf
/// kecil ([`is_legacy_shape`] — warisan generator lama atau pilihan pengguna),
/// perbandingan tetap tidak peka-kasus. Sengaja, supaya HP/APK lama yang
/// mengkapital huruf pertama (atau yang lama: memaksa semua huruf besar) tidak
/// terkunci oleh host yang baru diperbarui. Efek sampingnya harus disadari:
/// password semacam itu hanya punya ~4,95 bit per karakter dan diterima juga
/// dalam bentuk huruf kecil. Pilih password campuran untuk manfaat penuh.
///
/// Spasi di ujung dibuang di kedua sisi (hasil salin-tempel), perbandingan
/// memakai hash SHA-256 + akumulasi XOR supaya konstan-waktu terhadap
/// panjangnya.
pub fn verify_password(input: &str, actual: &str) -> bool {
    let given = input.trim();
    let stored = actual.trim();
    if equal_digests(given.as_bytes(), stored.as_bytes()) {
        return true;
    }
    // Jaring kompatibilitas, satu arah.
    //
    // Password LAMA (generator lama hanya huruf besar) dan password kustom yang
    // seluruhnya huruf besar tetap diterima tanpa peduli besar-kecil. Itu
    // penting karena papan ketik ponsel suka mengkapital huruf pertama dan
    // client lama bahkan ada yang memaksa semua huruf jadi besar: tanpa jaring
    // ini, memperbarui host saja bisa mengunci pemilik PC dari PC-nya sendiri.
    //
    // Password CAMPURAN (hasil generator baru) TIDAK pernah dilonggarkan —
    // begitu ada satu huruf kecil di nilai yang tersimpan, besar-kecil dihitung.
    if is_legacy_shape(stored) {
        return equal_digests(
            given.to_ascii_uppercase().as_bytes(),
            stored.to_ascii_uppercase().as_bytes(),
        );
    }
    false
}

/// `SHA-256(a) == SHA-256(b)` dengan perbandingan konstan-waktu.
///
/// Hash dipakai supaya panjang input tidak terbaca dari waktu eksekusi; XOR
/// accumulate dipakai supaya hasil != tidak keluar lebih awal di byte pertama.
fn equal_digests(a: &[u8], b: &[u8]) -> bool {
    let x = Sha256::digest(a);
    let y = Sha256::digest(b);
    let mut diff = 0u8;
    for (p, q) in x.iter().zip(y.iter()) {
        diff |= p ^ q;
    }
    diff == 0
}

/// Bentuk password "lama": tidak ada satu pun huruf kecil. Host memakai ini
/// untuk memutuskan apakah verifikasinya dilonggarkan jadi tidak peka-kasus
/// (lihat [`verify_password`]).
pub fn is_legacy_shape(pw: &str) -> bool {
    let pw = pw.trim();
    !pw.is_empty() && pw.chars().all(|c| !c.is_ascii_lowercase())
}

/// Simpan password pairing kustom (persisten).
///
/// Semua aturan password kustom hidup DI SINI — bukan di UI shell atau di
/// control API — supaya CLI `--set-password`, `POST /action` dari shell
/// desktop, dan jalur apa pun di masa depan menolak hal yang sama:
///
/// * spasi di ujung dibuang (yang tersimpan = yang ditampilkan ke pengguna);
/// * minimal [`PW_MIN_LEN`] KARAKTER — dihitung per karakter, bukan per byte,
///   jadi password beraksen tidak dihitung dua kali;
/// * tanpa karakter kontrol: Enter/Tab/ESC tidak bisa diketik dari papan ketik
///   ponsel, jadi menyimpannya berarti mengunci pemilik PC dari PC-nya sendiri.
///
/// Besar-kecil TIDAK dinormalisasi saat menyimpan: layar menampilkan persis yang
/// dipilih pengguna, dan [`verify_password`] membandingkannya apa adanya
/// (kecuali untuk password yang seluruhnya huruf besar — lihat di sana).
pub fn set_password(pw: &str) -> std::io::Result<()> {
    let pw = pw.trim();
    if pw.chars().count() < PW_MIN_LEN {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            format!("password minimal {PW_MIN_LEN} karakter"),
        ));
    }
    if pw.chars().any(|c| c.is_control()) {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            "password tidak boleh berisi karakter kontrol (Enter/Tab/ESC)",
        ));
    }
    fs::create_dir_all(config_dir())?;
    fs::write(config_dir().join("password"), pw)
}

/// Direktori konfigurasi host (lintas platform, tanpa crate tambahan).
///
/// Bisa diarahkan ulang lewat env `XYDESK_HOME` — dipakai test otomatis dan
/// mode portable (installer tanpa instalasi: identitas ikut folder aplikasi).
fn config_dir() -> PathBuf {
    if let Ok(dir) = std::env::var("XYDESK_HOME") {
        let dir = dir.trim();
        if !dir.is_empty() {
            return PathBuf::from(dir);
        }
    }
    let base = std::env::var("USERPROFILE")
        .or_else(|_| std::env::var("HOME"))
        .unwrap_or_else(|_| ".".to_string());
    PathBuf::from(base).join(".xydesk")
}

/// Gembok untuk tes yang mengubah env `XYDESK_HOME`.
///
/// Env var itu milik BERSAMA satu proses, sementara `cargo test` menjalankan
/// tes di banyak thread: tanpa gembok, tes yang menulis password ke direktori
/// sementara masing-masing bisa membaca nilai yang baru dipindah tes lain —
/// gagal-tidak-gagalnya bergantung urutan jadwal thread (terlihat sekali: 1
/// gagal dari 87 tanpa perubahan kode). Sengaja memakai flag + RAII, bukan
/// `Mutex`: guard-nya harus `Send` supaya boleh dipegang melintasi `await` di
/// tes async (`control::tests`), dan gembok `std` yang beracun tidak boleh
/// membuat semua tes sesudahnya ikut gagal.
#[cfg(test)]
pub(crate) static HOME_ENV_BUSY: std::sync::atomic::AtomicBool =
    std::sync::atomic::AtomicBool::new(false);

#[cfg(test)]
pub(crate) struct HomeEnvGuard;

#[cfg(test)]
impl Drop for HomeEnvGuard {
    fn drop(&mut self) {
        HOME_ENV_BUSY.store(false, std::sync::atomic::Ordering::SeqCst);
    }
}

/// Versi sinkron: dipakai tes `#[test]`. Menunggu dengan `yield_now` (bukan
/// `sleep`) karena pemegang gembok tidak pernah tertidur lama.
#[cfg(test)]
pub(crate) fn lock_home_env() -> HomeEnvGuard {
    loop {
        if !HOME_ENV_BUSY.swap(true, std::sync::atomic::Ordering::SeqCst) {
            return HomeEnvGuard;
        }
        std::thread::yield_now();
    }
}

/// Versi async: dipakai tes `#[tokio::test]` yang harus memegang gembok sambil
/// menunggu I/O — ber-`await` di sini membiarkan worker tokio melayani tes lain.
#[cfg(test)]
pub(crate) async fn lock_home_env_async() -> HomeEnvGuard {
    loop {
        if !HOME_ENV_BUSY.swap(true, std::sync::atomic::Ordering::SeqCst) {
            return HomeEnvGuard;
        }
        tokio::task::yield_now().await;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn charset_tanpa_karakter_yang_mudah_tertukar() {
        // I, O, 0, 1 (dan l, yang dikasari 'I' di banyak font mono). Aturan ini
        // berlaku untuk KEDUA kasus huruf — menambah huruf kecil saja tanpa
        // ikut menyaring akan mengembalikan karakter yang dibuang.
        for c in ['I', 'O', 'L', 'i', 'o', 'l', '1', '0'] {
            assert!(
                !PW_CHARS.contains(&(c as u8)),
                "karakter {c:?} mudah tertukar, tidak boleh ada di charset"
            );
        }
    }

    #[test]
    fn charset_mengandung_huruf_kecil_dan_besar() {
        // Permintaan yang ditutup: password tidak lagi sekadar huruf besar.
        assert!(PW_CHARS.iter().any(|c| c.is_ascii_lowercase()));
        assert!(PW_CHARS.iter().any(|c| c.is_ascii_uppercase()));
        // 23 huruf besar + 23 huruf kecil + 8 angka = 54; setelah penyamaran
        // besar-kecil yang tersisa 31 ruang tebakan per karakter (≈4,95 bit).
        assert_eq!(PW_CHARS.len(), 54);
        let folded: std::collections::BTreeSet<u8> =
            PW_CHARS.iter().map(|c| c.to_ascii_uppercase()).collect();
        assert_eq!(folded.len(), 31);
    }

    #[test]
    fn password_generasi_panjang_dan_hanya_dari_charset() {
        for _ in 0..200 {
            let pw = generate_password();
            assert_eq!(pw.chars().count(), PW_GEN_LEN);
            assert!(
                pw.chars().all(|c| PW_CHARS.contains(&(c as u8))),
                "di luar charset: {pw}"
            );
        }
    }

    #[test]
    fn perbandingan_peka_kasus_untuk_password_campuran() {
        // Yang berubah sejak 3 Sep 2026: besar-kecil ikut menghitung.
        let pw = "aV7kQm2d9x";
        assert!(verify_password(pw, pw));
        assert!(
            !verify_password(&pw.to_uppercase(), pw),
            "password campuran tidak boleh diterima dalam bentuk lain"
        );
        assert!(!verify_password("AV7kQm2d9x", pw));
        assert!(!verify_password("av7kQm2d9x", pw));
        // Spasi ujung (salin-tempel) tetap dimaafkan.
        assert!(verify_password(&format!("  {pw}\n"), pw));
        assert!(!verify_password(&format!("{pw}x"), pw));
    }

    #[test]
    fn password_lama_huruf_besar_tetap_diterima_tanpa_peduli_kasus() {
        // Jaring kompatibilitas satu arah: inilah yang membuat host baru tidak
        // mengunci APK lama yang mengkapital huruf pertama.
        let lama = "AB2CDE7FGH";
        assert!(is_legacy_shape(lama));
        assert!(verify_password(lama, lama));
        assert!(verify_password(&lama.to_lowercase(), lama));
        // Termasuk password kustom tanpa huruf kecil — konsekuensi yang dipilih
        // sadar, bukan kejutan: jangan pakai password begini kalau mau penuh.
        assert!(is_legacy_shape("RAHASIA123"));
        assert!(verify_password("rahasia123", "RAHASIA123"));
        // Begitu ada satu huruf kecil, jaringnya lepas.
        assert!(!is_legacy_shape("Rahasia123"));
        assert!(!verify_password("RAHASIA123", "Rahasia123"));
    }

    #[test]
    fn password_hasil_generasi_selalu_bisa_diterima_dan_campur_kasus() {
        // Sanitasi menyeluruh: yang kita generasi harus lolos verifikasinya
        // sendiri, dan karena charset kini campuran, tidak boleh ada yang
        // jatuh ke bentuk "legacy" (semua huruf besar) terus-menerus.
        let mut ada_kecil = 0;
        let mut ada_besar = 0;
        for _ in 0..500 {
            let pw = generate_password();
            assert!(
                verify_password(&pw, &pw),
                "tidak cocok dengan dirinya sendiri: {pw}"
            );
            assert_eq!(pw.chars().count(), PW_GEN_LEN);
            ada_kecil += usize::from(pw.chars().any(|c| c.is_ascii_lowercase()));
            ada_besar += usize::from(pw.chars().any(|c| c.is_ascii_uppercase()));
        }
        // Peluang satu password 10 karakter tanpa huruf kecil = (31/54)^10 ≈ 0,4%.
        assert!(
            ada_kecil > 480 && ada_besar > 480,
            "{ada_kecil}/{ada_besar} dari 500"
        );
    }

    #[test]
    fn password_kustom_menolak_karakter_kontrol_dan_spasi_jauh() {
        let _guard = lock_home_env();
        let dir = std::env::temp_dir().join(format!("xydesk-pw-ctl-{}", std::process::id()));
        std::env::set_var("XYDESK_HOME", &dir);
        let _ = std::fs::create_dir_all(&dir);
        // Enter di tengah password = tidak bisa diketik dari HP: ditolak.
        assert!(set_password("rahasia\n123").is_err());
        assert!(set_password("\tkode").is_err());
        // Spasi di ujung dibuang, spasi di tengah boleh.
        assert!(set_password("  Kopi Pagi 2026  ").is_ok());
        assert_eq!(load_or_create_password(), "Kopi Pagi 2026");
        // 6 KARAKTER, bukan 6 byte.
        assert!(set_password("ééé").is_err());
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn password_kustom_disimpan_apa_adanya() {
        let _guard = lock_home_env();
        let dir = std::env::temp_dir().join(format!("xydesk-pw-{}", std::process::id()));
        std::env::set_var("XYDESK_HOME", &dir);
        let _ = std::fs::create_dir_all(&dir);
        // Campuran besar-kecil harus bisa disimpan (yang dulu ditolak layar
        // karena generator hanya huruf besar).
        assert!(set_password("XyDesk2026").is_ok());
        let pw = load_or_create_password();
        assert_eq!(pw, "XyDesk2026");
        // Campuran besar/kecil = peka-kasus: bentuk lain harus DITOLAK.
        assert!(verify_password("XyDesk2026", &pw));
        assert!(!verify_password("xydesk2026", &pw));
        assert!(!verify_password("XYDESK2026", &pw));
        assert!(
            set_password("abc").is_err(),
            "di bawah PW_MIN_LEN harus ditolak"
        );
        let _ = std::fs::remove_dir_all(&dir);
    }
}
