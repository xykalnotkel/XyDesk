import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/session_vault.dart';
import 'devlog.dart';
import 'l10n_bridge.dart';

/// Penyimpanan lokal sederhana di atas SharedPreferences.
///
/// Dipakai agar pengaturan, daftar perangkat, riwayat, dan profil kontrol
/// benar-benar bertahan setelah aplikasi ditutup — bukan sekadar demo.
class Store {
  Store(this._p);

  final SharedPreferences _p;

  static Future<Store> open() async {
    final p = await SharedPreferences.getInstance();
    DevLog.ok('store', 'Penyimpanan lokal siap', '${p.getKeys().length} kunci');
    return Store(p);
  }

  // ── primitif ──
  String? getStr(String k) => _p.getString(k);
  Future<void> setStr(String k, String v) => _p.setString(k, v);
  bool getBool(String k, {bool def = false}) => _p.getBool(k) ?? def;
  Future<void> setBool(String k, bool v) => _p.setBool(k, v);
  double getD(String k, {double def = 0}) => _p.getDouble(k) ?? def;
  Future<void> setD(String k, double v) => _p.setDouble(k, v);
  int getI(String k, {int def = 0}) => _p.getInt(k) ?? def;
  Future<void> setI(String k, int v) => _p.setInt(k, v);
  Future<void> remove(String k) => _p.remove(k);

  List<Map<String, dynamic>> getList(String k) {
    final raw = _p.getString(k);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (e, s) {
      DevLog.e('store', 'Gagal membaca $k', e, s);
      return [];
    }
  }

  Future<void> setList(String k, List<Map<String, dynamic>> v) =>
      _p.setString(k, jsonEncode(v));

  Future<void> clearAll() async {
    await _p.clear();
    DevLog.w('store', 'Semua data lokal dihapus');
  }
}

/// Disediakan di `main()` setelah Store terbuka.
final storeProvider = Provider<Store>((_) => throw UnimplementedError());

// ══════════════════════════════════════════════════════════
//  Pengaturan aplikasi (termasuk Mesin Streaming & Kualitas Audio/Video)
// ══════════════════════════════════════════════════════════

@immutable
class AppSettings {
  const AppSettings({
    this.langCode = 'id',
    this.haptics = true,
    this.highRefresh = true,
    this.showDevLog = true,
    this.reduceMotion = false,
    this.codec = 'AV1 (NVENC / AMF GPU)',
    this.resolution = '1080p60 (FHD)',
    this.bitrateMbps = 25,
    this.relativeMouseMode = false,
    this.audioEnabled = true,
    this.micPassthrough = false,
    this.clipboardSync = true,
  });

  final String langCode;
  final bool haptics;
  final bool highRefresh;
  final bool showDevLog;
  final bool reduceMotion;
  final String codec;
  final String resolution;
  final int bitrateMbps;
  final bool relativeMouseMode;
  final bool audioEnabled;
  final bool micPassthrough;
  final bool clipboardSync;

  AppSettings copyWith({
    String? langCode,
    bool? haptics,
    bool? highRefresh,
    bool? showDevLog,
    bool? reduceMotion,
    String? codec,
    String? resolution,
    int? bitrateMbps,
    bool? relativeMouseMode,
    bool? audioEnabled,
    bool? micPassthrough,
    bool? clipboardSync,
  }) => AppSettings(
    langCode: langCode ?? this.langCode,
    haptics: haptics ?? this.haptics,
    highRefresh: highRefresh ?? this.highRefresh,
    showDevLog: showDevLog ?? this.showDevLog,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    codec: codec ?? this.codec,
    resolution: resolution ?? this.resolution,
    bitrateMbps: bitrateMbps ?? this.bitrateMbps,
    relativeMouseMode: relativeMouseMode ?? this.relativeMouseMode,
    audioEnabled: audioEnabled ?? this.audioEnabled,
    micPassthrough: micPassthrough ?? this.micPassthrough,
    clipboardSync: clipboardSync ?? this.clipboardSync,
  );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._s) : super(const AppSettings()) {
    _load();
  }

  final Store _s;

  void _load() {
    state = AppSettings(
      langCode: _s.getStr('lang') ?? 'id',
      haptics: _s.getBool('haptics', def: true),
      highRefresh: _s.getBool('high_refresh', def: true),
      showDevLog: _s.getBool('show_devlog', def: true),
      reduceMotion: _s.getBool('reduce_motion'),
      codec: _s.getStr('stream_codec') ?? 'AV1 (NVENC / AMF GPU)',
      resolution: _s.getStr('stream_res') ?? '1080p60 (FHD)',
      bitrateMbps: _s.getI('stream_bitrate', def: 25),
      relativeMouseMode: _s.getBool('stream_relative_mouse', def: false),
      audioEnabled: _s.getBool('stream_audio', def: true),
      micPassthrough: _s.getBool('stream_mic', def: false),
      clipboardSync: _s.getBool('stream_clipboard', def: true),
    );
    DevLog.i(
      'settings',
      'Dimuat',
      'bahasa=${state.langCode} codec=${state.codec}',
    );
  }

  Future<void> setLang(String code) async {
    state = state.copyWith(langCode: code);
    await _s.setStr('lang', code);
    DevLog.i('settings', 'Bahasa diubah', code);
  }

  Future<void> setHaptics(bool v) async {
    state = state.copyWith(haptics: v);
    await _s.setBool('haptics', v);
  }

  Future<void> setHighRefresh(bool v) async {
    state = state.copyWith(highRefresh: v);
    await _s.setBool('high_refresh', v);
  }

  Future<void> setShowDevLog(bool v) async {
    state = state.copyWith(showDevLog: v);
    await _s.setBool('show_devlog', v);
  }

  Future<void> setReduceMotion(bool v) async {
    state = state.copyWith(reduceMotion: v);
    await _s.setBool('reduce_motion', v);
  }

  Future<void> setCodec(String c) async {
    state = state.copyWith(codec: c);
    await _s.setStr('stream_codec', c);
    DevLog.i('settings', 'Codec diubah', c);
  }

  Future<void> setResolution(String r) async {
    state = state.copyWith(resolution: r);
    await _s.setStr('stream_res', r);
    DevLog.i('settings', 'Resolusi diubah', r);
  }

  Future<void> setBitrateMbps(int b) async {
    state = state.copyWith(bitrateMbps: b);
    await _s.setI('stream_bitrate', b);
    DevLog.i('settings', 'Bitrate diubah', '$b Mbps');
  }

  Future<void> setRelativeMouseMode(bool v) async {
    state = state.copyWith(relativeMouseMode: v);
    await _s.setBool('stream_relative_mouse', v);
    DevLog.i('settings', 'Relative mouse', '$v');
  }

  Future<void> setAudioEnabled(bool v) async {
    state = state.copyWith(audioEnabled: v);
    await _s.setBool('stream_audio', v);
  }

  Future<void> setMicPassthrough(bool v) async {
    state = state.copyWith(micPassthrough: v);
    await _s.setBool('stream_mic', v);
  }

  Future<void> setClipboardSync(bool v) async {
    state = state.copyWith(clipboardSync: v);
    await _s.setBool('stream_clipboard', v);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  return SettingsNotifier(ref.watch(storeProvider));
});

/// Bahasa aktif, diturunkan dari pengaturan.
final langProvider = Provider<AppLang>((ref) {
  return AppLang.byCode(ref.watch(settingsProvider).langCode);
});

// ══════════════════════════════════════════════════════════
//  Sesi pengguna
// ══════════════════════════════════════════════════════════

@immutable
class UserSession {
  const UserSession({
    this.email,
    this.name,
    this.picture,
    this.token,
    this.isGuest = false,
  });

  final String? email;
  final String? name;

  /// URL foto profil (dari Google), null bila tidak ada.
  final String? picture;

  /// JWT sesi backend. Tidak pernah ditulis ke SharedPreferences/log.
  final String? token;
  final bool isGuest;

  bool get signedIn => isGuest || (email != null && token != null);

  String get initial {
    if (name != null && name!.isNotEmpty) return name![0].toUpperCase();
    if (email != null && email!.isNotEmpty) return email![0].toUpperCase();
    return '?';
  }
}

class AuthNotifier extends StateNotifier<UserSession> {
  AuthNotifier(
    this._s, {
    this.initialToken,
    SessionVault vault = const NoopSessionVault(),
  }) : _vault = vault,
       super(const UserSession()) {
    final email = _s.getStr('user_email');
    final guest = _s.getBool('user_guest');
    if (guest) {
      state = const UserSession(isGuest: true);
      DevLog.i('auth', 'Sesi dipulihkan', 'tamu');
    } else if (initialToken != null) {
      // Email hanyalah cache metadata. JWT secure storage adalah sumber sesi;
      // `/auth/me` akan memulihkan profil bila cache SharedPreferences hilang.
      state = UserSession(
        email: email,
        name: _s.getStr('user_name'),
        picture: _s.getStr('user_picture'),
        token: initialToken,
      );
      DevLog.i('auth', 'JWT backend dipulihkan', email ?? 'menunggu profil');
    } else if (email != null) {
      // Versi lama hanya menyimpan email tanpa JWT. Jangan mempercayai sesi
      // lokal tersebut; bersihkan agar pengguna melakukan auth asli.
      _s.remove('user_email');
      _s.remove('user_name');
      DevLog.w('auth', 'Sesi lokal lama dibuang', 'JWT tidak ditemukan');
    }
  }

  final Store _s;
  final SessionVault _vault;
  final String? initialToken;

  Future<void> signInAuthenticated({
    required String email,
    required String token,
    String? name,
    String? picture,
  }) async {
    // Simpan token lebih dahulu; jangan buka shell bila secure storage gagal.
    await _vault.writeToken(token);
    await _s.setStr('user_email', email);
    if (name != null) {
      await _s.setStr('user_name', name);
    } else {
      await _s.remove('user_name');
    }
    if (picture != null) {
      await _s.setStr('user_picture', picture);
    } else {
      await _s.remove('user_picture');
    }
    await _s.setBool('user_guest', false);
    state = UserSession(
      email: email,
      name: name,
      picture: picture,
      token: token,
    );
    DevLog.ok('auth', 'Sesi backend aktif', email);
  }

  /// Memperbarui metadata dari `/auth/me` tanpa menulis ulang JWT.
  Future<void> refreshAuthenticatedProfile({
    required String email,
    String? name,
    String? picture,
  }) async {
    final token = state.token;
    if (token == null) return;
    await _s.setStr('user_email', email);
    if (name != null) {
      await _s.setStr('user_name', name);
    } else {
      await _s.remove('user_name');
    }
    if (picture != null) {
      await _s.setStr('user_picture', picture);
    } else {
      await _s.remove('user_picture');
    }
    await _s.setBool('user_guest', false);
    state = UserSession(
      email: email,
      name: name,
      picture: picture,
      token: token,
    );
  }

  Future<void> signInGuest() async {
    await _vault.deleteToken();
    await _s.remove('user_email');
    await _s.remove('user_name');
    await _s.remove('user_picture');
    await _s.setBool('user_guest', true);
    state = const UserSession(isGuest: true);
    DevLog.ok('auth', 'Masuk sebagai tamu');
  }

  Future<void> signOut() async {
    await _vault.deleteToken();
    await _s.remove('user_email');
    await _s.remove('user_name');
    await _s.remove('user_picture');
    await _s.setBool('user_guest', false);
    state = const UserSession();
    DevLog.i('auth', 'Keluar');
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, UserSession>((ref) {
  return AuthNotifier(
    ref.watch(storeProvider),
    initialToken: ref.watch(initialAuthTokenProvider),
    vault: ref.watch(sessionVaultProvider),
  );
});
