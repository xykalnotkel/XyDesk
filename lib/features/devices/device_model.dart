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
    this.resolution = '1920×1080',
    this.remembered = false,
  });

  final String id;
  final String name;
  final String os;
  final String? gpu;
  final DeviceStatus status;
  final int? pingMs;
  final DateTime? lastSeen;
  final String resolution;
  final bool remembered;

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
  }) =>
      Device(
        id: id,
        name: name ?? this.name,
        os: os,
        gpu: gpu,
        status: status ?? this.status,
        pingMs: pingMs ?? this.pingMs,
        lastSeen: lastSeen ?? this.lastSeen,
        resolution: resolution,
        remembered: remembered ?? this.remembered,
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
        resolution: j['res'] as String? ?? '1920×1080',
        remembered: j['remembered'] as bool? ?? false,
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
class DeviceRepo extends StateNotifier<List<Device>> {
  DeviceRepo(this._s) : super(const []) {
    _load();
  }

  final Store _s;
  static const _key = 'devices';

  void _load() {
    final raw = _s.getList(_key);
    if (raw.isEmpty) {
      // Contoh awal supaya aplikasi tidak terasa kosong saat pertama dibuka.
      state = _seed;
      _persist();
      DevLog.i('devices', 'Memakai daftar contoh', '${_seed.length} perangkat');
    } else {
      state = raw.map(Device.fromJson).toList();
      DevLog.i(
          'devices', 'Dimuat dari penyimpanan', '${state.length} perangkat');
    }
  }

  static final _seed = <Device>[
    Device(
      id: '123456789',
      name: 'GAMING-RIG',
      os: 'Windows 11',
      gpu: 'RTX 4070',
      status: DeviceStatus.online,
      pingMs: 24,
      lastSeen: DateTime.now(),
      resolution: '2560×1440',
      remembered: true,
    ),
    Device(
      id: '234567890',
      name: 'LAPTOP-ASUS',
      os: 'Ubuntu 24.04',
      gpu: 'Iris Xe',
      status: DeviceStatus.online,
      pingMs: 18,
      lastSeen: DateTime.now(),
    ),
    Device(
      id: '345678901',
      name: 'OFFICE-PC',
      os: 'Windows 10',
      status: DeviceStatus.offline,
      lastSeen: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    Device(
      id: '456789012',
      name: 'MAC-STUDIO',
      os: 'macOS 15',
      gpu: 'M2 Max',
      status: DeviceStatus.busy,
      pingMs: 72,
      lastSeen: DateTime.now(),
      resolution: '3024×1964',
    ),
  ];

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

  Future<void> rename(String id, String name) async {
    state = [
      for (final d in state)
        if (d.id == id) d.copyWith(name: name) else d
    ];
    await _persist();
    DevLog.i('devices', 'Perangkat diganti nama', '$id -> $name');
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

final deviceRepoProvider =
    StateNotifierProvider<DeviceRepo, List<Device>>((ref) {
  return DeviceRepo(ref.watch(storeProvider));
});

/// Riwayat sesi.
class HistoryRepo extends StateNotifier<List<SessionRecord>> {
  HistoryRepo(this._s) : super(const []) {
    state = _s.getList(_key).map(SessionRecord.fromJson).toList();
  }

  final Store _s;
  static const _key = 'history';

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

final historyProvider =
    StateNotifierProvider<HistoryRepo, List<SessionRecord>>((ref) {
  return HistoryRepo(ref.watch(storeProvider));
});
