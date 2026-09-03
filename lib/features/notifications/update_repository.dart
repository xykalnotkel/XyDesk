import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'app_update_details.dart';

const _repository = 'xykalnotkel/XyDesk';
const _officialHost = 'github.com';
const _manifestUrl =
    'https://github.com/xykalnotkel/XyDesk/releases/latest/download/update.json';

class OfficialUpdateManifest {
  const OfficialUpdateManifest({
    required this.version,
    required this.buildNumber,
    required this.tag,
    required this.apkUri,
    required this.apkSha256,
    required this.apkBytes,
    required this.details,
  });

  final String version;
  final int buildNumber;
  final String tag;
  final Uri apkUri;
  final String apkSha256;
  final int apkBytes;
  final AppUpdateDetails details;

  static OfficialUpdateManifest fromJson(
    Map<String, dynamic> json, {
    required String androidAbi,
  }) {
    if (json['schema'] != 2) {
      throw const UpdateCheckException(
        'Format metadata update belum didukung.',
      );
    }

    final version = _requiredText(json, 'version', maxLength: 32);
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
      throw const UpdateCheckException('Versi update resmi tidak valid.');
    }

    final buildNumber = json['build'];
    if (buildNumber is! int || buildNumber <= 0) {
      throw const UpdateCheckException('Nomor build update resmi tidak valid.');
    }

    final tag = _requiredText(json, 'tag', maxLength: 48);
    if (tag != 'v$version') {
      throw const UpdateCheckException('Tag dan versi update tidak cocok.');
    }

    if (androidAbi != 'arm64-v8a' && androidAbi != 'armeabi-v7a') {
      throw const UpdateCheckException(
        'Arsitektur Android perangkat ini tidak didukung rilis XyDesk.',
      );
    }
    final apks = json['apks'];
    final apk = apks is Map<String, dynamic> ? apks[androidAbi] : null;
    if (apk is! Map<String, dynamic>) {
      throw const UpdateCheckException(
        'Paket update untuk arsitektur perangkat tidak tersedia.',
      );
    }

    final apkUri = Uri.tryParse(_requiredText(apk, 'url', maxLength: 512));
    final expectedPath =
        '/$_repository/releases/download/$tag/XyDesk-Android-$androidAbi.apk';
    if (apkUri == null ||
        apkUri.scheme != 'https' ||
        apkUri.host != _officialHost ||
        apkUri.path != expectedPath ||
        apkUri.hasQuery ||
        apkUri.hasFragment) {
      throw const UpdateCheckException('Alamat APK resmi tidak valid.');
    }

    final apkSha256 = _requiredText(apk, 'sha256', maxLength: 64).toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(apkSha256)) {
      throw const UpdateCheckException('Checksum APK resmi tidak valid.');
    }

    final apkBytes = apk['bytes'];
    if (apkBytes is! int || apkBytes <= 0) {
      throw const UpdateCheckException('Ukuran APK resmi tidak valid.');
    }

    final notes = <String>[];
    final rawNotes = json['notes'];
    if (rawNotes is List) {
      for (final rawNote in rawNotes.take(8)) {
        if (rawNote is String && rawNote.trim().isNotEmpty) {
          notes.add(rawNote.trim());
        }
      }
    }

    final details = AppUpdateDetails(
      title: _optionalText(json['title']) ?? 'XyDesk Update!! Cek Sekarang',
      message:
          _optionalText(json['summary']) ?? 'Versi terbaru XyDesk tersedia.',
      version: 'Versi $version · Build $buildNumber',
      releaseNotes: notes,
    );

    return OfficialUpdateManifest(
      version: version,
      buildNumber: buildNumber,
      tag: tag,
      apkUri: apkUri,
      apkSha256: apkSha256,
      apkBytes: apkBytes,
      details: details,
    );
  }

  Uri get releasePageUri =>
      Uri.parse('https://github.com/$_repository/releases/tag/$tag');
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.installedVersion,
    required this.installedBuildNumber,
    required this.isAndroid,
    required this.manifest,
    required this.updateAvailable,
  });

  final String installedVersion;
  final int installedBuildNumber;
  final bool isAndroid;
  final OfficialUpdateManifest manifest;
  final bool updateAvailable;
}

class OfficialUpdateRepository {
  const OfficialUpdateRepository();

  static const _updateChannel = MethodChannel('com.xystudio.xydesk/update');

  Future<UpdateCheckResult> check() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final androidAbi = isAndroid
        ? await _updateChannel.invokeMethod<String>('getPrimaryAbi')
        : 'arm64-v8a';
    if (androidAbi == null || androidAbi.isEmpty) {
      throw const UpdateCheckException(
        'Arsitektur Android tidak dapat dideteksi dengan aman.',
      );
    }
    final installedBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
    final response = await http
        .get(
          Uri.parse(_manifestUrl),
          headers: const {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw UpdateCheckException(
        'Server update resmi belum dapat dihubungi (${response.statusCode}).',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const UpdateCheckException('Metadata update resmi rusak.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const UpdateCheckException('Metadata update resmi tidak valid.');
    }

    final manifest = OfficialUpdateManifest.fromJson(
      decoded,
      androidAbi: androidAbi,
    );
    final updateAvailable = isAndroid
        ? manifest.buildNumber > installedBuild
        : _compareVersions(manifest.version, packageInfo.version) > 0;

    return UpdateCheckResult(
      installedVersion: packageInfo.version,
      installedBuildNumber: installedBuild,
      isAndroid: isAndroid,
      manifest: manifest,
      updateAvailable: updateAvailable,
    );
  }

  /// Ambil isi changelog lengkap dari body GitHub Release resmi.
  ///
  /// `release.yml` menulis body Release dari `CHANGELOG.md`, jadi inilah
  /// catatan perubahan paling lengkap. Manifest `update.json` hanya membawa
  /// beberapa catatan ringkas ("Yang disiapkan"), sehingga halaman pembaruan
  /// tampil pincang tanpa bagian ini. Mengembalikan `null` bila gagal (mis.
  /// offline) — halaman tetap jalan memakai catatan ringkas.
  Future<String?> releaseBody(String tag) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/$_repository/releases/tags/$tag',
            ),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'XyDesk',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return null;
      final body = decoded['body'];
      return body is String && body.trim().isNotEmpty ? body : null;
    } catch (_) {
      return null;
    }
  }
}

class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Ubah markdown changelog (body GitHub Release) menjadi daftar catatan
/// yang bisa ditampilkan sebagai baris di halaman pembaruan.
///
/// - Baris heading versi (`## [6.3.0]`) dipertahankan sebagai judul bagian.
/// - Sub-heading (`### Ditambahkan`, `### Diubah`, dst) disimpan.
/// - Butir daftar (`- ...`) memakai teksnya; penanda daftar dibuang.
/// - Baris kosong, gambar, tabel, dan blok `<...>` direnggangkan.
///
/// Mengembalikan daftar kosong bila `body` null / kosong.
List<String> parseChangelogMarkdown(String? body) {
  if (body == null || body.trim().isEmpty) return const [];
  final lines = body.split('\n');
  final out = <String>[];
  var sawVersion = false;
  for (final raw in lines) {
    final line = raw.trimRight();
    final trimmed = line.trim();
    // Lewati tabel markdown, gambar, blok HTML, dan baris kosong.
    if (trimmed.isEmpty ||
        trimmed.startsWith('|') ||
        RegExp(r'^!\[|^<').hasMatch(trimmed)) {
      continue;
    }
    if (RegExp(r'^##\s').hasMatch(trimmed)) {
      out.add(trimmed.replaceFirst(RegExp(r'^##\s+'), ''));
      sawVersion = true;
      continue;
    }
    if (RegExp(r'^###\s').hasMatch(trimmed)) {
      out.add(trimmed.replaceFirst(RegExp(r'^###\s+'), ''));
      continue;
    }
    // Butir daftar: buang penanda baris.
    final bullet = RegExp(r'^\s*[-*+]\s+').firstMatch(line);
    String text;
    if (bullet != null) {
      text = trimmed.replaceFirst(RegExp(r'^[-*+]\s+'), '');
    } else {
      // Baris non-daftar dalam changelog — simpan apa adanya, tetapi jangan
      // mulai sebelum heading versi pertama.
      if (!sawVersion) continue;
      text = trimmed;
    }
    // Bersihkan inline markdown (tautan/gambar/tebal) agar teks terbaca.
    // `replaceAllMapped` dipakai karena Dart tidak mengevaluasi `$1` pada
    // `replaceAll` dengan String biasa.
    text = text
        .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m[1] ?? '')
        .replaceAllMapped(RegExp(r'!\[([^\]]*)\]\([^)]*\)'), (m) => m[1] ?? '')
        .replaceAll(RegExp(r'[*_`~]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.isNotEmpty) out.add(text);
  }
  return out;
}

String _requiredText(
  Map<String, dynamic> source,
  String key, {
  required int maxLength,
}) {
  final value = source[key];
  if (value is! String ||
      value.trim().isEmpty ||
      value.trim().length > maxLength) {
    throw const UpdateCheckException('Metadata update resmi tidak lengkap.');
  }
  return value.trim();
}

String? _optionalText(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return trimmed.length <= 240 ? trimmed : trimmed.substring(0, 240);
}

int _compareVersions(String left, String right) {
  List<int> parts(String value) => value
      .split(RegExp(r'[.+-]'))
      .take(3)
      .map((part) => int.tryParse(part) ?? 0)
      .toList(growable: false);

  final a = parts(left);
  final b = parts(right);
  for (var index = 0; index < 3; index++) {
    final aPart = index < a.length ? a[index] : 0;
    final bPart = index < b.length ? b[index] : 0;
    if (aPart != bPart) return aPart.compareTo(bPart);
  }
  return 0;
}
