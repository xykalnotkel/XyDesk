import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  static OfficialUpdateManifest fromJson(Map<String, dynamic> json) {
    if (json['schema'] != 1) {
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

    final apk = json['apk'];
    if (apk is! Map<String, dynamic>) {
      throw const UpdateCheckException('Metadata APK resmi tidak tersedia.');
    }

    final apkUri = Uri.tryParse(_requiredText(apk, 'url', maxLength: 512));
    final expectedPath = '/$_repository/releases/download/$tag/XyDesk.apk';
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

  Future<UpdateCheckResult> check() async {
    final packageInfo = await PackageInfo.fromPlatform();
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

    final manifest = OfficialUpdateManifest.fromJson(decoded);
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
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
}

class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message);

  final String message;

  @override
  String toString() => message;
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
