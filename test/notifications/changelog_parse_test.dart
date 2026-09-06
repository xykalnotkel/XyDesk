// Kontrak parser changelog halaman pembaruan.
//
// Body GitHub Release berisi `CHANGELOG.md` (markdown). Parser ini mengubahnya
// menjadi daftar catatan untuk ditampilkan rapi di "Pusat Update". Uji ini
// memastikan heading versi, sub-heading, dan butir daftar terbaca dengan benar,
// sementara gambar, tabel, dan link inline tidak bocor sebagai teks mentah.

import 'package:flutter_test/flutter_test.dart';

import 'package:xydesk/features/notifications/update_repository.dart';

void main() {
  test('heading versi, sub-heading, dan butir daftar terbaca', () {
    const body = '''
# Changelog XyDesk

## [6.3.0] - 2026-09-03

### Ditambahkan
- Ikon nav AI ungu glossy.
- Papan ketik sistem.

### Diubah
- Halaman pembaruan kini menampilkan changelog lengkap.

## [6.2.2] - 2026-09-01

### Diperbaiki
- Tombol suka berita.
''';
    final notes = parseChangelogMarkdown(body);
    expect(notes, contains('[6.3.0] - 2026-09-03'));
    expect(notes, contains('Ditambahkan'));
    expect(notes, contains('Ikon nav AI ungu glossy.'));
    expect(notes, contains('Papan ketik sistem.'));
    expect(notes, contains('Diubah'));
    expect(notes, contains('[6.2.2] - 2026-09-01'));
    // Penanda daftar "-" dibuang.
    expect(notes.any((n) => n.startsWith('-')), isFalse);
  });

  test('gambar, tabel, dan link inline tidak bocor sebagai teks mentah', () {
    const body = '''
## [6.3.0]

![banner](https://app.xydesk.my.id/banner.jpg)
- Lihat [detail rilis](https://github.com/x) untuk informasi.
| Kolom | Nilai |
| a | b |
- Teks biasa.
''';
    final notes = parseChangelogMarkdown(body);
    // Tautan inline diubah menjadi teks labelnya, bukan URL mentah.
    expect(notes, contains('Lihat detail rilis untuk informasi.'));
    expect(notes.any((n) => n.contains('banner.jpg')), isFalse);
    expect(notes.any((n) => n.contains('github.com')), isFalse);
    expect(notes, contains('Teks biasa.'));
  });

  test('null / kosong menghasilkan daftar kosong', () {
    expect(parseChangelogMarkdown(null), isEmpty);
    expect(parseChangelogMarkdown(''), isEmpty);
    expect(parseChangelogMarkdown('   '), isEmpty);
  });
}
