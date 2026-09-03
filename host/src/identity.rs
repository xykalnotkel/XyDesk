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
/// Dinaikkan dari 8 ke 10. Dengan charset 32 simbol, tiap karakter menyumbang
/// 5 bit, jadi ini menaikkan entropi dari 40 bit ke 50 bit — ruang pencarian
/// 1024 kali lebih besar. Biayanya cuma dua karakter tambahan yang diketik
/// sekali saat pairing.
pub const PW_GEN_LEN: usize = 10;

/// Charset password yang digenerasi: huruf besar + huruf kecil + angka.
///
/// Yang dibuang adalah pasangan yang mudah tertukar di kedua kasus — `I`/`l`/`1`,
/// `O`/`o`/`0` — karena password ini dibaca dari kejauhan lalu diketik di
/// ponsel. Dulu charset-nya hanya huruf besar; di layar password itu terlihat
/// seperti teriakan dan tetap saja `L` mirip `I` di font mono.
///
/// Huruf kecil TIDAK menambah entropi di sini: [`verify_password`] sengaja
/// tidak peka besar-kecil, jadi `a` dan `A` menempati ruang tebakan yang sama.
/// Yang bertambah hanyalah keterbacaan dan kenyamanan mengetik. Ruang tebakan
/// efektifnya 31 simbol per karakter (23 huruf + 8 angka) ≈ 4,95 bit, sehingga
/// password [`PW_GEN_LEN`] = 10 karakter ≈ 49,5 bit.
///
/// Kalau besar-kecil mau dijadikan ruang tebakan (≈59 simbol, 5,9 bit per
/// karakter), `verify_password` harus jadi peka-kasus — dan SEBELUM itu
/// terjadi, semua tempat mengetik password (APK, web, shell) wajib
/// menonaktifkan auto-kapital & koreksi otomatis, kalau tidak pengguna
/// terkunci dari PC-nya sendiri.
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
/// yang sama.
pub fn verify_password(input: &str, actual: &str) -> bool {
    let a = Sha256::digest(input.trim().to_ascii_uppercase().as_bytes());
    let b = Sha256::digest(actual.trim().to_ascii_uppercase().as_bytes());
    let mut diff = 0u8;
    for (x, y) in a.iter().zip(b.iter()) {
        diff |= x ^ y;
    }
    diff == 0
}

/// Set password kustom (persisten). Gagal bila < 6 karakter.
/// Simpan password pairing kustom.
///
/// Semua aturan password kustom hidup DI SINI — bukan di UI shell atau di
/// control API — supaya CLI `--set-password`, `POST /action` dari shell
/// desktop, dan jalur apa pun di masa depan menolak hal yang sama:
///
/// * spasi di ujung dibuang (yang tersimpan = yang ditampilkan ke pengguna);
/// * minimal [`PW_MIN_LEN`] KARAKTER (dihitung per karakter, bukan byte —
///   `password̂` bukan 12 karakter buat pengguna);
/// * tanpa karakter kontrol: Enter/Tab/ESC tidak bisa diketik dari papan ketik
///   ponsel, jadi menyimpannya berarti mengunci pemilik PC dari PC-nya sendiri.
///
/// Besar-kecil sengaja TIDAK dinormalisasi saat menyimpan: layar menampilkan
/// persis yang dipilih pengguna. Yang longgar hanya pembandingnya
/// ([`verify_password`]).
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
    fn perbandingan_tidak_peka_kasus_tapi_peka_isi() {
        let host = generate_password();
        assert!(verify_password(&host, &host));
        assert!(verify_password(&host.to_lowercase(), &host));
        assert!(verify_password(&host.to_uppercase(), &host));
        // Spasi di ujung (hasil salin-tempel) tidak menggagalkan pairing.
        assert!(verify_password(&format!("  {host} "), &host));
        assert!(!verify_password(&format!("{host}x"), &host));
        let beda = generate_password();
        if beda.to_uppercase() != host.to_uppercase() {
            assert!(!verify_password(&beda, &host));
        }
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
        assert!(verify_password("xydesk2026", &pw));
        assert!(
            set_password("abc").is_err(),
            "di bawah PW_MIN_LEN harus ditolak"
        );
        let _ = std::fs::remove_dir_all(&dir);
    }
}
