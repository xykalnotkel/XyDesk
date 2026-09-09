//! Pemeriksa + pemasang pembaruan shell desktop.
//!
//! Membaca manifest resmi yang SAMA dengan klien Android
//! (`releases/latest/download/update.json`, skema 2) — hanya kunci `windows`
//! yang dipakai. Aturan keamanannya meniru
//! `lib/features/notifications/update_repository.dart`: host resmi, path
//! persis, tanpa query/fragment, lalu verifikasi ukuran + SHA-256 sebelum
//! installer dijalankan. Tanpa kunci `windows` di manifest = "tidak ada
//! update" (bukan error): rilis lama memang tidak menerbitkannya.

use serde::{Deserialize, Serialize};

const MANIFEST_URL: &str =
    "https://github.com/xykalnotkel/XyDesk/releases/latest/download/update.json";
const OFFICIAL_HOST: &str = "github.com";
const REPOSITORY: &str = "xykalnotkel/XyDesk";

#[derive(Debug, Deserialize)]
struct ManifestAsset {
    url: String,
    sha256: String,
    bytes: u64,
}

#[derive(Debug, Deserialize)]
struct ManifestWindows {
    x64: Option<ManifestAsset>,
    arm64: Option<ManifestAsset>,
}

#[derive(Debug, Deserialize)]
struct Manifest {
    schema: i32,
    version: String,
    build: i64,
    tag: String,
    notes: Option<Vec<String>>,
    windows: Option<ManifestWindows>,
}

/// Status pembaruan untuk frontend (camelCase, lihat `global.d.ts`).
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateStatus {
    pub current_version: String,
    pub latest_version: String,
    pub latest_build: i64,
    pub update_available: bool,
    pub notes: Vec<String>,
    pub asset_name: Option<String>,
    pub asset_bytes: Option<u64>,
}

/// Versi shell yang sedang berjalan — satu sumber kebenaran (Cargo.toml).
pub fn current_version() -> &'static str {
    env!("CARGO_PKG_VERSION")
}

/// Kunci aset installer untuk arsitektur proses ini.
fn asset_key() -> Option<&'static str> {
    match std::env::consts::ARCH {
        "x86_64" => Some("x64"),
        "aarch64" => Some("arm64"),
        _ => None,
    }
}

fn asset_file_name(key: &str) -> String {
    format!("XyDesk-{key}.exe")
}

/// `true` bila [latest] semver-nya lebih baru dari [current].
/// Keduanya wajib `N.N.N` numerik — kalau tidak, ini Err, bukan `false`
/// yang diam: versi yang tidak bisa dibandingkan tidak boleh disimpulkan.
pub fn is_newer(latest: &str, current: &str) -> Result<bool, String> {
    fn triplet(v: &str) -> Result<[u32; 3], String> {
        let parts: Vec<&str> = v.split('.').collect();
        if parts.len() != 3 {
            return Err(format!("versi tidak valid: {v}"));
        }
        let mut out = [0u32; 3];
        for (i, p) in parts.iter().enumerate() {
            out[i] = p
                .parse::<u32>()
                .map_err(|_| format!("versi tidak valid: {v}"))?;
        }
        Ok(out)
    }
    Ok(triplet(latest)? > triplet(current)?)
}

/// Pilih dan validasi aset installer untuk arsitektur ini.
/// URL wajib persis milik rilis resmi — bukan sekadar "host-nya benar".
fn pick_asset<'a>(m: &'a Manifest) -> Result<(&'a ManifestAsset, String), String> {
    let key = asset_key().ok_or_else(|| {
        format!(
            "arsitektur {} tidak punya installer resmi",
            std::env::consts::ARCH
        )
    })?;
    let w = m
        .windows
        .as_ref()
        .ok_or_else(|| "rilis ini tidak menerbitkan installer Windows".to_string())?;
    let asset = match key {
        "x64" => w.x64.as_ref(),
        _ => w.arm64.as_ref(),
    }
    .ok_or_else(|| format!("installer {key} tidak tersedia di rilis ini"))?;

    let name = asset_file_name(key);
    let expected_path = format!("/{REPOSITORY}/releases/download/{}/{}", m.tag, name);
    let parsed =
        url::Url::parse(&asset.url).map_err(|_| "URL installer tidak valid".to_string())?;
    if parsed.scheme() != "https"
        || parsed.host_str() != Some(OFFICIAL_HOST)
        || parsed.path() != expected_path
        || parsed.query().is_some()
        || parsed.fragment().is_some()
    {
        return Err("URL installer bukan dari rilis resmi XyDesk".to_string());
    }
    if asset.sha256.len() != 64 || !asset.sha256.bytes().all(|b| b.is_ascii_hexdigit()) {
        return Err("checksum installer tidak valid".to_string());
    }
    if asset.bytes == 0 {
        return Err("ukuran installer tidak valid".to_string());
    }
    Ok((asset, name))
}

fn hex(bytes: &[u8]) -> String {
    const T: &[u8; 16] = b"0123456789abcdef";
    let mut s = String::with_capacity(bytes.len() * 2);
    for b in bytes {
        s.push(T[(b >> 4) as usize] as char);
        s.push(T[(b & 0x0f) as usize] as char);
    }
    s
}

fn validate_manifest(m: &Manifest) -> Result<(), String> {
    if m.schema != 2 {
        return Err("format metadata update belum didukung".to_string());
    }
    // Versi wajib N.N.N numerik — `is_newer` yang menilai, di sini cukup
    // memastikan bentuknya sebelum dipakai membangun path ekspektasi.
    if m.version.split('.').count() != 3
        || !m
            .version
            .split('.')
            .all(|p| !p.is_empty() && p.bytes().all(|b| b.is_ascii_digit()))
    {
        return Err("versi update resmi tidak valid".to_string());
    }
    if m.tag != format!("v{}", m.version) {
        return Err("tag dan versi update tidak cocok".to_string());
    }
    if m.build <= 0 {
        return Err("nomor build update resmi tidak valid".to_string());
    }
    Ok(())
}

async fn fetch_manifest() -> Result<Manifest, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(20))
        .build()
        .map_err(|e| format!("gagal menyiapkan HTTP: {e}"))?;
    let res = client
        .get(MANIFEST_URL)
        .send()
        .await
        .map_err(|e| format!("tidak dapat menghubungi server update: {e}"))?;
    if !res.status().is_success() {
        return Err(format!("server update menjawab {}", res.status()));
    }
    let m: Manifest = res
        .json()
        .await
        .map_err(|_| "metadata update rusak".to_string())?;
    validate_manifest(&m)?;
    Ok(m)
}

/// Periksa pembaruan: bandingkan versi berjalan dengan manifest resmi.
pub async fn check_update() -> Result<UpdateStatus, String> {
    let current = current_version().to_string();
    let m = fetch_manifest().await?;
    let newer = is_newer(&m.version, &current)?;
    // Rilis tanpa kunci `windows` (rilis lama) = tidak ada update untuk
    // desktop, bukan kegagalan.
    let picked = if newer { pick_asset(&m).ok() } else { None };
    let (asset_name, asset_bytes) = match &picked {
        Some((a, name)) => (Some(name.clone()), Some(a.bytes)),
        None => (None, None),
    };
    Ok(UpdateStatus {
        current_version: current,
        latest_version: m.version,
        latest_build: m.build,
        update_available: newer && picked.is_some(),
        notes: m.notes.unwrap_or_default(),
        asset_name,
        asset_bytes,
    })
}

/// Unduh installer rilis terbaru ke direktori temp, verifikasi ukuran +
/// SHA-256, kembalikan path-nya. Manifest diambil ulang di sini (bukan
/// dari frontend) supaya URL yang dijalankan tidak bisa disusupi.
pub async fn download_update() -> Result<String, String> {
    let m = fetch_manifest().await?;
    if !is_newer(&m.version, current_version())? {
        return Err("sudah memakai versi terbaru".to_string());
    }
    let (asset, name) = pick_asset(&m)?;
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(300))
        .build()
        .map_err(|e| format!("gagal menyiapkan HTTP: {e}"))?;
    let bytes = client
        .get(&asset.url)
        .send()
        .await
        .map_err(|e| format!("unduhan gagal: {e}"))?
        .bytes()
        .await
        .map_err(|e| format!("unduhan gagal: {e}"))?;
    if bytes.len() as u64 != asset.bytes {
        return Err("ukuran berkas tidak cocok dengan manifest".to_string());
    }
    use sha2::Digest as _;
    let mut h = sha2::Sha256::new();
    h.update(&bytes);
    if hex(&h.finalize()) != asset.sha256.to_lowercase() {
        return Err("checksum berkas tidak cocok — unduhan dibuang".to_string());
    }
    let path = std::env::temp_dir().join(format!("xydesk-update-{name}"));
    std::fs::write(&path, &bytes).map_err(|e| format!("gagal menyimpan berkas: {e}"))?;
    path.to_str()
        .map(|s| s.to_string())
        .ok_or_else(|| "path temp tidak valid".to_string())
}

/// Jalankan installer lalu KELUAR: janji fungsi ini tidak pernah resolve.
/// Installer membutuhkan admin (UAC) dan menutup aplikasi yang sedang
/// berjalan — itulah kenapa proses ini mengakhiri dirinya sendiri setelah
/// installer lahir, bukan menunggu.
pub fn install_update(path: String) -> Result<(), String> {
    let p = std::path::Path::new(&path);
    let file = p
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or_default();
    if !file.starts_with("xydesk-update-XyDesk-") || !file.ends_with(".exe") {
        return Err("berkas bukan hasil unduhan updater".to_string());
    }
    if p.parent() != Some(std::env::temp_dir().as_path()) || !p.exists() {
        return Err("berkas update tidak ditemukan".to_string());
    }
    std::process::Command::new(p)
        .arg("/SILENT")
        .spawn()
        .map_err(|e| format!("gagal membuka installer: {e}"))?;
    std::process::exit(0);
}

#[cfg(test)]
mod tests {
    use super::*;

    fn manifest(tag: &str, url: &str) -> Manifest {
        Manifest {
            schema: 2,
            version: tag.trim_start_matches('v').to_string(),
            build: 48,
            tag: tag.to_string(),
            notes: Some(vec!["catatan".to_string()]),
            windows: Some(ManifestWindows {
                x64: Some(ManifestAsset {
                    url: url.to_string(),
                    sha256: "a".repeat(64),
                    bytes: 8_000_000,
                }),
                arm64: None,
            }),
        }
    }

    #[test]
    fn versi_baru_terdeteksi() {
        assert_eq!(is_newer("6.7.13", "6.7.12"), Ok(true));
        assert_eq!(is_newer("6.8.0", "6.7.12"), Ok(true));
        assert_eq!(is_newer("6.7.12", "6.7.12"), Ok(false));
        assert_eq!(is_newer("6.7.11", "6.7.12"), Ok(false));
        // Perbandingan numerik, bukan leksikografis: 6.7.9 < 6.7.12.
        assert_eq!(is_newer("6.7.9", "6.7.12"), Ok(false));
    }

    #[test]
    fn versi_rusak_ditolak_bukan_disimpulkan() {
        assert!(is_newer("6.7", "6.7.12").is_err());
        assert!(is_newer("enam", "6.7.12").is_err());
        assert!(is_newer("6.7.13", "6.7").is_err());
    }

    #[test]
    fn url_resmi_lolos_semua_validasi() {
        let m = manifest(
            "v6.7.13",
            "https://github.com/xykalnotkel/XyDesk/releases/download/v6.7.13/XyDesk-x64.exe",
        );
        assert!(validate_manifest(&m).is_ok());
        // Test ini jalan di x64 dan arm64; di arm64 asetnya None → Err yang
        // jujur ("tidak tersedia"), bukan lolos palsu.
        match std::env::consts::ARCH {
            "x86_64" => {
                let (a, name) = pick_asset(&m).expect("aset x64 harus lolos");
                assert_eq!(name, "XyDesk-x64.exe");
                assert_eq!(a.bytes, 8_000_000);
            }
            _ => assert!(pick_asset(&m).is_err()),
        }
    }

    #[test]
    fn url_palsu_ditolak() {
        for bad in [
            // Host salah.
            "https://evil.com/xykalnotkel/XyDesk/releases/download/v6.7.13/XyDesk-x64.exe",
            // Skema bukan https.
            "http://github.com/xykalnotkel/XyDesk/releases/download/v6.7.13/XyDesk-x64.exe",
            // Tag di path tidak cocok dengan tag manifest.
            "https://github.com/xykalnotkel/XyDesk/releases/download/v6.7.12/XyDesk-x64.exe",
            // Nama berkas berbeda.
            "https://github.com/xykalnotkel/XyDesk/releases/download/v6.7.13/setup.exe",
            // Query string = URL berbeda.
            "https://github.com/xykalnotkel/XyDesk/releases/download/v6.7.13/XyDesk-x64.exe?x=1",
        ] {
            let m = manifest("v6.7.13", bad);
            assert!(pick_asset(&m).is_err(), "seharusnya ditolak: {bad}");
        }
    }

    #[test]
    fn manifest_rusak_ditolak() {
        let mut m = manifest(
            "v6.7.13",
            "https://github.com/xykalnotkel/XyDesk/releases/download/v6.7.13/XyDesk-x64.exe",
        );
        m.tag = "v9.9.9".to_string();
        assert!(validate_manifest(&m).is_err());
        m.tag = "v6.7.13".to_string();
        m.schema = 1;
        assert!(validate_manifest(&m).is_err());
    }

    #[test]
    fn install_menolak_path_asing() {
        assert!(install_update("C:\\Windows\\System32\\x.exe".to_string()).is_err());
        assert!(install_update("/tmp/xydesk-update-XyDesk-x64.exe".to_string()).is_err());
    }
}
