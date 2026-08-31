//! Build script XyDesk host: kompilasi libopus STATIS dari source yang
//! di-vendor di `vendor/opus` (lihat `vendor/opus/COPYING` — BSD-3-Clause,
//! Xiph.Org Foundation).
//!
//! Kenapa di-vendor: crate `opus` bergantung pada `audiopus_sys` yang
//! membangun libopus lawas lewat CMake — build itu gagal di runner Windows
//! modern (CMakeLists-nya memakai `cmake_minimum_required < 3.5`, ditolak
//! CMake baru). Mengompilasi source resmi (1.5.2) langsung dengan `cc`
//! menghilangkan ketergantungan itu sepenuhnya.
//!
//! Hanya dijalankan untuk target Windows — audio forward/passthrough
//! memakai WASAPI (Windows-only); platform lain tidak menaut opus.

fn main() {
    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    if target_os != "windows" {
        println!("cargo:warning=opus di-vendor hanya dikompilasi untuk Windows");
        return;
    }

    let root = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("vendor/opus");
    let include = |p: &str| root.join(p);

    let mut src: Vec<std::path::PathBuf> = Vec::new();
    for name in [
        "analysis.c",
        "mlp.c",
        "mlp_data.c",
        "opus.c",
        "opus_decoder.c",
        "opus_encoder.c",
        "repacketizer.c",
    ] {
        src.push(include(&format!("src/{name}")));
    }
    for entry in std::fs::read_dir(root.join("celt")).expect("vendor/opus/celt") {
        let p = entry.expect("entry").path();
        if p.extension().and_then(|e| e.to_str()) == Some("c") {
            src.push(p);
        }
    }
    for entry in std::fs::read_dir(root.join("silk")).expect("vendor/opus/silk") {
        let p = entry.expect("entry").path();
        if p.is_file() && p.extension().and_then(|e| e.to_str()) == Some("c") {
            src.push(p);
        }
    }
    for entry in std::fs::read_dir(root.join("silk/float")).expect("vendor/opus/silk/float") {
        let p = entry.expect("entry").path();
        if p.extension().and_then(|e| e.to_str()) == Some("c") {
            src.push(p);
        }
    }
    src.sort();

    let mut build = cc::Build::new();
    build
        .include(include(""))
        .include(include("include"))
        .include(include("src"))
        .include(include("celt"))
        .include(include("silk"))
        .include(include("silk/float"))
        .files(&src)
        .define("HAVE_CONFIG_H", None)
        .define("NDEBUG", None)
        .warnings(false)
        .opt_level(3);
    build.compile("opus");
    println!("cargo:rustc-link-lib=static=opus");
    println!("cargo:rerun-if-changed=vendor/opus");
}
