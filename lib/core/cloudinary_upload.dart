import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Upload foto profil ke Cloudinary (unsigned preset).
///
/// ## Kenapa unsigned, dan kenapa `api_secret` TIDAK ada di sini
/// Cloudinary mendukung dua jenis upload: **signed** (jalur kiri, butuh
/// `api_key` + `api_secret`) dan **unsigned** (jalur kanan, lewat `upload_preset`
/// yang dibuat di dasbor). Menanam `api_secret` di kode klien = membocorkan
/// kunci ke semua orang yang mendecompile APK — melanggar aturan repo
/// "jangan commit rahasia". Karena itu klien memakai **unsigned preset**:
/// ia hanya butuh `cloud_name` (bukan rahasia) dan nama preset.
///
/// ## Yang tersisa (dari operator, bukan kode)
/// Buka Cloudinary → Settings → Upload → Add upload preset → pilih **unsigned**
/// (signed = false), lalu isi nilainya ke [cloudinaryUploadPreset] di bawah.
/// Kalau belum diisi, tombol upload menampilkan pesan "belum dikonfigurasi"
/// dan tidak mengirim apa pun.

/// Nama cloud Cloudinary — bukan rahasia (muncul di URL publik hasil upload).
const cloudinaryCloudName = 'jxjvz3qi';

/// Nama unsigned upload preset. KOSONG sampai operator membuatnya di
/// dasbor Cloudinary. Kalau masih kosong, [uploadProfileImage] melempar
/// [CloudinaryUploadException] dengan pesan yang jelas, bukan gagal senyap.
const cloudinaryUploadPreset = '';

class CloudinaryUploadException implements Exception {
  CloudinaryUploadException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Upload satu gambar (bytes) → kembalikan URL publik `secure_url`.
///
/// Melempar [CloudinaryUploadException] bila preset belum dikonfigurasi atau
/// saat jaringan/Cloudinary menolak. Tidak pernah menaruh kunci di klien.
Future<String> uploadProfileImage(
  Uint8List bytes, {
  required String filename,
  String? uploadPreset,
  String? cloudName,
}) async {
  final preset = uploadPreset ?? cloudinaryUploadPreset;
  final cloud = cloudName ?? cloudinaryCloudName;

  if (preset.isEmpty) {
    throw CloudinaryUploadException(
      'Unggah foto belum dikonfigurasi. Operator perlu membuat unsigned '
      'upload preset di Cloudinary lalu mengisi cloudinaryUploadPreset.',
    );
  }

  final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloud/image/upload');

  final request = http.MultipartRequest('POST', uri);
  request.fields.addAll({
    'upload_preset': preset,
    'folder': 'profile',
    // Dipaksa jadi gambar API agar lewat jalur image/upload (bukan raw).
  });
  request.files.add(
    http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: null,
    ),
  );

  try {
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(streamed);
    final body = utf8.decode(res.bodyBytes);
    final data = body.isEmpty
        ? <String, dynamic>{}
        : (jsonDecode(body) as Map<String, dynamic>);
    if (res.statusCode != 200) {
      final err = data['error']?['message'];
      throw CloudinaryUploadException(
        'Unggah foto gagal: ${err ?? 'HTTP ${res.statusCode}'}',
      );
    }
    final url = (data['secure_url'] ?? data['url']) as String?;
    if (url == null) {
      throw CloudinaryUploadException(
        'Cloudinary tidak mengembalikan URL gambar.',
      );
    }
    return url;
  } on CloudinaryUploadException {
    rethrow;
  } catch (e) {
    throw CloudinaryUploadException(
      'Tidak dapat mengunggah foto (periksa koneksi). $e',
    );
  }
}
