# Aset gambar

Skrip untuk membuat ulang logo dan ilustrasi.

## Alur

1. Buat gambar sumber (AI atau manual) dengan **latar putih polos**,
   simpan ke `raw/`.
2. Jalankan pemrosesan — menghapus latar, merapikan tepi, memotong margin,
   lalu mengekspor PNG + WebP ke `out/`:

   ```bash
   pip install pillow
   python3 tool/art/process.py
   ```

3. Salin hasilnya ke `assets/img/`, lalu buat ikon launcher Android:

   ```bash
   python3 tool/art/launcher.py android/app/src/main/res
   ```

## Kenapa flood-fill, bukan "semua putih jadi transparan"

Logo XyDesk punya layar monitor terang di tengah huruf X. Kalau semua piksel
putih dihapus, bagian itu ikut hilang. `process.py` hanya menjalar dari tepi
gambar, jadi putih yang terkurung di dalam bentuk tetap aman.

## Format

| Jenis | Format | Alasan |
|---|---|---|
| Logo | PNG | Perlu tepi tajam saat dipakai kecil |
| Ilustrasi | WebP q92 | ~60% lebih ringan pada gambar vektor-3D |

Berkas `raw/` sengaja **tidak** disimpan di repo agar ukurannya tetap kecil.
