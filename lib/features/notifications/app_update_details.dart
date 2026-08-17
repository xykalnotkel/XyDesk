import 'dart:convert';

/// Data yang ditampilkan oleh halaman pembaruan internal.
///
/// Detail boleh datang dari Additional Data OneSignal, tetapi pemeriksaan dan
/// download selalu memakai manifest GitHub Release resmi. URL dari payload tidak
/// pernah dieksekusi.
class AppUpdateDetails {
  const AppUpdateDetails({
    required this.title,
    required this.message,
    required this.version,
    required this.releaseNotes,
  });

  final String title;
  final String message;
  final String version;
  final List<String> releaseNotes;

  factory AppUpdateDetails.updateCenter() => const AppUpdateDetails(
        title: 'Pusat Pembaruan XyDesk',
        message:
            'XyDesk akan membandingkan versi terpasang dengan manifest GitHub '
            'Release resmi.',
        version: 'Memeriksa versi resmi',
        releaseNotes: [
          'Catatan perubahan lengkap tersedia bersama setiap rilis resmi.',
          'APK hanya diambil dari repositori resmi XyDesk di GitHub Releases.',
        ],
      );

  factory AppUpdateDetails.fromPayload({
    required String? notificationTitle,
    required String? notificationBody,
    required Map<String, dynamic>? data,
  }) {
    final payload = data ?? const <String, dynamic>{};
    final title = _displayText(payload['title'], maxLength: 80) ??
        _displayText(notificationTitle, maxLength: 80) ??
        'XyDesk Update';
    final message = _displayText(payload['summary'], maxLength: 320) ??
        _displayText(payload['message'], maxLength: 320) ??
        _displayText(notificationBody, maxLength: 320) ??
        'Pembaruan XyDesk tersedia. Lihat detailnya sebelum mengunduh.';
    final version = _version(payload['version']) ?? 'Rilis terbaru';
    final notes = _parseNotes(payload['notes']);

    return AppUpdateDetails(
      title: title,
      message: message,
      version: version,
      releaseNotes: notes.isEmpty
          ? const ['Detail perubahan tersedia di catatan rilis resmi.']
          : notes,
    );
  }

  static bool isUpdateDestination(
    Map<String, dynamic>? data, {
    String? actionId,
  }) {
    if (actionId == 'open_update') return true;
    if (data == null) return false;

    for (final key in const ['route', 'screen', 'type']) {
      final value = _nonEmpty(data[key])?.toLowerCase();
      if (value == 'app_update' ||
          value == 'update' ||
          value == '/app-update') {
        return true;
      }
    }
    return false;
  }

  static String? _nonEmpty(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String? _displayText(Object? value, {required int maxLength}) {
    final text = _nonEmpty(value)
        ?.replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text == null || text.isEmpty) return null;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 1).trimRight()}…';
  }

  static String? _version(Object? value) {
    final text = _displayText(value, maxLength: 32);
    if (text == null) return null;
    return RegExp(r'^[A-Za-z0-9][A-Za-z0-9 ._+()\-]{0,31}$').hasMatch(text)
        ? text
        : null;
  }

  static List<String> _sanitizeNotes(Iterable<dynamic> values) {
    return values
        .map((value) => _displayText(value, maxLength: 180))
        .whereType<String>()
        .take(8)
        .toList(growable: false);
  }

  static List<String> _parseNotes(Object? raw) {
    if (raw is List) return _sanitizeNotes(raw);

    final text = _nonEmpty(raw);
    if (text == null || text.length > 3000) return const [];

    try {
      final decoded = jsonDecode(text);
      if (decoded is List) return _sanitizeNotes(decoded);
    } on FormatException {
      // Dashboard juga nyaman diisi dengan satu catatan per baris.
    }

    return _sanitizeNotes(
      text
          .split(RegExp(r'\r?\n|\s*\|\s*'))
          .map((line) => line.replaceFirst(RegExp(r'^[-•]\s*'), '').trim()),
    );
  }
}
