import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/devlog.dart';
import '../../core/store.dart';

/// Status koneksi sebuah PC host.
enum DeviceStatus { online, offline, busy }

@immutable
class Device {
  const Device({
    required this.id,
    required this.name,
    required this.os,
    this.gpu,
    this.status = DeviceStatus.offline,
    this.pingMs,
    this.lastSeen,
    this.resolution,
    this.remembered = false,
    this.motherboard,
    this.cpu,
    this.ram,
    this.displays = const [],
    this.storage,
  });

  final String id;
  final String name;
  final String os;
  final String? gpu;
  final DeviceStatus status;
  final int? pingMs;
  final DateTime? lastSeen;

  /// Resolusi monitor utama **menurut host**. Null = host belum pernah
  /// melaporkannya. Sengaja tidak punya default: nilai bawaan '1920×1080'
  /// membuat layar detail mengklaim resolusi yang tidak pernah dibaca dari
  /// mesin mana pun, dan `copyWith` lama menyalinnya tanpa bisa dikoreksi.
  final String? resolution;
  final bool remembered;

  /// Info hardware tambahan — dibaca dari host saat sesi.
  final String? motherboard;
  final String? cpu;
  final String? ram;
  final List<DisplayInfo> displays;
  final String? storage;

  bool get isOnline => status == DeviceStatus.online;

  /// ID diformat "123 456 789" agar mudah dibaca.
  String get prettyId {
    final d = id.replaceAll(RegExp(r'\D'), '');
    if (d.length != 9) return id;
    return '${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}';
  }

  Device copyWith({
    String? name,
    DeviceStatus? status,
    int? pingMs,
    DateTime? lastSeen,
    bool? remembered,
    String? motherboard,
    String? cpu,
    String? gpu,
    String? ram,
    List<DisplayInfo>? displays,
    String? storage,
    String? resolution,
  }) => Device(
    id: id,
    name: name ?? this.name,
    os: os,
    gpu: gpu ?? this.gpu,
    status: status ?? this.status,
    pingMs: pingMs ?? this.pingMs,
    lastSeen: lastSeen ?? this.lastSeen,
    resolution: resolution ?? this.resolution,
    remembered: remembered ?? this.remembered,
    motherboard: motherboard ?? this.motherboard,
    cpu: cpu ?? this.cpu,
    ram: ram ?? this.ram,
    displays: displays ?? this.displays,
    storage: storage ?? this.storage,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'os': os,
    'gpu': gpu,
    'status': status.name,
    'ping': pingMs,
    'lastSeen': lastSeen?.toIso8601String(),
    'res': resolution,
    'remembered': remembered,
    'motherboard': motherboard,
    'cpu': cpu,
    'ram': ram,
    'displays': displays.map((d) => d.toJson()).toList(),
    'storage': storage,
  };

  factory Device.fromJson(Map<String, dynamic> j) => Device(
    id: j['id'] as String,
    name: j['name'] as String,
    os: j['os'] as String? ?? '',
    gpu: j['gpu'] as String?,
    status: DeviceStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => DeviceStatus.offline,
    ),
    pingMs: j['ping'] as int?,
    lastSeen: j['lastSeen'] == null
        ? null
        : DateTime.tryParse(j['lastSeen'] as String),
    resolution: j['res'] as String?,
    remembered: j['remembered'] as bool? ?? false,
    motherboard: j['motherboard'] as String?,
    cpu: j['cpu'] as String?,
    ram: j['ram'] as String?,
    displays:
        (j['displays'] as List?)
            ?.map((d) => DisplayInfo.fromJson(d as Map<String, dynamic>))
            .toList() ??
        [],
    storage: j['storage'] as String?,
  );
}

/// Catatan satu sesi, untuk halaman Riwayat.
@immutable
class SessionRecord {
  const SessionRecord({
    required this.deviceId,
    required this.deviceName,
    required this.at,
    required this.durationMin,
    required this.path,
    required this.quality,
  });

  final String deviceId;
  final String deviceName;
  final DateTime at;
  final int durationMin;
  final String path; // 'P2P' atau 'Relay'
  final String quality;

  Map<String, dynamic> toJson() => {
    'id': deviceId,
    'name': deviceName,
    'at': at.toIso8601String(),
    'dur': durationMin,
    'path': path,
    'q': quality,
  };

  factory SessionRecord.fromJson(Map<String, dynamic> j) => SessionRecord(
    deviceId: j['id'] as String,
    deviceName: j['name'] as String,
    at: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
    durationMin: j['dur'] as int? ?? 0,
    path: j['path'] as String? ?? 'P2P',
    quality: j['q'] as String? ?? '1080p60',
  );
}

/// Daftar perangkat yang tersimpan di HP.
///
/// Kunci penyimpanan memuat [scope] (per akun) supaya daftar PC yang pernah
/// disambungkan tidak bocor antar akun setelah pengguna keluar/masuk lagi.
class DeviceRepo extends StateNotifier<List<Device>> {
  DeviceRepo(this._s, this._scope) : super(const []) {
    _load();
  }

  final Store _s;

  /// Ruang lingkup akun (dari [accountScopeProvider]; 'guest' untuk tamu).
  final String _scope;
  String get _key => 'devices:$_scope';

  /// Muat ulang daftar dari penyimpanan — dipakai pull-to-refresh Beranda.
  void reloadFromStore() => _load();

  void _load() {
    final raw = _s.getList(_key);
    if (raw.isEmpty) {
      // Daftar kosong = memang belum ada perangkat.
      //
      // Sebelumnya di sini diisi empat perangkat contoh berstatus "online"
      // (GAMING-RIG RTX 4090, dst) lalu LANGSUNG DISIMPAN ke penyimpanan.
      // Akibatnya user baru melihat perangkat yang tidak mereka miliki,
      // mencoba menyambung, dan gagal tanpa penjelasan. UI menampilkan
      // empty state yang mengarahkan user menambah perangkat.
      state = const [];
      DevLog.i('devices', 'Belum ada perangkat tersimpan', '0 perangkat');
    } else {
      state = raw.map(Device.fromJson).toList();
      DevLog.i(
        'devices',
        'Dimuat dari penyimpanan',
        '${state.length} perangkat',
      );
    }
  }

  Future<void> _persist() =>
      _s.setList(_key, state.map((d) => d.toJson()).toList());

  Future<void> add(Device d) async {
    if (state.any((x) => x.id == d.id)) {
      DevLog.w('devices', 'Perangkat sudah ada', d.id);
      return;
    }
    state = [...state, d];
    await _persist();
    DevLog.ok('devices', 'Perangkat ditambahkan', d.name);
  }

  /// Simulasi pairing lokal: perangkat baru disimpan, perangkat lama
  /// diperbarui menjadi online. Nanti method ini bisa diganti repository API
  /// tanpa mengubah layar Connect.
  Future<Device> connect({
    required String id,
    required String name,
    bool remembered = false,
  }) async {
    final current = byId(id);
    final connected =
        (current ??
                Device(
                  id: id,
                  name: name,
                  os: 'Windows 11',
                  status: DeviceStatus.offline,
                ))
            .copyWith(
              status: DeviceStatus.online,
              pingMs: 24,
              lastSeen: DateTime.now(),
              remembered: remembered || (current?.remembered ?? false),
            );

    state = [
      for (final d in state)
        if (d.id == id) connected else d,
      if (current == null) connected,
    ];
    await _persist();
    DevLog.ok('devices', 'Perangkat disimpan ke riwayat', connected.name);
    return connected;
  }

  Future<void> rename(String id, String name) async {
    state = [
      for (final d in state)
        if (d.id == id) d.copyWith(name: name) else d,
    ];
    await _persist();
    DevLog.i('devices', 'Perangkat diganti nama', '$id -> $name');
  }

  /// Update hardware info perangkat (motherboard, CPU, GPU, RAM, storage,
  /// displays, resolusi monitor utama). Dipanggil saat sesi dimulai dan host
  /// mengirim meta data. Semua nilai berasal dari host — tidak ada yang
  /// disintesis di client.
  Future<void> updateHardwareInfo(
    String id, {
    String? resolution,
    String? motherboard,
    String? cpu,
    String? gpu,
    String? ram,
    String? storage,
    List<DisplayInfo>? displays,
  }) async {
    final current = byId(id);
    if (current == null) {
      DevLog.w(
        'devices',
        'Perangkat tidak ditemukan untuk update hardware',
        id,
      );
      return;
    }

    final updated = current.copyWith(
      resolution: resolution ?? current.resolution,
      motherboard: motherboard ?? current.motherboard,
      cpu: cpu ?? current.cpu,
      gpu: gpu ?? current.gpu,
      ram: ram ?? current.ram,
      storage: storage ?? current.storage,
      displays: displays ?? current.displays,
    );

    state = [
      for (final d in state)
        if (d.id == id) updated else d,
    ];
    await _persist();
    DevLog.i('devices', 'Hardware info diupdate', id);
  }

  Future<void> remove(String id) async {
    state = state.where((d) => d.id != id).toList();
    await _persist();
    DevLog.i('devices', 'Perangkat dihapus', id);
  }

  Device? byId(String id) {
    for (final d in state) {
      if (d.id == id) return d;
    }
    return null;
  }
}

final deviceRepoProvider = StateNotifierProvider<DeviceRepo, List<Device>>((
  ref,
) {
  // Scope ikut sesi: ganti akun membuat repo dibangun ulang dengan kunci yang
  // sesuai, sehingga daftar perangkat tidak bocor antar akun.
  final store = ref.watch(storeProvider);
  final scope = ref.watch(accountScopeProvider);
  return DeviceRepo(store, scope);
});

/// Info display host — dipakai untuk menampilkan monitor yang tersambung.
@immutable
class DisplayInfo {
  const DisplayInfo({
    required this.index,
    required this.name,
    required this.width,
    required this.height,
    this.refreshRate,
    this.isPrimary = false,
  });

  final int index;
  final String name;
  final int width;
  final int height;
  final int? refreshRate;
  final bool isPrimary;

  String get resolution => '$width×$height';
  String get refreshRateLabel => refreshRate != null ? '$refreshRate Hz' : '';

  Map<String, dynamic> toJson() => {
    'index': index,
    'name': name,
    'width': width,
    'height': height,
    'refreshRate': refreshRate,
    'isPrimary': isPrimary,
  };

  factory DisplayInfo.fromJson(Map<String, dynamic> j) => DisplayInfo(
    index: j['index'] as int? ?? 0,
    name: j['name'] as String? ?? 'Monitor ${((j['index'] as int? ?? 0) + 1)}',
    width: j['width'] as int? ?? 0,
    height: j['height'] as int? ?? 0,
    refreshRate: j['refreshRate'] as int?,
    isPrimary: j['isPrimary'] as bool? ?? false,
  );
}

/// Riwayat sesi.
///
/// Kunci penyimpanan memuat [scope] (per akun) — sama dengan daftar perangkat
/// — sehingga riwayat sesi milik akun A tidak tampil pada akun B.
class HistoryRepo extends StateNotifier<List<SessionRecord>> {
  HistoryRepo(this._s, this._scope) : super(const []) {
    state = _s.getList(_key).map(SessionRecord.fromJson).toList();
  }

  final Store _s;

  /// Ruang lingkup akun (dari [accountScopeProvider]; 'guest' untuk tamu).
  final String _scope;
  String get _key => 'history:$_scope';

  Future<void> add(SessionRecord r) async {
    state = [r, ...state].take(50).toList();
    await _s.setList(_key, state.map((e) => e.toJson()).toList());
    DevLog.i('history', 'Sesi dicatat', '${r.deviceName} ${r.durationMin}m');
  }

  Future<void> clear() async {
    state = [];
    await _s.remove(_key);
    DevLog.i('history', 'Riwayat dibersihkan');
  }
}

final historyProvider = StateNotifierProvider<HistoryRepo, List<SessionRecord>>(
  (ref) {
    final store = ref.watch(storeProvider);
    final scope = ref.watch(accountScopeProvider);
    return HistoryRepo(store, scope);
  },
);
