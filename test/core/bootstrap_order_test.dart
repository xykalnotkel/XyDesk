// Kontrak urutan boot — penjaga regresi "aplikasi tidak bisa dibuka".
//
// GEJALA YANG PERNAH TERJADI: aplikasi berhenti di splash native Android
// (logo di atas #FAFAF9) selamanya. Tanpa crash, tanpa galat, tanpa tombol.
//
// SEBAB: `main()` mendaftarkan handler kanal PiP SEBELUM
// `WidgetsFlutterBinding.ensureInitialized()`. `setMethodCallHandler`
// menyentuh binary messenger yang belum ada, jadi ia melempar — di luar
// `runZonedGuarded` dan sebelum `runApp`. Frame pertama tidak pernah
// digambar, dan splash native tidak pernah dilepas.
//
// KENAPA CI TIDAK MENANGKAPNYA: `flutter analyze` tidak menjalankan `main()`,
// dan `flutter test` juga tidak. Build APK sukses karena ini galat runtime,
// bukan galat kompilasi. Satu-satunya jaring yang bisa dipasang tanpa
// perangkat nyata adalah membaca urutan di sumbernya — itulah uji ini.
//
// Uji perilaku boot sungguhan tetap butuh perangkat nyata; catatan itu jujur
// dan tidak diganti oleh uji ini.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:xydesk/core/pip_controller.dart';
import 'package:xydesk/main.dart' show registerPipChannel;

/// Baris pertama (1-based) di [source] yang memuat salah satu [needles].
/// `null` bila tidak ada satu pun.
int? firstLineOf(String source, List<String> needles) {
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    // Komentar boleh menyebut nama apa pun; yang dihitung hanya kode.
    final trimmed = lines[i].trimLeft();
    if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
    if (needles.any(trimmed.contains)) return i + 1;
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('urutan boot di lib/main.dart', () {
    late String source;

    setUpAll(() {
      final file = File('lib/main.dart');
      expect(file.existsSync(), isTrue, reason: 'lib/main.dart harus ada');
      source = file.readAsStringSync();
    });

    /// Isi `void main() { ... }` saja.
    ///
    /// Sengaja dipersempit ke main(): `bootstrap()` juga memanggil
    /// `ensureInitialized()` dan letaknya lebih awal di berkas, jadi
    /// membandingkan "kemunculan pertama di seluruh berkas" akan selalu
    /// lolos — termasuk saat urutannya di main() salah. Uji yang lolos
    /// karena alasan yang salah lebih buruk daripada tidak ada uji.
    String bodyMain() {
      final mulai = source.indexOf('void main()');
      expect(mulai, isNonNegative, reason: 'void main() tidak ditemukan');
      return source.substring(mulai);
    }

    test('binding disiapkan sebelum kanal platform, di dalam main()', () {
      final body = bodyMain();
      final binding = firstLineOf(body, [
        'WidgetsFlutterBinding.ensureInitialized()',
      ]);
      final channel = firstLineOf(body, [
        'registerPipChannel()',
        'setMethodCallHandler',
        'MethodChannel(',
      ]);

      expect(
        binding,
        isNotNull,
        reason:
            'main() sendiri yang wajib menyiapkan binding — jangan '
            'mengandalkan bootstrap() yang dipanggil belakangan',
      );
      expect(
        channel,
        isNotNull,
        reason: 'main() harus mendaftarkan kanal PiP secara eksplisit',
      );
      expect(
        binding! < channel!,
        isTrue,
        reason:
            'Di dalam main(), ensureInitialized() (baris relatif $binding) '
            'HARUS mendahului sentuhan kanal platform pertama (baris relatif '
            '$channel). Kalau terbalik, setMethodCallHandler melempar sebelum '
            'runApp dan aplikasi terkunci di splash native selamanya.',
      );
    });

    test('tidak ada kanal platform di top level berkas', () {
      // Pendaftaran di top level sebuah library berjalan saat import — di luar
      // kendali main(), di luar zona penangkap galat, dan pasti sebelum binding
      // siap. Pernyataan top level Dart selalu di kolom 0, sedangkan isi fungsi
      // selalu menjorok; itu cukup untuk membedakan keduanya tanpa parser.
      for (final line in source.split('\n')) {
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//')) continue;
        if (!trimmed.contains('setMethodCallHandler') &&
            !trimmed.contains('MethodChannel(')) {
          continue;
        }
        expect(
          line.startsWith(' ') || line.startsWith('\t'),
          isTrue,
          reason:
              'Sentuhan kanal platform di kolom 0 = top level, berjalan saat '
              'import sebelum binding siap: "$trimmed"',
        );
      }
    });

    test('pendaftaran kanal dibungkus try/catch', () {
      // PiP fitur opsional. Kegagalannya tidak boleh mencegah frame pertama.
      final fn = source.substring(source.indexOf('void registerPipChannel()'));
      final body = fn.substring(0, fn.indexOf('\nvoid main()'));
      expect(body, contains('try {'));
      expect(body, contains('catch'));
    });
  });

  group('nama kanal PiP', () {
    test('konstanta Dart cocok dengan yang didaftarkan MainActivity.kt', () {
      // Dua bahasa, satu nama. Kalau salah satu diubah tanpa yang lain, PiP
      // gagal diam-diam: invokeMethod balik MissingPluginException dan
      // callback native tidak pernah sampai ke Dart.
      final kotlin = File(
        'android/app/src/main/kotlin/com/xystudio/xydesk/MainActivity.kt',
      );
      expect(kotlin.existsSync(), isTrue, reason: 'MainActivity.kt harus ada');

      final declared = RegExp(r'PIP_CHANNEL\s*=\s*"([^"]+)"')
          .firstMatch(kotlin.readAsStringSync());
      expect(
        declared,
        isNotNull,
        reason: 'PIP_CHANNEL tidak ditemukan di Kotlin',
      );
      expect(declared!.group(1), pipChannelName);
    });
  });

  group('perilaku registerPipChannel', () {
    test('tidak melempar ketika binding sudah siap', () {
      // Ini sisi aman dari invariant di atas: dengan binding siap (kondisi
      // normal setelah perbaikan), pendaftaran harus berjalan bersih.
      expect(registerPipChannel, returnsNormally);
    });

    test('handler memakai perbandingan longgar, bukan cast', () {
      // `call.arguments as bool` akan melempar di dalam handler bila native
      // mengirim null atau tipe lain — dan galat di dalam handler kanal tidak
      // punya jalan keluar yang terlihat pengguna. Sumbernya diperiksa, bukan
      // perilakunya: mengirim pesan platform tiruan ke kanal butuh API uji
      // yang tidak bisa diverifikasi di lingkungan tanpa Flutter, dan uji yang
      // tidak bisa dijalankan penulisnya lebih mungkin merusak CI daripada
      // menjaga apa pun.
      final source = File('lib/main.dart').readAsStringSync();
      final fn = source.substring(source.indexOf('void registerPipChannel()'));
      final body = fn.substring(0, fn.indexOf('\nvoid main()'));
      // Baris komentar dibuang: komentar yang menjelaskan aturan ini menyebut
      // pola terlarangnya secara harfiah, jadi memeriksa teks mentah akan
      // menuduh penjelasannya sendiri.
      final kode = body
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(kode, contains('call.arguments == true'));
      expect(kode, isNot(contains('as bool')));
    });
  });
}
