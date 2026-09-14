// Kontrak label statistik sesi yang dibaca pengguna.
//
// `noFrameWarning` adalah inti watchdog "terhubung tapi belum ada gambar"
// (10 detik setelah connected tanpa frame). Banner di session_page.dart
// dan rail di web bergantung pada label ini jujur: sebelum tenggat lewat
// pengguna boleh melihat "Belum ada gambar" biasa, sesudah tenggat ia
// harus diarahkan memeriksa PC host — bukan dibiarkan menunggu selamanya.

import 'package:flutter_test/flutter_test.dart';

import 'package:xydesk/webrtc/rtc_service.dart';

void main() {
  group('SessionStats.hasVideo', () {
    test('false selama dimensi frame belum diketahui', () {
      expect(const SessionStats().hasVideo, isFalse);
      expect(const SessionStats(width: 1920).hasVideo, isFalse);
      expect(const SessionStats(height: 1080).hasVideo, isFalse);
    });

    test('true begitu kedua dimensi frame ada', () {
      expect(const SessionStats(width: 1920, height: 1080).hasVideo, isTrue);
    });
  });

  group('SessionStats.resolutionLabel', () {
    test('menampilkan dimensi saat video mengalir', () {
      expect(
        const SessionStats(width: 2560, height: 1440).resolutionLabel,
        '2560 x 1440',
      );
    });

    test('netral sebelum watchdog tenggat', () {
      expect(const SessionStats().resolutionLabel, 'Belum ada gambar');
    });

    test('mengarahkan ke PC host setelah watchdog tenggat', () {
      expect(
        const SessionStats(noFrameWarning: true).resolutionLabel,
        'Belum ada gambar (periksa PC)',
      );
    });
  });

  group('SessionStats.copyWith', () {
    test('menurunkan noFrameWarning dan dimensi apa adanya', () {
      const awal = SessionStats(width: 1280, height: 720);
      final turun = awal.copyWith(noFrameWarning: true);
      expect(turun.noFrameWarning, isTrue);
      expect(turun.width, 1280);
      expect(turun.height, 720);
      expect(turun.hasVideo, isTrue);
    });

    test('bisa memulihkan keadaan tanpa memalsukan dimensi', () {
      const waspada = SessionStats(noFrameWarning: true);
      final pulih = waspada.copyWith(
        noFrameWarning: false,
        width: 800,
        height: 600,
      );
      expect(pulih.noFrameWarning, isFalse);
      expect(pulih.resolutionLabel, '800 x 600');
    });
  });
}
