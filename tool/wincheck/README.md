# wincheck — pemeriksa tipe kode Windows di mesin Linux/macOS

## Masalah yang diselesaikan

Seluruh kode capture, registry, audio, dan encoder XyDesk host ada di balik
`#[cfg(target_os = "windows")]`. CI menjalankan `cargo fmt --check`,
`cargo clippy -D warnings`, dan `cargo test` di **ubuntu-latest**, yang berarti
blok `cfg(windows)` tidak pernah disentuh sama sekali: bukan dikompilasi, bukan
di-lint, bukan diuji. Satu-satunya pemeriksaan nyata adalah job
`Windows x64/arm64` di workflow Build — dijalankan manual oleh operator dan
makan sekitar 10 menit sekali jalan.

Akibatnya mudah ditebak: `hwinfo.rs` pertama kali dikirim dengan lima error
kompilasi Windows (nama field `ullTotalRam` yang seharusnya `ullTotalPhys`,
konstanta `MONITORINFOF_PRIMARY` yang tidak diekspor crate `windows` 0.61,
newtype `ENUM_DISPLAY_SETTINGS_MODE`, dan `*const u64` yang seharusnya
`*mut u64`). Lima putaran CI untuk lima salah ketik.

## Cara pakai

```sh
rustup target add x86_64-pc-windows-msvc     # sekali saja
cd tool/wincheck
cargo check  --target x86_64-pc-windows-msvc
cargo clippy --target x86_64-pc-windows-msvc -- -D warnings
```

Selesai dalam hitungan detik setelah kompilasi pertama. Tidak butuh linker,
tidak butuh MSVC, tidak butuh Wine — fase `check` hanya melakukan type-check.

## Menambah modul host

1. Tambahkan `#[path = "../../../host/src/<modul>.rs"] pub mod <modul>;` di
   `src/lib.rs`.
2. Bila modul itu memakai API Win32 baru, tambahkan fiturnya ke
   `Cargo.toml` di sini **dan** di `host/Cargo.toml` — keduanya harus cocok,
   kalau tidak pemeriksaan ini lolos sementara Build tetap gagal.
3. Modul yang menarik dependensi berat (webrtc, openh264, encoder) lebih baik
   diwakili fungsi cermin seperti `primary_bit_ok` daripada disertakan utuh.

## Batas

Ini memeriksa **tipe**, bukan perilaku:

| Tertangkap di sini | Tidak tertangkap di sini |
| --- | --- |
| Salah nama field/fungsi Win32 | Logika salah (urutan, kondisi) |
| Salah tipe parameter/pointer | Urutan panggilan COM yang keliru |
| Fitur Cargo yang kurang | Kebocoran handle / resource |
| Peringatan clippy di kode Windows | HRESULT gagal saat runtime |
| Dead code di jalur Windows | Perilaku di mesin nyata |

Jadi: hijau di sini bukan berarti boleh melewatkan job Windows. Artinya
putaran CI yang mahal itu dipakai untuk hal yang hanya bisa dijawab mesin
Windows, bukan untuk salah ketik.

## Verifikasi bahwa alat ini benar-benar memeriksa

Alat verifikasi yang diam-diam tidak melakukan apa-apa lebih berbahaya daripada
tidak punya alat. Buktikan sesekali dengan uji negatif — rusak satu nama field
secara sengaja dan pastikan `cargo check` menolaknya:

```sh
sed -i 's/ullTotalPhys/ullTotalPhysSalah/' ../../host/src/hwinfo.rs
cargo check --target x86_64-pc-windows-msvc   # HARUS error E0609
git checkout ../../host/src/hwinfo.rs
```
