// Kontrak penyimpanan & parsing foto profil.
//
// Nilai yang disimpan adalah teks (`preset:<seed>` atau `url:<encoded>`)
// supaya tidak butuh backend dan tidak menambah dependensi. Uji ini mengunci
// bahwa parsing mengembalikan jenis yang benar, sehingga widget tahu harus
// merender SvgPicture atau Image.network.

import 'package:flutter_test/flutter_test.dart';

import 'package:xydesk/widgets/profile_avatar.dart';

void main() {
  group('parseAvatar', () {
    test('nilai kosong / null', () {
      expect(parseAvatar(null).isPreset, false);
      expect(parseAvatar(null).payload, '');
      expect(parseAvatar('').isPreset, false);
      expect(parseAvatar('').payload, '');
    });

    test('preset', () {
      final p = parseAvatar('preset:Biru');
      expect(p.isPreset, true);
      expect(p.payload, 'Biru');
    });

    test('url', () {
      final p = parseAvatar('url:https%3A%2F%2Fexample.com%2Fa.png');
      expect(p.isPreset, false);
      expect(p.payload, 'https%3A%2F%2Fexample.com%2Fa.png');
    });

    test('nilai tak dikenal diperlakukan kosong', () {
      final p = parseAvatar('aneh');
      expect(p.isPreset, false);
      expect(p.payload, '');
    });
  });

  test('presetAvatarUrl membangun URL DiceBear SVG', () {
    final u = presetAvatarUrl('Kirana');
    expect(u, startsWith('https://api.dicebear.com/9.x/adventurer/svg'));
    expect(u, contains('seed=Kirana'));
  });

  test('daftar preset non-kosong', () {
    expect(profileAvatarSeeds, isNotEmpty);
    expect(profileAvatarSeeds.length, greaterThanOrEqualTo(4));
  });
}
