// Kontrak isolasi data lokal per akun.
//
// Sebelumnya daftar perangkat, riwayat sesi, dan "perangkat terakhir" di
// halaman Connect memakai kunci penyimpanan global (`devices`, `history`,
// `connect_recents`). Akibatnya setelah pengguna keluar lalu masuk akun lain,
// daftar PC milik akun sebelumnya masih tampil — kebocoran data antar akun.
// Sekarang setiap penyimpanan memuat ruang lingkup akun sebagai bagian kunci.
// Uji ini memastikan: data di bawah satu scope tidak bocor ke scope lain.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xydesk/core/store.dart';
import 'package:xydesk/features/devices/device_model.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<Store> store() => Store.open();

  test('perangkat pada scope A tidak tampil di scope B', () async {
    final s = await store();

    final repoA = DeviceRepo(s, 'acct-aaa');
    final repoB = DeviceRepo(s, 'acct-bbb');

    // Tambah perangkat pada scope A.
    await repoA.add(
      const Device(
        id: '123456789',
        name: 'Gaming',
        os: 'Windows 11',
        status: DeviceStatus.offline,
      ),
    );

    expect(repoA.state, hasLength(1));
    expect(repoB.state, isEmpty);

    // Reload scope B dari penyimpanan (kunci berbeda) tetap kosong.
    final repoB2 = DeviceRepo(s, 'acct-bbb');
    expect(repoB2.state, isEmpty);

    repoA.dispose();
    repoB.dispose();
    repoB2.dispose();
  });

  test('riwayat sesi memakai scope sebagai bagian kunci', () async {
    final s = await store();

    final histA = HistoryRepo(s, 'acct-aaa');
    await histA.add(
      SessionRecord(
        deviceId: '123',
        deviceName: 'PC Ku',
        at: DateTime.now(),
        durationMin: 45,
        path: 'P2P',
        quality: '1080p60',
      ),
    );

    final histB = HistoryRepo(s, 'acct-bbb');
    expect(histA.state, hasLength(1));
    expect(histB.state, isEmpty);

    histA.dispose();
    histB.dispose();
  });
}
