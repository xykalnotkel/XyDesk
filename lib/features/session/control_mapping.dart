import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/store.dart';

/// Tipe input yang bisa di-map ke aksi.
enum InputType { keyboard, joystick, mouse, touch }

/// Satu mapping dari input ke aksi.
@immutable
class ControlMapping {
  const ControlMapping({
    required this.id,
    required this.name,
    required this.inputType,
    required this.inputKey,
    required this.action,
    this.description,
  });

  final String id;
  final String name;
  final InputType inputType;
  final String inputKey;
  final String action;
  final String? description;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'inputType': inputType.name,
    'inputKey': inputKey,
    'action': action,
    if (description != null) 'description': description,
  };

  factory ControlMapping.fromJson(Map<String, dynamic> json) => ControlMapping(
    id: json['id'] as String,
    name: json['name'] as String,
    inputType: InputType.values.firstWhere((e) => e.name == json['inputType']),
    inputKey: json['inputKey'] as String,
    action: json['action'] as String,
    description: json['description'] as String?,
  );

  ControlMapping copyWith({
    String? id,
    String? name,
    InputType? inputType,
    String? inputKey,
    String? action,
    String? description,
  }) => ControlMapping(
    id: id ?? this.id,
    name: name ?? this.name,
    inputType: inputType ?? this.inputType,
    inputKey: inputKey ?? this.inputKey,
    action: action ?? this.action,
    description: description ?? this.description,
  );
}

/// Profil control mapping yang bisa disimpan per akun.
@immutable
class ControlProfile {
  const ControlProfile({
    required this.id,
    required this.name,
    required this.mappings,
    this.isDefault = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final List<ControlMapping> mappings;
  final bool isDefault;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mappings': mappings.map((m) => m.toJson()).toList(),
    'isDefault': isDefault,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };

  factory ControlProfile.fromJson(Map<String, dynamic> json) => ControlProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    mappings: (json['mappings'] as List)
        .map((m) => ControlMapping.fromJson(m as Map<String, dynamic>))
        .toList(),
    isDefault: json['isDefault'] as bool? ?? false,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : null,
  );

  ControlProfile copyWith({
    String? id,
    String? name,
    List<ControlMapping>? mappings,
    bool? isDefault,
    DateTime? createdAt,
  }) => ControlProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    mappings: mappings ?? this.mappings,
    isDefault: isDefault ?? this.isDefault,
    createdAt: createdAt ?? this.createdAt,
  );
}

/// Default mappings untuk gaming (WASD + mouse).
final _defaultGamingProfile = ControlProfile(
  id: 'default-gaming',
  name: 'Gaming Default',
  isDefault: true,
  createdAt: DateTime.now(),
  mappings: const [
    // Movement
    ControlMapping(
      id: 'move-forward',
      name: 'Maju',
      inputType: InputType.keyboard,
      inputKey: 'W',
      action: 'move_forward',
      description: 'Gerak ke depan',
    ),
    ControlMapping(
      id: 'move-backward',
      name: 'Mundur',
      inputType: InputType.keyboard,
      inputKey: 'S',
      action: 'move_backward',
      description: 'Gerak ke belakang',
    ),
    ControlMapping(
      id: 'move-left',
      name: 'Kiri',
      inputType: InputType.keyboard,
      inputKey: 'A',
      action: 'move_left',
      description: 'Gerak ke kiri',
    ),
    ControlMapping(
      id: 'move-right',
      name: 'Kanan',
      inputType: InputType.keyboard,
      inputKey: 'D',
      action: 'move_right',
      description: 'Gerak ke kanan',
    ),
    // Actions
    ControlMapping(
      id: 'jump',
      name: 'Lompat',
      inputType: InputType.keyboard,
      inputKey: 'Space',
      action: 'jump',
      description: 'Lompat / meloncat',
    ),
    ControlMapping(
      id: 'crouch',
      name: 'Jongkok',
      inputType: InputType.keyboard,
      inputKey: 'Ctrl',
      action: 'crouch',
      description: 'Jongkok / merunduk',
    ),
    ControlMapping(
      id: 'sprint',
      name: 'Lari',
      inputType: InputType.keyboard,
      inputKey: 'Shift',
      action: 'sprint',
      description: 'Lari cepat',
    ),
    // Mouse
    ControlMapping(
      id: 'shoot',
      name: 'Tembak',
      inputType: InputType.mouse,
      inputKey: 'LeftClick',
      action: 'shoot',
      description: 'Tembak / aksi utama',
    ),
    ControlMapping(
      id: 'aim',
      name: 'Bidik',
      inputType: InputType.mouse,
      inputKey: 'RightClick',
      action: 'aim',
      description: 'Bidik / ADS',
    ),
    ControlMapping(
      id: 'reload',
      name: 'Reload',
      inputType: InputType.keyboard,
      inputKey: 'R',
      action: 'reload',
      description: 'Isi ulang peluru',
    ),
    // Utility
    ControlMapping(
      id: 'interact',
      name: 'Interaksi',
      inputType: InputType.keyboard,
      inputKey: 'E',
      action: 'interact',
      description: 'Interaksi dengan objek',
    ),
    ControlMapping(
      id: 'inventory',
      name: 'Inventory',
      inputType: InputType.keyboard,
      inputKey: 'Tab',
      action: 'inventory',
      description: 'Buka inventory',
    ),
    ControlMapping(
      id: 'map',
      name: 'Peta',
      inputType: InputType.keyboard,
      inputKey: 'M',
      action: 'map',
      description: 'Buka peta',
    ),
  ],
);

/// Default mappings untuk desktop (produktivitas).
final _defaultDesktopProfile = ControlProfile(
  id: 'default-desktop',
  name: 'Desktop Default',
  isDefault: true,
  createdAt: DateTime.now(),
  mappings: const [
    ControlMapping(
      id: 'copy',
      name: 'Salin',
      inputType: InputType.keyboard,
      inputKey: 'Ctrl+C',
      action: 'copy',
      description: 'Salin teks/objek',
    ),
    ControlMapping(
      id: 'paste',
      name: 'Tempel',
      inputType: InputType.keyboard,
      inputKey: 'Ctrl+V',
      action: 'paste',
      description: 'Tempel dari clipboard',
    ),
    ControlMapping(
      id: 'cut',
      name: 'Potong',
      inputType: InputType.keyboard,
      inputKey: 'Ctrl+X',
      action: 'cut',
      description: 'Potong teks/objek',
    ),
    ControlMapping(
      id: 'undo',
      name: 'Undo',
      inputType: InputType.keyboard,
      inputKey: 'Ctrl+Z',
      action: 'undo',
      description: 'Batalkan aksi',
    ),
    ControlMapping(
      id: 'redo',
      name: 'Redo',
      inputType: InputType.keyboard,
      inputKey: 'Ctrl+Y',
      action: 'redo',
      description: 'Ulangi aksi',
    ),
    ControlMapping(
      id: 'save',
      name: 'Simpan',
      inputType: InputType.keyboard,
      inputKey: 'Ctrl+S',
      action: 'save',
      description: 'Simpan file',
    ),
    ControlMapping(
      id: 'select-all',
      name: 'Pilih Semua',
      inputType: InputType.keyboard,
      inputKey: 'Ctrl+A',
      action: 'select_all',
      description: 'Pilih semua',
    ),
    ControlMapping(
      id: 'new-tab',
      name: 'Tab Baru',
      inputType: InputType.keyboard,
      inputKey: 'Ctrl+T',
      action: 'new_tab',
      description: 'Buka tab baru',
    ),
    ControlMapping(
      id: 'close-tab',
      name: 'Tutup Tab',
      inputType: InputType.keyboard,
      inputKey: 'Ctrl+W',
      action: 'close_tab',
      description: 'Tutup tab aktif',
    ),
  ],
);

/// Manager untuk control mapping per akun.
class ControlMappingManager extends StateNotifier<List<ControlProfile>> {
  ControlMappingManager(this._store, this._scope) : super([]) {
    _load();
  }

  final Store _store;
  final String _scope;

  String get _key => 'control_profiles:$_scope';

  void _load() {
    final raw = _store.getStr(_key);
    if (raw == null || raw.isEmpty) {
      // Pakai default profiles
      state = [_defaultGamingProfile, _defaultDesktopProfile];
      return;
    }
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => ControlProfile.fromJson(e as Map<String, dynamic>))
          .toList();
      state = list;
    } catch (e) {
      state = [_defaultGamingProfile, _defaultDesktopProfile];
    }
  }

  Future<void> _save() async {
    final json = state.map((p) => p.toJson()).toList();
    await _store.setStr(_key, jsonEncode(json));
  }

  Future<void> addProfile(ControlProfile profile) async {
    state = [...state, profile];
    await _save();
  }

  Future<void> updateProfile(ControlProfile profile) async {
    state = [
      for (final p in state)
        if (p.id == profile.id) profile else p,
    ];
    await _save();
  }

  Future<void> deleteProfile(String profileId) async {
    state = state.where((p) => p.id != profileId).toList();
    await _save();
  }

  Future<void> setDefault(String profileId) async {
    state = [for (final p in state) p.copyWith(isDefault: p.id == profileId)];
    await _save();
  }

  ControlProfile? get defaultProfile {
    for (final p in state) {
      if (p.isDefault) return p;
    }
    return state.isNotEmpty ? state.first : null;
  }

  Future<void> resetToDefaults() async {
    state = [_defaultGamingProfile, _defaultDesktopProfile];
    await _save();
  }
}

final controlMappingManagerProvider =
    StateNotifierProvider.autoDispose<
      ControlMappingManager,
      List<ControlProfile>
    >((ref) {
      final store = ref.watch(storeProvider);
      final scope = ref.watch(accountScopeProvider);
      return ControlMappingManager(store, scope);
    });
