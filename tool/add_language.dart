// Alat bantu menambah bahasa baru ke XyDesk.
//
// Cara pakai:
//   dart run tool/add_language.dart <kode> "<Nama Inggris>" "<Nama Asli>" [rtl]
//
// Contoh:
//   dart run tool/add_language.dart ja Japanese 日本語
//   dart run tool/add_language.dart he Hebrew עברית rtl
//
// Script akan:
//   1. Menambahkan konstanta bahasa ke `AppLang`
//   2. Menyisipkan entri kosong untuk SEMUA kunci di `kStrings`
//   3. Menulis daftar kunci yang perlu diterjemahkan ke `l10n_todo.txt`
//
// Kunci yang belum diisi otomatis jatuh ke bahasa Inggris saat runtime,
// jadi aplikasi tetap jalan normal walau terjemahan belum lengkap.

import 'dart:io';

void main(List<String> args) {
  if (args.length < 3) {
    stderr.writeln(
      'Pemakaian: dart run tool/add_language.dart <kode> "<Nama>" "<Nama Asli>" [rtl]\n'
      'Contoh   : dart run tool/add_language.dart ja Japanese 日本語',
    );
    exit(64);
  }

  final code = args[0].toLowerCase();
  final name = args[1];
  final native = args[2];
  final rtl = args.length > 3 && args[3].toLowerCase() == 'rtl';

  final file = File('lib/l10n/strings.dart');
  if (!file.existsSync()) {
    stderr.writeln(
      'Tidak menemukan lib/l10n/strings.dart. '
      'Jalankan dari akar proyek.',
    );
    exit(66);
  }

  var src = file.readAsStringSync();

  if (RegExp("'$code':").hasMatch(src)) {
    stdout.writeln('Bahasa "$code" sudah ada. Tidak ada perubahan.');
    return;
  }

  // 1) Tambah konstanta AppLang
  final constLine =
      "  static const $code = AppLang('$code', '$name', "
      "'$native'${rtl ? ', rtl: true' : ''});";
  src = src.replaceFirst(
    RegExp(r'\n\n  static const all = <AppLang>\['),
    '\n$constLine\n\n  static const all = <AppLang>[',
  );
  src = src.replaceFirst(
    RegExp(r'static const all = <AppLang>\[([^\]]*)\];'),
    'static const all = <AppLang>[\$1, $code];',
  );

  // 2) Sisipkan entri kosong untuk setiap kunci.
  //    Ditaruh setelah entri 'en' agar mudah dibandingkan saat menerjemahkan.
  final todo = <String>[];
  final keyRe = RegExp(r"^  '([a-z0-9_]+)': \{", multiLine: true);
  for (final m in keyRe.allMatches(src).toList().reversed) {
    final key = m.group(1)!;
    final blockStart = m.end;
    final blockEnd = src.indexOf('},', blockStart);
    if (blockEnd == -1) continue;
    final block = src.substring(blockStart, blockEnd);
    if (block.contains("'$code':")) continue;

    // ambil teks Inggris sebagai acuan penerjemah
    final enM = RegExp(r"'en': '([^']*)'").firstMatch(block);
    final enText = enM?.group(1) ?? '';
    todo.add('$key = $enText');

    src = src.replaceRange(blockEnd, blockEnd, "    '$code': '',\n  ");
  }

  file.writeAsStringSync(src);

  // 3) Tulis daftar tugas terjemahan
  final todoFile = File('l10n_todo_$code.txt');
  todoFile.writeAsStringSync(
    'Terjemahan yang perlu diisi untuk "$name" ($code)\n'
    'Isi nilai kosong di lib/l10n/strings.dart pada kunci berikut.\n'
    'Format: kunci = teks bahasa Inggris\n'
    '${'-' * 60}\n'
    '${todo.reversed.join('\n')}\n',
  );

  stdout
    ..writeln('Bahasa ditambahkan: $name ($code)${rtl ? ' [RTL]' : ''}')
    ..writeln('  ${todo.length} kunci menunggu terjemahan')
    ..writeln('  Daftar tugas: ${todoFile.path}')
    ..writeln('')
    ..writeln(
      'Kunci kosong otomatis memakai bahasa Inggris, '
      'jadi aplikasi tetap berjalan normal.',
    )
    ..writeln('Jalankan `dart format lib/l10n/strings.dart` setelah mengisi.');
}
