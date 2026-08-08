import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
//  Pengaturan aplikasi
// ══════════════════════════════════════════════════════════

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.langCode = 'id',
    this.haptics = true,
    this.highRefresh = true,
    this.showDevLog = true,
    this.reduceMotion = false,
  });

  final ThemeMode themeMode;
  final String langCode;
  final bool haptics;
  final bool highRefresh;
  final bool showDevLog;
  final bool reduceMotion;

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? langCode,
    bool? haptics,
    bool? highRefresh,
    bool? showDevLog,
    bool? reduceMotion,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    langCode: langCode ?? this.langCode,
    haptics: haptics ?? this.haptics,
    highRefresh: highRefresh ?? this.highRefresh,
    showDevLog: showDevLog ?? this.showDevLog,
    reduceMotion: reduceMotion ?? this.reduceMotion,
  );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._s) : super(const AppSettings()) {
    _load();
  }

  final Store _s;

  void _load() {
    state = AppSettings(
      themeMode: ThemeMode.values[_s.getI('theme', def: ThemeMode.dark.index)],
      langCode: _s.getStr('lang') ?? 'id',
      haptics: _s.getBool('haptics', def: true),
      highRefresh: _s.getBool('high_refresh', def: true),
      showDevLog: _s.getBool('show_devlog', def: true),
      reduceMotion: _s.getBool('reduce_motion'),
    );
    DevLog.i(
      'settings',
      'Dimuat',
      'tema=${state.themeMode.name} bahasa=${state.langCode}',
    );
  }

  Future<void> setTheme(ThemeMode m) async {
    state = state.copyWith(themeMode: m);
    await _s.setI('theme', m.index);
    DevLog.i('settings', 'Tema diubah', m.name);
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
  const UserSession({this.email, this.name, this.isGuest = false});

  final String? email;
  final String? name;
  final bool isGuest;

  bool get signedIn => email != null || isGuest;

  String get initial {
    if (name != null && name!.isNotEmpty) return name![0].toUpperCase();
    if (email != null && email!.isNotEmpty) return email![0].toUpperCase();
    return '?';
  }
}

class AuthNotifier extends StateNotifier<UserSession> {
  AuthNotifier(this._s) : super(const UserSession()) {
    final email = _s.getStr('user_email');
    final guest = _s.getBool('user_guest');
    if (email != null || guest) {
      state = UserSession(
        email: email,
        name: _s.getStr('user_name'),
        isGuest: guest,
      );
      DevLog.i('auth', 'Sesi dipulihkan', email ?? 'tamu');
    }
  }

  final Store _s;

  Future<void> signInEmail(String email, {String? name}) async {
    state = UserSession(email: email, name: name);
    await _s.setStr('user_email', email);
    if (name != null) await _s.setStr('user_name', name);
    await _s.setBool('user_guest', false);
    DevLog.ok('auth', 'Masuk dengan email', email);
  }

  Future<void> signInGuest() async {
    state = const UserSession(isGuest: true);
    await _s.setBool('user_guest', true);
    DevLog.ok('auth', 'Masuk sebagai tamu');
  }

  Future<void> signOut() async {
    state = const UserSession();
    await _s.remove('user_email');
    await _s.remove('user_name');
    await _s.setBool('user_guest', false);
    DevLog.i('auth', 'Keluar');
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, UserSession>((ref) {
  return AuthNotifier(ref.watch(storeProvider));
});
