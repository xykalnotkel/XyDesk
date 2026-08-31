#!/usr/bin/env bash
# Cross-check kode host Windows dari Linux/macOS — tanpa runner Windows.
#
# ## Kenapa skrip ini ada
#
# Seluruh jalur WASAPI, DXGI, dan GDI hidup di balik `cfg(target_os =
# "windows")`. `cargo check` biasa di Linux TIDAK menyentuh satu baris pun dari
# kode itu — dia hanya mengompilasi stub non-Windows. Akibatnya salah ketik dan
# salah tanda tangan API windows-rs baru ketahuan di GitHub Actions, dengan
# umpan balik ~8 menit per percobaan. Riwayat repo ini punya buktinya: tujuh
# commit `fix(host)` beruntun dalam satu jam pada 31 Agu 2026, semuanya error
# kompilasi sepele (kurung let-else, atribut salah tempat, file .c kurang).
#
# Skrip ini memindahkan umpan balik itu ke mesin lokal, hitungan detik.
#
# ## Kenapa target GNU, bukan MSVC
#
# `x86_64-pc-windows-msvc` butuh header Windows SDK + CRT Microsoft (lewat
# cargo-xwin, ~1 GB unduhan dan lisensinya perlu diterima). `-gnu` cuma butuh
# mingw-w64 dari repo distro. Untuk MEMERIKSA kode, keduanya setara: parser,
# type checker, dan seluruh binding windows-rs sama persis. Yang berbeda hanya
# ABI dan linker — dan itu tetap diverifikasi oleh runner Windows asli di CI.
#
# Aturan mainnya: skrip ini menangkap error kompilasi sebelum push. Yang
# TIDAK bisa ia buktikan: linking MSVC, perilaku runtime, dan apakah audionya
# benar-benar terdengar. Itu tetap tugas lab Windows.
#
# ## Prasyarat (sekali saja)
#
#   rustup target add x86_64-pc-windows-gnu
#   sudo apt-get install -y mingw-w64        # Debian/Ubuntu
#   brew install mingw-w64                   # macOS
#
# ## Pakai
#
#   tool/check-host-windows.sh               # cek cepat
#   tool/check-host-windows.sh --clippy      # + lint, sama seperti CI
#
# Catatan memori: crate `windows` besar sekali. Di mesin dengan RAM < 4 GB,
# rustc bisa kena OOM killer (terlihat sebagai "signal: 9, SIGKILL") — itu
# bukan error kode. Skrip memakai -j 1 dan mematikan debuginfo supaya muat di
# mesin kecil; kalau masih kena, tambah swap atau jalankan di mesin lain.

set -euo pipefail

TARGET="x86_64-pc-windows-gnu"
HOST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/host"
JOBS="${JOBS:-1}"

merah() { printf '\033[31m%s\033[0m\n' "$1"; }
hijau() { printf '\033[32m%s\033[0m\n' "$1"; }

if ! rustup target list --installed | grep -qx "$TARGET"; then
  merah "Target $TARGET belum dipasang."
  echo "  rustup target add $TARGET"
  exit 1
fi

if ! command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
  merah "mingw-w64 tidak ditemukan — build.rs vendor libopus butuh compiler C untuk target ini."
  echo "  sudo apt-get install -y mingw-w64   (Debian/Ubuntu)"
  echo "  brew install mingw-w64              (macOS)"
  exit 1
fi

cd "$HOST_DIR"

export CARGO_PROFILE_DEV_DEBUG=0
export CC_x86_64_pc_windows_gnu="${CC_x86_64_pc_windows_gnu:-x86_64-w64-mingw32-gcc}"
export AR_x86_64_pc_windows_gnu="${AR_x86_64_pc_windows_gnu:-x86_64-w64-mingw32-ar}"

echo "Memeriksa kode host untuk $TARGET (jalur cfg(windows) ikut dikompilasi)..."
cargo check --target "$TARGET" --all-targets -j "$JOBS"

if [ "${1:-}" = "--clippy" ]; then
  echo "Clippy untuk $TARGET..."
  cargo clippy --target "$TARGET" --all-targets -j "$JOBS" -- -D warnings
fi

hijau "OK — kode Windows lolos type check. Linking MSVC & perilaku runtime tetap diuji di CI/lab."
