//! Spesifikasi mesin host — **dibaca nyata dari sistem, tidak pernah dikarang**.
//!
//! Client (`lib/webrtc/rtc_service.dart` → `HostMeta.fromJson`) sudah lama
//! menunggu blok `hardware{motherboard,cpu,gpu,ram,storage}` di pesan `meta`.
//! Modul ini yang mengisinya.
//!
//! ## Aturan kejujuran (penting — jangan dilanggar)
//!
//! 1. Setiap nilai berasal dari API/registry Windows sungguhan. Tidak ada
//!    nilai default yang "kelihatan masuk akal".
//! 2. Bila sebuah nilai gagal dibaca → kirim **`null`**. Client menampilkan
//!    "Tidak terdeteksi". Angka karangan lebih berbahaya daripada lubang:
//!    pengguna menyewa PC orang lain dan mengambil keputusan dari layar ini.
//! 3. Fungsi pemformat murni (`ram_label`, `cpu_label`, `windows_label`,
//!    `capacity_label`) terpisah dari pembacaan sistem supaya bisa diuji di
//!    Linux/CI tanpa mesin Windows.
//!
//! ## Kenapa registry, bukan WMI
//!
//! WMI (`Win32_BaseBoard`, `Win32_Processor`) butuh COM + namespace root\cimv2
//! dan bisa lambat/rusak di server sewaan (`winmgmt` dinonaktifkan). Nilai yang
//! sama tersedia di `HKLM\HARDWARE\DESCRIPTION\System` yang diisi kernel saat
//! boot — lebih cepat dan lebih jarang gagal. GPU dibaca dari kunci kelas
//! display adapter (`{4d36e968-...}`) di registry, bukan `EnumDisplayDevicesW`:
//! satu API untuk semua nilai berarti satu titik gagal, dan registry tetap
//! menyebut adapter yang terdaftar meski sedang tidak menempel ke desktop.

use serde_json::{json, Value};

/// Batas aman satu nilai registry (wchar). Nama prosesor/motherboard nyata
/// tidak pernah sepanjang ini; bila terpotong, hasilnya `null` (jujur).
const REG_BUF_WCHARS: usize = 1024;

// ── Pemformat murni (diuji di semua platform) ────────────────────────────────

/// Label RAM dari byte total, dibulatkan ke GB desimal seperti stiker pabrik
/// ("32 GB"), dengan nilai biner presisi di belakangnya ("31.9 GiB").
///
/// `0` berarti pembacaan gagal → `None`, bukan "0 GB".
pub fn ram_label(total_bytes: u64) -> Option<String> {
    if total_bytes == 0 {
        return None;
    }
    let gib = total_bytes as f64 / (1024.0 * 1024.0 * 1024.0);
    // Modul memori dijual dalam pangkat dua (8/16/32/64/128). Pembulatan ke
    // pangkat dua terdekat mengembalikan angka stiker dari angka terukur, yang
    // selalu sedikit lebih kecil karena firmware memotong sebagian RAM.
    let nominal = nearest_power_of_two(gib);
    if nominal > 0 && (gib / nominal as f64) > 0.85 {
        Some(format!("{nominal} GB ({gib:.1} GiB terukur)"))
    } else {
        Some(format!("{gib:.1} GiB"))
    }
}

/// Pangkat dua terdekat dari `v` (0 untuk v < 1).
fn nearest_power_of_two(v: f64) -> u64 {
    if v < 1.0 {
        return 0;
    }
    let exp = v.log2().round() as u32;
    1u64 << exp.min(20)
}

/// Label prosesor: nama dari registry + jumlah inti/logis dari `GetSystemInfo`.
///
/// Bagian yang tidak diketahui tidak dikarang: nama saja, jumlah saja, atau
/// `None` bila keduanya kosong.
pub fn cpu_label(name: Option<&str>, cores: u32, logical: u32) -> Option<String> {
    let name = name.map(str::trim).filter(|s| !s.is_empty());
    match (name, cores, logical) {
        (Some(n), c, l) if c > 0 && l > 0 => Some(format!("{n} — {c} inti / {l} thread")),
        (Some(n), _, _) => Some(n.to_string()),
        (None, c, l) if c > 0 && l > 0 => Some(format!("{c} inti / {l} thread")),
        _ => None,
    }
}

/// Label edisi Windows.
///
/// Registry `ProductName` di Windows 11 masih menulis "Windows 10 Pro" — itu
/// perilaku Microsoft, bukan bug kita. Build >= 22000 = Windows 11, jadi
/// namanya dikoreksi dari nomor build. Apa pun yang tidak dikenali dilaporkan
/// apa adanya, tanpa ditebak.
pub fn windows_label(product_name: Option<&str>, display_version: Option<&str>, build: u32) -> Option<String> {
    let name = product_name.map(str::trim).filter(|s| !s.is_empty())?;
    let name = if build >= 22000 {
        name.replacen("Windows 10", "Windows 11", 1)
    } else {
        name.to_string()
    };
    let ver = display_version.map(str::trim).filter(|s| !s.is_empty());
    let mut out = match ver {
        Some(v) => format!("{name} {v}"),
        None => name,
    };
    if build > 0 {
        out.push_str(&format!(" (build {build})"));
    }
    Some(out)
}

/// Label kapasitas disk ("476 GB total · 120 GB bebas").
///
/// `total == 0` berarti volume tidak bisa dibaca → `None`.
pub fn capacity_label(total_bytes: u64, free_bytes: u64) -> Option<String> {
    if total_bytes == 0 {
        return None;
    }
    let gib = |b: u64| b as f64 / (1024.0 * 1024.0 * 1024.0);
    Some(format!(
        "{:.0} GB total · {:.0} GB bebas",
        gib(total_bytes),
        gib(free_bytes)
    ))
}

/// Label satu monitor: "2560×1440 @ 144 Hz" (Hz hanya bila diketahui).
pub fn display_label(width: u32, height: u32, refresh_hz: Option<u32>) -> String {
    match refresh_hz {
        Some(hz) if hz > 0 => format!("{width}×{height} @ {hz} Hz"),
        _ => format!("{width}×{height}"),
    }
}

/// Gabungkan beberapa GPU jadi satu baris (mesin hybrid punya iGPU + dGPU dan
/// keduanya nyata — menyembunyikan salah satunya membuat diagnosis salah).
pub fn gpu_label(names: &[String]) -> Option<String> {
    let mut uniq: Vec<&String> = Vec::new();
    for n in names.iter().filter(|s| !s.trim().is_empty()) {
        if !uniq.iter().any(|x| x.trim() == n.trim()) {
            uniq.push(n);
        }
    }
    match uniq.len() {
        0 => None,
        _ => Some(uniq.iter().map(|s| s.trim()).collect::<Vec<_>>().join(" + ")),
    }
}

/// Blok `hardware` untuk pesan `meta`. Field bernilai `null` = tidak terbaca.
pub fn hardware_json() -> Value {
    let p = probe();
    json!({
        "hostname": p.hostname,
        "os": p.os,
        "motherboard": p.motherboard,
        "cpu": p.cpu,
        "gpu": p.gpu,
        "ram": p.ram,
        "storage": p.storage,
        // Sumber tiap nilai, supaya client bisa menjelaskan kenapa sebuah
        // baris kosong ("tidak terbaca dari registry") alih-alih diam.
        "source": "registry+gdi",
    })
}

/// Hasil probe mentah — semua field `Option` karena kegagalan itu normal.
#[derive(Default, Debug)]
pub struct Probe {
    pub hostname: Option<String>,
    pub os: Option<String>,
    pub motherboard: Option<String>,
    pub cpu: Option<String>,
    pub gpu: Option<String>,
    pub ram: Option<String>,
    pub storage: Option<String>,
}

/// Baca spesifikasi mesin ini.
pub fn probe() -> Probe {
    #[cfg(target_os = "windows")]
    {
        windows_probe::probe()
    }
    #[cfg(not(target_os = "windows"))]
    {
        // Host di Linux hanya dipakai untuk uji jalur RTP (pola uji). Tidak ada
        // angka yang dikarang di sini: semuanya null dan client menulis
        // "Tidak terdeteksi".
        Probe::default()
    }
}

/// Refresh rate monitor (Hz) untuk nama perangkat GDI seperti `\\.\DISPLAY1`.
/// `None` bila tidak terbaca — dipakai `screen::list_displays`.
pub fn refresh_rate_hz(device_name: &str) -> Option<u32> {
    #[cfg(target_os = "windows")]
    {
        windows_probe::refresh_rate_hz(device_name)
    }
    #[cfg(not(target_os = "windows"))]
    {
        let _ = device_name;
        None
    }
}

// ── Implementasi Windows ─────────────────────────────────────────────────────

#[cfg(target_os = "windows")]
mod windows_probe {
    use super::{
        capacity_label, cpu_label, gpu_label, ram_label, windows_label, Probe, REG_BUF_WCHARS,
    };
    use windows::core::PCWSTR;
    use windows::Win32::Graphics::Gdi::{EnumDisplaySettingsW, DEVMODEW};

    /// `ENUM_CURRENT_SETTINGS` = -1 sebagai u32. Ditulis literal supaya tidak
    /// bergantung pada nama/tipe konstanta yang pernah pindah antar versi crate.
    const MODE_CURRENT_SETTINGS: u32 = 0xFFFF_FFFF;
    use windows::Win32::Storage::FileSystem::GetDiskFreeSpaceExW;
    use windows::Win32::System::Registry::{RegGetValueW, HKEY_LOCAL_MACHINE, RRF_RT_REG_SZ};
    use windows::Win32::System::SystemInformation::{
        GetSystemInfo, GlobalMemoryStatusEx, MEMORYSTATUSEX, SYSTEM_INFO,
    };

    pub(super) fn probe() -> Probe {
        let mut p = Probe::default();

        // Nama mesin: variabel lingkungan diisi Windows saat login — cukup dan
        // tidak butuh API tambahan.
        p.hostname = std::env::var("COMPUTERNAME").ok().filter(|s| !s.is_empty());

        // ── OS: registry CurrentVersion (diisi sistem, bukan tebakan) ──
        let cv = r"SOFTWARE\Microsoft\Windows NT\CurrentVersion";
        let product = reg_string(cv, "ProductName");
        let dispver = reg_string(cv, "DisplayVersion");
        let build = reg_string(cv, "CurrentBuildNumber")
            .and_then(|s| s.trim().parse::<u32>().ok())
            .unwrap_or(0);
        p.os = windows_label(product.as_deref(), dispver.as_deref(), build);

        // ── Motherboard: BIOS menuliskan identitas papan saat boot ──
        let bios = r"HARDWARE\DESCRIPTION\System\BIOS";
        let maker = reg_string(bios, "BaseBoardManufacturer");
        let model = reg_string(bios, "BaseBoardProduct");
        p.motherboard = match (maker, model) {
            (Some(a), Some(b)) => Some(format!("{} {}", a.trim(), b.trim())),
            (Some(a), None) => Some(a),
            (None, Some(b)) => Some(b),
            // Mesin rakitan/virtual sering mengosongkan ini. Laporan jujur:
            // null → UI menulis "Tidak terdeteksi".
            (None, None) => None,
        };

        // ── CPU: nama dari registry, inti/thread dari GetSystemInfo ──
        let cpu_name = reg_string(
            r"HARDWARE\DESCRIPTION\System\CentralProcessor\0",
            "ProcessorNameString",
        );
        let mut si: SYSTEM_INFO = unsafe { std::mem::zeroed() };
        unsafe { GetSystemInfo(&mut si) };
        let logical = si.dwNumberOfProcessors;
        // Jumlah inti fisik tidak tersedia tanpa CPUID; `logical` saja lebih
        // jujur daripada menebak "cores = logical / 2".
        p.cpu = cpu_label(cpu_name.as_deref(), 0, logical);

        // ── RAM: GlobalMemoryStatusEx ──
        let mut ms = MEMORYSTATUSEX {
            dwLength: std::mem::size_of::<MEMORYSTATUSEX>() as u32,
            ..Default::default()
        };
        // Nilai balik API ini BOOL di sebagian versi crate dan Result<()> di
        // versi lain; kita tidak bergantung padanya. Isi struct yang berbicara:
        // ullTotalRam > 0 berarti pembacaan berhasil.
        unsafe {
            let _ = GlobalMemoryStatusEx(&mut ms);
        }
        p.ram = ram_label(ms.ullTotalRam);

        // ── GPU: adapter yang benar-benar men-drive desktop ──
        p.gpu = gpu_label(&gpu_names());

        // ── Penyimpanan: volume C: (bukan model disk — itu butuh IOCTL dan
        //    akan dikarang kalau ditebak) ──
        p.storage = volume_c_label();

        p
    }

    /// Refresh rate sebuah perangkat GDI (`\\.\DISPLAY1`) dalam Hz.
    pub(super) fn refresh_rate_hz(device_name: &str) -> Option<u32> {
        let wide: Vec<u16> = device_name.encode_utf16().chain(std::iter::once(0)).collect();
        let mut dm: DEVMODEW = unsafe { std::mem::zeroed() };
        dm.dmSize = std::mem::size_of::<DEVMODEW>() as u16;
        unsafe {
            let _ = EnumDisplaySettingsW(PCWSTR(wide.as_ptr()), MODE_CURRENT_SETTINGS, &mut dm);
        }
        // Sama seperti di atas: percaya pada isi struct, bukan nilai balik.
        if dm.dmPelsWidth == 0 {
            return None;
        }
        let hz = dm.dmDisplayFrequency;
        if hz == 0 || hz == 1 {
            // 1 Hz = "tidak dilaporkan" pada sebagian driver virtual.
            None
        } else {
            Some(hz)
        }
    }

    /// Kunci kelas display adapter Windows. Subkunci `0000`, `0001`, ... adalah
    /// adapter terdaftar; `DriverDesc` berisi nama yang sama dengan yang ditulis
    /// Device Manager ("NVIDIA GeForce RTX 3080").
    const VGA_CLASS_KEY: &str =
        r"SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}";

    /// Nama semua adapter grafis terdaftar.
    ///
    /// Sengaja melaporkan **semua** yang terdaftar, termasuk yang tidak sedang
    /// menempel ke desktop: di mesin hybrid (iGPU + dGPU) keduanya nyata, dan
    /// menyembunyikan salah satunya membuat diagnosis encoder salah — NVENC
    /// butuh NVIDIA, bukan Intel UHD. Duplikat disaring `gpu_label`.
    fn gpu_names() -> Vec<String> {
        let mut out: Vec<String> = Vec::new();
        // Delapan subkunci pertama sudah mencakup mesin dengan banyak GPU;
        // adapter yang tidak terbaca lebih baik tidak dilaporkan daripada
        // dikarang (aturan kejujuran #2).
        for i in 0..8u32 {
            let sub = format!("{VGA_CLASS_KEY}\\{i:04}");
            if let Some(desc) = reg_string(&sub, "DriverDesc") {
                out.push(desc);
            }
        }
        out
    }

    /// Kapasitas volume C:.
    fn volume_c_label() -> Option<String> {
        let path: Vec<u16> = "C:\\\0".encode_utf16().collect();
        let mut total: u64 = 0;
        let mut free: u64 = 0;
        unsafe {
            let _ = GetDiskFreeSpaceExW(
                PCWSTR(path.as_ptr()),
                None,
                // Koersi &mut -> *const tidak terjadi di dalam Some(...), jadi
                // ditulis eksplisit.
                Some(&mut total as *mut u64 as *const u64),
                Some(&mut free as *mut u64 as *const u64),
            );
        }
        capacity_label(total, free)
    }

    /// Baca satu nilai string (REG_SZ) dari `HKLM\<subkey>`.
    fn reg_string(subkey: &str, value: &str) -> Option<String> {
        let sub: Vec<u16> = subkey.encode_utf16().chain(std::iter::once(0)).collect();
        let val: Vec<u16> = value.encode_utf16().chain(std::iter::once(0)).collect();
        let mut buf = [0u16; REG_BUF_WCHARS];
        let mut size = (REG_BUF_WCHARS * 2) as u32;
        let code = unsafe {
            RegGetValueW(
                HKEY_LOCAL_MACHINE,
                PCWSTR(sub.as_ptr()),
                PCWSTR(val.as_ptr()),
                RRF_RT_REG_SZ,
                None,
                Some(buf.as_mut_ptr().cast()),
                Some(&mut size as *mut u32),
            )
        };
        if !code.is_ok() || size < 2 {
            return None;
        }
        let len = ((size as usize) / 2).min(REG_BUF_WCHARS);
        let s = String::from_utf16_lossy(&buf[..len])
            .trim_end_matches('\0')
            .trim()
            .to_string();
        if s.is_empty() {
            None
        } else {
            Some(s)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ram_label_mengembalikan_angka_stiker_dan_nilai_terukur() {
        // 32 GB stiker biasanya terbaca ~31.9 GiB karena potongan firmware.
        let bytes = 34_258_000_000u64;
        let label = ram_label(bytes).expect("harus ada label");
        assert!(label.starts_with("32 GB"), "label salah: {label}");
        assert!(label.contains("terukur"), "nilai presisi hilang: {label}");
    }

    #[test]
    fn ram_label_gagal_baca_berarti_null_bukan_nol() {
        // Aturan kejujuran #2: 0 byte = gagal baca → None, bukan "0 GB".
        assert_eq!(ram_label(0), None);
    }

    #[test]
    fn ram_label_bukan_pangkat_dua_tetap_dilaporkan() {
        // 12 GB (bukan pangkat dua) jangan dibulatkan jadi 16 GB.
        let bytes = 12u64 * 1024 * 1024 * 1024;
        let label = ram_label(bytes).unwrap();
        assert!(label.starts_with("12 GB"), "label salah: {label}");
    }

    #[test]
    fn cpu_label_menggabungkan_nama_dan_jumlah_thread() {
        let got = cpu_label(Some("AMD Ryzen 7 5800X"), 8, 16).unwrap();
        assert_eq!(got, "AMD Ryzen 7 5800X — 8 inti / 16 thread");
        // Nama saja (GetSystemInfo gagal) tetap berguna, tanpa angka karangan.
        assert_eq!(cpu_label(Some("Intel Core i5"), 0, 0).unwrap(), "Intel Core i5");
        // Jumlah saja (registry gagal).
        assert_eq!(cpu_label(None, 0, 4).unwrap(), "4 inti / 4 thread");
        // Keduanya gagal → null, bukan "Unknown CPU".
        assert_eq!(cpu_label(None, 0, 0), None);
        assert_eq!(cpu_label(Some("   "), 0, 0), None);
    }

    #[test]
    fn windows_label_mengoreksi_nama_win11_dari_build() {
        // Registry Windows 11 masih menulis "Windows 10 Pro" — build 22000+
        // membuktikan itu Windows 11.
        let got = windows_label(Some("Windows 10 Pro"), Some("24H2"), 26100).unwrap();
        assert_eq!(got, "Windows 11 Pro 24H2 (build 26100)");
        // Windows 10 sungguhan tidak boleh diubah namanya.
        let w10 = windows_label(Some("Windows 10 Home"), Some("22H2"), 19045).unwrap();
        assert_eq!(w10, "Windows 10 Home 22H2 (build 19045)");
        // DisplayVersion kosong → tanpa bagian itu, bukan "null".
        let nov = windows_label(Some("Windows 10 Pro"), None, 19045).unwrap();
        assert_eq!(nov, "Windows 10 Pro (build 19045)");
        // ProductName gagal → null.
        assert_eq!(windows_label(None, Some("24H2"), 26100), None);
    }

    #[test]
    fn capacity_label_dan_display_label() {
        let gib = 1024u64 * 1024 * 1024;
        assert_eq!(
            capacity_label(512 * gib, 120 * gib).unwrap(),
            "512 GB total · 120 GB bebas"
        );
        assert_eq!(capacity_label(0, 0), None);
        assert_eq!(display_label(2560, 1440, Some(144)), "2560×1440 @ 144 Hz");
        assert_eq!(display_label(1920, 1080, None), "1920×1080");
        // 0 Hz dari driver = tidak diketahui, jangan ditulis "@ 0 Hz".
        assert_eq!(display_label(1920, 1080, Some(0)), "1920×1080");
    }

    #[test]
    fn gpu_label_menyatukan_mesin_hybrid_tanpa_duplikat() {
        // Mesin hybrid: iGPU + dGPU keduanya nyata.
        assert_eq!(
            gpu_label(&[
                "Intel(R) UHD Graphics".to_string(),
                "NVIDIA GeForce RTX 3080".to_string()
            ])
            .unwrap(),
            "Intel(R) UHD Graphics + NVIDIA GeForce RTX 3080"
        );
        assert_eq!(gpu_label(&[]), None);
        assert_eq!(gpu_label(&["".to_string(), "  ".to_string()]), None);
    }

    #[test]
    fn probe_di_platform_ini_tidak_mengarang_nilai() {
        // Di Linux CI semua field harus null: bukti bahwa tidak ada nilai
        // default yang menyamar sebagai hasil pembacaan.
        #[cfg(not(target_os = "windows"))]
        {
            let p = probe();
            assert!(p.cpu.is_none() && p.ram.is_none() && p.gpu.is_none());
            assert!(p.motherboard.is_none() && p.os.is_none() && p.storage.is_none());
        }
        // Bentuk JSON-nya harus selalu punya kunci yang client harapkan.
        let v = hardware_json();
        for key in ["hostname", "os", "motherboard", "cpu", "gpu", "ram", "storage"] {
            assert!(v.get(key).is_some(), "kunci {key} hilang dari hardware");
        }
    }
}
