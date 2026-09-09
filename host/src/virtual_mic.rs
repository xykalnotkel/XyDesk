//! Virtual Mic Driver — biar mic client (HP → PC) kebaca sebagai input di Windows
//! seperti AnyDesk/RustDesk, dan mic host denyut di Control Panel
//!
//! ## Masalah sekarang
//! - `audio.rs::render_loop` render mic client ke **default output** (speaker) —
//!   jadi suara HP terdengar di speaker PC, tapi TIDAK muncul sebagai mic input
//!   di Windows. Discord/game/Zoom yang pakai mic tidak dengar, dan di
//!   Control Panel → Recording tidak denyut.
//! - `mic_capture_loop` capture mic PC host via eCapture — kalau VM tanpa mic
//!   device, tidak ada denyut sama sekali.
//!
//! ## Solusi driver (seperti AnyDesk)
//! Pakai virtual audio cable yang bikin pasangan:
//! - Render endpoint: "CABLE Input" / "VoiceMeeter Input" / "Virtual Mic Input"
//! - Capture endpoint: "CABLE Output" / "VoiceMeeter Output" / "Virtual Mic"
//! Kalau kita render client mic ke "CABLE Input", maka "CABLE Output" akan
//! denyut di Control Panel → Recording dan bisa dipilih sebagai mic di aplikasi.
//!
//! Driver yang didukung:
//! - VB-Audio Virtual Cable (VB-CABLE) — gratis, paling populer
//!   https://vb-audio.com/Cable/
//! - VB-Audio VoiceMeeter Banana — lebih canggih, bisa mix
//!   https://vb-audio.com/Voicemeeter/banana.htm
//! - Virtual Audio Cable (VAC) by Muzychenko — berbayar
//!   https://vac.muzychenko.net/
//! - itsmikethetech/Virtual-Audio-Driver (open source, WIP)
//!
//! ## Implementasi v6.7.2+
//! Modul ini:
//! 1. Deteksi virtual mic devices yang ada
//! 2. Pilih render target untuk client mic: prioritas virtual cable, fallback speaker
//! 3. Expose status ke control API biar UI bisa banner
//! 4. Sediakan installer script

#[cfg(target_os = "windows")]
use std::process::Command;

#[cfg(target_os = "windows")]
const VIRTUAL_MIC_KEYWORDS: &[&str] = &[
    "cable",       // VB-CABLE
    "voicemeeter", // VoiceMeeter
    "virtual",     // generic virtual
    "vb-audio",
    "vac", // Virtual Audio Cable
];

#[cfg(target_os = "windows")]
const VIRTUAL_SPEAKER_KEYWORDS: &[&str] = &[
    "cable input",       // VB-CABLE Input (render)
    "voicemeeter input", // VoiceMeeter Input
    "virtual input",
];

/// Status virtual mic
#[derive(Clone, Debug)]
pub struct VirtualMicStatus {
    pub needed: bool,
    pub installed: bool,
    pub has_virtual_input: bool,
    pub has_virtual_output: bool,
    pub render_target: String, // device yang dipakai untuk render client mic
}

#[cfg(target_os = "windows")]
pub fn get_status() -> VirtualMicStatus {
    let outputs = crate::audio::list_outputs_detailed();
    let inputs = crate::audio::list_inputs_detailed();

    let has_virtual_input = outputs.iter().any(|(_, name)| {
        let n = name.to_lowercase();
        VIRTUAL_SPEAKER_KEYWORDS.iter().any(|k| n.contains(k))
    });
    let has_virtual_output = inputs.iter().any(|(_, name)| {
        let n = name.to_lowercase();
        VIRTUAL_MIC_KEYWORDS.iter().any(|k| n.contains(k))
    });

    let installed = has_virtual_input || has_virtual_output;

    // Pilih render target: prioritas virtual cable input, fallback default
    let render_target = if let Some((id, name)) = outputs.iter().find(|(_, name)| {
        let n = name.to_lowercase();
        n.contains("cable input") || n.contains("voicemeeter input")
    }) {
        format!("{} ({})", name, id)
    } else if let Some((id, name)) = outputs.first() {
        format!("{} ({}) [default speaker]", name, id)
    } else {
        "tidak ada output device".to_string()
    };

    let needed = crate::audio::list_outputs().is_empty() || !installed;

    VirtualMicStatus {
        needed,
        installed,
        has_virtual_input,
        has_virtual_output,
        render_target,
    }
}

#[cfg(not(target_os = "windows"))]
pub fn get_status() -> VirtualMicStatus {
    VirtualMicStatus {
        needed: false,
        installed: false,
        has_virtual_input: false,
        has_virtual_output: false,
        render_target: "non-windows".to_string(),
    }
}

#[cfg(target_os = "windows")]
pub fn is_driver_installed() -> bool {
    get_status().installed
}

#[cfg(not(target_os = "windows"))]
pub fn is_driver_installed() -> bool {
    false
}

/// Coba cari device ID untuk render client mic — prioritas virtual cable
#[cfg(target_os = "windows")]
pub fn get_render_device_id() -> Option<String> {
    let outputs = crate::audio::list_outputs_detailed();

    // Prioritas 1: CABLE Input (VB-CABLE)
    for (id, name) in &outputs {
        if name.to_lowercase().contains("cable input") {
            return Some(id.clone());
        }
    }
    // Prioritas 2: VoiceMeeter Input
    for (id, name) in &outputs {
        if name.to_lowercase().contains("voicemeeter input") {
            return Some(id.clone());
        }
    }
    // Prioritas 3: Virtual Input apapun
    for (id, name) in &outputs {
        let n = name.to_lowercase();
        if n.contains("virtual") && n.contains("input") {
            return Some(id.clone());
        }
    }
    // Fallback: default output (speaker) — yang lama, tidak denyut di mic panel
    None
}

#[cfg(not(target_os = "windows"))]
pub fn get_render_device_id() -> Option<String> {
    None
}

/// Install VB-CABLE via installer yang ada di ./driver/ atau download
#[cfg(target_os = "windows")]
pub fn try_install_driver() -> Result<String, String> {
    if !crate::virtual_display::is_admin() {
        return Err("butuh admin untuk install virtual audio driver".to_string());
    }

    // Cek lokasi installer
    let candidates = [
        r"C:\Program Files\XyDesk\drivers\audio\VBCABLE_Setup_x64.exe",
        r"./drivers/audio/VBCABLE_Setup_x64.exe",
        r"../drivers/audio/VBCABLE_Setup_x64.exe",
        r"C:\Program Files\VB\CABLE\VBCABLE_Setup_x64.exe",
        r"./driver/VBCABLE_Setup_x64.exe",
        r"./driver/VBCABLE_Setup.exe",
        r"C:\VBCABLE\VBCABLE_Setup_x64.exe",
    ];

    for exe in candidates {
        if std::path::Path::new(exe).exists() {
            let output = Command::new(exe)
                .arg("-i")
                .arg("-h")
                .output()
                .map_err(|e| format!("gagal jalankan {exe}: {e}"))?;
            if output.status.success() {
                return Ok(format!(
                    "VB-CABLE terpasang dari {exe} — restart audio service"
                ));
            }
        }
    }

    Err(
        "VB-CABLE tidak ditemukan. Install manual:\n\
         1. Download https://vb-audio.com/Cable/ (VBCABLE_Driver_Pack*.zip)\n\
         2. Extract, kanan VBCABLE_Setup_x64.exe → Run as Administrator\n\
         3. Reboot, lalu di XyDesk Host → Beranda → Audio akan deteksi CABLE Input/Output\n\
         4. Di Discord/Zoom/Game, pilih mic = CABLE Output\n\
         5. Di XyDesk Android, mic HP → akan denyut di Control Panel → Recording → CABLE Output\n\
         \n\
         Alternatif: VoiceMeeter Banana (https://vb-audio.com/Voicemeeter/banana.htm) lebih canggih\n\
         Atau VAC (https://vac.muzychenko.net/) berbayar"
            .to_string(),
    )
}

#[cfg(not(target_os = "windows"))]
pub fn try_install_driver() -> Result<String, String> {
    Err("hanya Windows".to_string())
}

/// Buat virtual mic device via VB-CABLE API (kalau driver sudah ada, tidak perlu buat —
//  driver sudah bikin pasangan Input/Output otomatis)
#[cfg(target_os = "windows")]
pub fn ensure_virtual_mic() {
    let status = get_status();
    eprintln!(
        "[xydesk-host] Virtual Mic: needed={}, installed={}, virtual_input={}, virtual_output={}, render_target={}",
        status.needed, status.installed, status.has_virtual_input, status.has_virtual_output, status.render_target
    );

    if status.installed {
        println!(
            "[xydesk-host] virtual audio driver ada — client mic akan di-render ke {}",
            status.render_target
        );
        return;
    }

    if status.needed {
        eprintln!(
            "[xydesk-host] BUTUH virtual audio driver biar mic client kebaca sebagai input (denyut di Control Panel).\n\
             Saat ini render_target={} — ini speaker, bukan mic virtual, jadi tidak denyut di Recording.\n\
             Install VB-CABLE dari https://vb-audio.com/Cable/ lalu pilih mic = CABLE Output di aplikasi.",
            status.render_target
        );
    }
}

#[cfg(not(target_os = "windows"))]
pub fn ensure_virtual_mic() {}
