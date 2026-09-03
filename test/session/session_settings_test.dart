// Kontrak pengaturan sesi terkait sumber papan ketik.
//
// [SessionSettings] mengontrol dua jalur input yang berbeda: papan ketik
// XyDesk (keycode Windows, untuk game & kontrol penuh) dan papan ketik
// sistem/IME (mengetik teks bebas). Nilai default dan salinan (copyWith)
// harus konsisten supaya sesi tidak mengganti sumber keyboard secara tak
// sengaja.

import 'package:flutter_test/flutter_test.dart';

import 'package:xydesk/features/session/session_panels.dart';

void main() {
  group('SessionSettings.keyboardSource', () {
    test('nilai default adalah papan ketik XyDesk', () {
      const s = SessionSettings();
      expect(s.keyboardSource, KeyboardSource.xydesk);
    });

    test('copyWith dapat mengganti ke papan ketik sistem', () {
      const s = SessionSettings();
      final next = s.copyWith(keyboardSource: KeyboardSource.system);
      expect(next.keyboardSource, KeyboardSource.system);
      // Nilai lain dipertahankan.
      expect(next.experience, s.experience);
      expect(next.haptics, s.haptics);
    });

    test('copyWith menjaga sumber yang sudah dipilih bila tidak diubah', () {
      const s = SessionSettings(keyboardSource: KeyboardSource.system);
      expect(s.copyWith(haptics: false).keyboardSource, KeyboardSource.system);
    });
  });
}
