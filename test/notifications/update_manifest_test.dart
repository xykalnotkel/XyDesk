// Kontrak manifest update resmi (`update.json` skema 2).
//
// Manifest dibaca dua platform: Android memakai kunci `apks`, desktop
// memakai kunci `windows`. Parser Android wajib mengabaikan kunci milik
// desktop — bukan menolak manifestnya.

import 'package:flutter_test/flutter_test.dart';

import 'package:xydesk/features/notifications/update_repository.dart';

Map<String, dynamic> _manifest() => {
  'schema': 2,
  'version': '6.7.13',
  'build': 48,
  'tag': 'v6.7.13',
  'title': 'XyDesk Update!! Cek Sekarang',
  'summary': 'Ringkasan.',
  'notes': ['Satu catatan.'],
  'apks': {
    'arm64-v8a': {
      'url':
          'https://github.com/xykalnotkel/XyDesk/releases/download/v6.7.13/XyDesk-Android-arm64-v8a.apk',
      'sha256': 'a' * 64,
      'bytes': 41000000,
    },
    'armeabi-v7a': {
      'url':
          'https://github.com/xykalnotkel/XyDesk/releases/download/v6.7.13/XyDesk-Android-armeabi-v7a.apk',
      'sha256': 'b' * 64,
      'bytes': 33000000,
    },
  },
  // Kunci milik desktop — parser Android harus mengabaikannya.
  'windows': {
    'x64': {
      'url':
          'https://github.com/xykalnotkel/XyDesk/releases/download/v6.7.13/XyDesk-x64.exe',
      'sha256': 'c' * 64,
      'bytes': 9000000,
    },
    'arm64': {
      'url':
          'https://github.com/xykalnotkel/XyDesk/releases/download/v6.7.13/XyDesk-arm64.exe',
      'sha256': 'd' * 64,
      'bytes': 8000000,
    },
  },
  'release_url': 'https://github.com/xykalnotkel/XyDesk/releases/tag/v6.7.13',
  'banner_url':
      'https://github.com/xykalnotkel/XyDesk/releases/download/v6.7.13/xydesk_update_banner_1024x512.jpg',
};

void main() {
  group('OfficialUpdateManifest.fromJson', () {
    test('manifest lengkap (termasuk kunci windows) terurai', () {
      final m = OfficialUpdateManifest.fromJson(
        _manifest(),
        androidAbi: 'arm64-v8a',
      );

      expect(m.version, '6.7.13');
      expect(m.buildNumber, 48);
      expect(m.tag, 'v6.7.13');
      expect(m.apkBytes, 41000000);
      expect(m.apkSha256, 'a' * 64);
      expect(
        m.apkUri.path,
        '/xykalnotkel/XyDesk/releases/download/v6.7.13/XyDesk-Android-arm64-v8a.apk',
      );
      expect(m.details.releaseNotes, ['Satu catatan.']);
    });

    test('ABI lain memilih entri APK yang benar', () {
      final m = OfficialUpdateManifest.fromJson(
        _manifest(),
        androidAbi: 'armeabi-v7a',
      );

      expect(m.apkBytes, 33000000);
      expect(m.apkSha256, 'b' * 64);
    });

    test('skema selain 2 ditolak', () {
      final bad = _manifest()..['schema'] = 3;

      expect(
        () => OfficialUpdateManifest.fromJson(bad, androidAbi: 'arm64-v8a'),
        throwsA(isA<UpdateCheckException>()),
      );
    });

    test('tag yang tidak cocok dengan versi ditolak', () {
      final bad = _manifest()..['tag'] = 'v9.9.9';

      expect(
        () => OfficialUpdateManifest.fromJson(bad, androidAbi: 'arm64-v8a'),
        throwsA(isA<UpdateCheckException>()),
      );
    });
  });
}
