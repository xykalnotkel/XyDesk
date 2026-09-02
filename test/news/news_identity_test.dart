// Kontrak identitas komentator berita di klien.
//
// Nama tampilan dan URL avatar di Flutter HARUS dibangkitkan dengan aturan
// yang identik dengan web (`web/src/news.ts`) supaya nama sama memunculkan
// wajah sama di semua platform, dan label teknis `tamu-xxxx` tidak bocor
// ke kolom komentar. Perbahan apa pun yang melenceng dari kontrak ini
// berarti perangkat yang sama bisa dianggap "orang lain".

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xydesk/core/store.dart';
import 'package:xydesk/features/news/news_avatar.dart';
import 'package:xydesk/features/news/news_service.dart';

void main() {
  Future<NewsApi> apiWithMock({String? fingerprint, String? storedName}) async {
    SharedPreferences.setMockInitialValues({
      if (fingerprint != null) 'news_fp': fingerprint,
      if (storedName != null) 'news_display_name': storedName,
    });
    return NewsApi(await Store.open());
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('displayName', () {
    test('menghasilkan nama manusia, bukan label teknis tamu-xxxx', () async {
      final api = await apiWithMock();
      final name = api.displayName;
      expect(name, isNot(startsWith('tamu-')));
      expect(name, contains(' '));
      expect(api.displayName, name); // tersimpan, stabil
    });

    test(
      'deterministik untuk sidik jari yang sama (nama sama, bukan acak)',
      () async {
        const fp = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';
        final a = await apiWithMock(fingerprint: fp);
        final b = await apiWithMock(fingerprint: fp, storedName: a.displayName);
        expect(b.displayName, a.displayName);
      },
    );

    test('membangkitkan ulang nama lama "tamu-xxxx"', () async {
      final api = await apiWithMock(
        fingerprint: 'ffffffff000000001111222233334444',
        storedName: 'tamu-abc1',
      );
      expect(api.displayName, isNot(startsWith('tamu-')));
    });

    test('tidak menyentuh nama yang sudah manusiawi', () async {
      final api = await apiWithMock(
        fingerprint: 'ffffffff000000001111222233334444',
        storedName: 'Raka Saputra',
      );
      expect(api.displayName, 'Raka Saputra');
    });
  });

  group('avatar', () {
    test('URL DiceBear menyematkan nama sebagai seed (dienkode) dan SVG', () {
      final u = newsAvatarUrl('Raka Saputra');
      expect(u, startsWith('https://api.dicebear.com/9.x/adventurer/svg'));
      expect(u, contains('seed=Raka%20Saputra'));
      expect(u, contains('backgroundColor=ede9fe'));
    });

    test('resmi tidak lewat DiceBear — memakai foto pendiri', () {
      expect(newsFounderAvatar, contains('/team/founder.jpg'));
    });
  });
}
