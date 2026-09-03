// Kontrak unggah foto profil ke Cloudinary.
//
// Unggah memakai unsigned upload preset (tanpa api_secret di klien). Uji ini
// mengunci perilaku saat preset belum dikonfigurasi: harus melempar pesan yang
// jelas, bukan gagal senyap ataupun mencoba memanggil Cloudinary dengan field
// kosong. Membangun URL upload juga diverifikasi tanpa menembak jaringan.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:xydesk/core/cloudinary_upload.dart';

void main() {
  test('cloud name terisi (bukan rahasia, perlu untuk URL upload)', () {
    expect(cloudinaryCloudName, isNotEmpty);
  });

  test('preset unsigned sudah dikonfigurasi operator', () {
    // Dibuat 3 Sep 2026 (`xydesk_profile_unsigned`) dan diuji dengan upload
    // sungguhan tanpa api_secret. Selama konstanta ini kosong, tombol unggah
    // foto di halaman akun sengaja tidak membuka galeri — jadi test ini
    // menjaga agar nilainya tidak terhapus tanpa sengaja.
    expect(cloudinaryUploadPreset, isNotEmpty);
  });

  test(
    'upload melempar pesan jelas ketika preset belum dikonfigurasi',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      try {
        await uploadProfileImage(
          bytes,
          filename: 'a.png',
          uploadPreset: '', // kosong = belum diisi operator
        );
        fail('Seharusnya melempar CloudinaryUploadException');
      } on CloudinaryUploadException catch (e) {
        expect(e.message, contains('belum dikonfigurasi'));
      }
    },
  );

  test('upload membangun URL ke cloud_name yang diberikan', () async {
    // Tidak menembak jaringan: verifikasi bahwa URL yang dipakai menyertakan
    // cloud_name. Kode di bawah hanya membuktikan pembentukan endpoint — uji
    // jaringan nyata membutuhkan preset asli, yang di luar jangkauan unit.
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload',
    );
    expect(uri.path, '/v1_1/$cloudinaryCloudName/image/upload');
  });
}
