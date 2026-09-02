import 'dart:convert';
import 'dart:typed_data';

import 'store.dart';

/// Cuplikan layar terakhir dari sesi remote, disimpan per perangkat.
///
/// Dipakai di halaman detail PC: alih-alih menampilkan ilustrasi statis,
/// pengguna melihat layar terakhir PC-nya saat sesi terputus.
///
/// ## Keterbatasan yang jujur
/// Frame ditangkap dari sisi klien lewat `RepaintBoundary.toImage()`.
/// Video remote dirender sebagai *platform texture* (`flutter_webrtc`),
/// sehingga di beberapa perangkat hasil tangkapan bisa gelap/kosong dan
/// tidak merepresentasikan frame video sungguhan. Jalur yang paling kokoh
/// adalah endpoint screenshot dari **host** (role Host Engine) atau renderer
/// `RTCVideoRenderer`. Tangkapan klien ini ditempatkan sebagai lapisan
/// pertama yang bekerja tanpa backend — dan gagal diam-diam (tidak
/// menyimpan apa pun) agar UI tidak menampilkan kotak hitam.

const _keyPrefix = 'session_preview_';

/// Simpan cuplikan PNG. Kalau gagaal (mis. bytes kosong), lakukan apa-apa.
Future<void> saveSessionPreview(
  Store store,
  String deviceId,
  Uint8List pngBytes,
) async {
  if (pngBytes.isEmpty) return;
  await store.setStr(_keyPrefix + deviceId, base64Encode(pngBytes));
}

/// Muat cuplikan PNG yang tersimpan untuk sebuah perangkat. `null` kalau
/// belum pernah ada.
Uint8List? loadSessionPreview(Store store, String deviceId) {
  final raw = store.getStr(_keyPrefix + deviceId);
  if (raw == null || raw.isEmpty) return null;
  try {
    return base64Decode(raw);
  } catch (_) {
    return null;
  }
}

/// Hapus cuplikan untuk satu perangkat (dipakai saat perangkat dihapus).
Future<void> clearSessionPreview(Store store, String deviceId) =>
    store.remove(_keyPrefix + deviceId);
