// Kontrak penyimpanan cuplikan layar sesi.
//
// Cuplikan disimpan per perangkat sebagai PNG ter-encode base64 di
// SharedPreferences. Uji ini mengunci bahwa menyimpan lalu memuat ulang
// menghasilkan byte yang sama, dan bahwa nilai kosong/rusak dibaca sebagai
// null — supaya halaman detail PC tidak menampilkan kotak hitam.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xydesk/core/session_preview.dart';
import 'package:xydesk/core/store.dart';

void main() {
  late Store store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await Store.open();
  });

  test('menyimpan lalu memuat ulang mengembalikan byte yang sama', () async {
    final bytes = Uint8List.fromList(List.generate(64, (i) => i));
    await saveSessionPreview(store, 'dev-1', bytes);
    final loaded = loadSessionPreview(store, 'dev-1');
    expect(loaded, isNotNull);
    expect(loaded!.length, bytes.length);
    expect(loaded, bytes);
  });

  test('cuplikan yang belum pernah ada dibaca sebagai null', () {
    expect(loadSessionPreview(store, 'dev-tak-dikenal'), isNull);
  });

  test('byte kosong tidak disimpan (hindari kotak hitam)', () async {
    await saveSessionPreview(store, 'dev-2', Uint8List(0));
    expect(loadSessionPreview(store, 'dev-2'), isNull);
  });

  test('nilai dalam penyimpanan yang rusak dibaca sebagai null', () async {
    await store.setStr('session_preview_dev-3', '!!!bukan base64!!!');
    expect(loadSessionPreview(store, 'dev-3'), isNull);
  });

  test('cuplikan per perangkat tidak saling menimpa', () async {
    final a = Uint8List.fromList([1, 2, 3]);
    final b = Uint8List.fromList([9, 8, 7]);
    await saveSessionPreview(store, 'dev-A', a);
    await saveSessionPreview(store, 'dev-B', b);
    expect(loadSessionPreview(store, 'dev-A'), a);
    expect(loadSessionPreview(store, 'dev-B'), b);
  });
}
