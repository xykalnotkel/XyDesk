import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/devlog.dart';
import '../../core/store.dart';
import 'app_update_details.dart';
import 'notification_config.dart';
import 'update_page.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

typedef NewsNavigationCallback = void Function(String articleId, String slug);

/// Bridge Dart ke OneSignal Android SDK native.
///
/// Flutter tetap menjadi UI/UX, tetapi SDK push, permission, opt-in/opt-out,
/// dan lifecycle OneSignal dijalankan oleh MainActivity Kotlin. Tidak ada lagi
/// `onesignal_flutter` atau inisialisasi push dari Dart.
class NotificationService extends ChangeNotifier {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static const _channel = MethodChannel('com.xystudio.xydesk/notifications');
  static const _pausedKey = 'push_paused_by_user';
  static const _initTimeout = Duration(seconds: 10);

  Future<void>? _initializeFuture;
  bool _handlerAttached = false;
  bool _initialized = false;
  bool _busy = false;
  bool _permissionGranted = false;
  bool _canRequestPermission = false;
  bool _optedIn = false;
  String? _lastError;
  NewsNavigationCallback? onNewsNavigate;
  _PendingNewsNavigation? _pendingNews;
  AppUpdateDetails? _pendingUpdate;
  bool _navigationScheduled = false;
  bool _updateRouteOpen = false;

  bool get supported => NotificationConfig.isSupportedPlatform;
  bool get initialized => _initialized;
  bool get busy => _busy;
  bool get permissionGranted => _permissionGranted;
  bool get canRequestPermission => _canRequestPermission;
  bool get optedIn => _optedIn;
  bool get active => _permissionGranted && _optedIn;
  String? get lastError => _lastError;

  void _attachNativeHandler() {
    if (_handlerAttached) return;
    _handlerAttached = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'notificationClick') return null;
      final data = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
      _onNotificationClick(data);
      return null;
    });
  }

  Future<Map<String, dynamic>> _nativeState() async {
    final value = await _channel.invokeMapMethod<String, dynamic>('getState');
    return value ?? const <String, dynamic>{};
  }

  void _applyState(Map<String, dynamic> state) {
    _initialized = state['initialized'] == true;
    _permissionGranted = state['permissionGranted'] == true;
    _canRequestPermission = state['canRequestPermission'] == true;
    _optedIn = state['optedIn'] == true;
  }

  Future<void> initialize() async {
    if (!supported || _initialized) return;
    final inFlight = _initializeFuture;
    if (inFlight != null) {
      await inFlight.timeout(_initTimeout, onTimeout: () {});
      return;
    }

    _attachNativeHandler();
    final future = _initialize();
    _initializeFuture = future;
    try {
      await future.timeout(_initTimeout, onTimeout: _onInitTimeout);
    } finally {
      if (!_initialized) _initializeFuture = null;
    }
  }

  void _onInitTimeout() {
    _lastError = 'Layanan notifikasi tidak menjawab. Coba lagi dari Pengaturan.';
    DevLog.w('push', 'Bridge OneSignal native melewati batas waktu');
    notifyListeners();
  }

  Future<void> _initialize() async {
    if (!supported) return;
    if (NotificationConfig.oneSignalAppId.trim().isEmpty) {
      _lastError = 'OneSignal App ID belum dikonfigurasi.';
      notifyListeners();
      return;
    }
    try {
      final state = await _channel.invokeMapMethod<String, dynamic>('initialize');
      _applyState(state ?? const <String, dynamic>{});
      _lastError = null;
      await _autoOptInIfAllowed();
      DevLog.ok('push', 'OneSignal native siap', 'bridge MethodChannel');
    } catch (error, stack) {
      _lastError = 'Layanan notifikasi belum dapat dihubungkan.';
      DevLog.e('push', 'Inisialisasi OneSignal native gagal', error, stack);
    }
    notifyListeners();
    flushPendingNavigation();
  }

  Future<void> _autoOptInIfAllowed() async {
    if (!_initialized || !_permissionGranted || _optedIn) return;
    try {
      final store = await Store.open();
      if (store.getBool(_pausedKey)) return;
      final state = await _channel.invokeMapMethod<String, dynamic>('optIn');
      _applyState(state ?? const <String, dynamic>{});
    } catch (error) {
      DevLog.w('push', 'Langganan native belum dapat dinyalakan', '$error');
    }
  }

  Future<void> refresh() async {
    await initialize();
    if (!_initialized) return;
    try {
      _applyState(await _nativeState());
    } catch (error) {
      _lastError = 'Status notifikasi native tidak dapat dibaca.';
      DevLog.w('push', 'Gagal membaca status native', '$error');
    }
    notifyListeners();
  }

  Future<bool> enableUpdates() async {
    if (!supported || _busy) return false;
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      await initialize();
      if (!_initialized) return false;
      if (!_permissionGranted) {
        final granted = await _channel.invokeMethod<bool>('requestPermission') ?? false;
        if (!granted) return false;
      }
      final state = await _channel.invokeMapMethod<String, dynamic>('optIn');
      _applyState(state ?? const <String, dynamic>{});
      await _setPaused(false);
      return active;
    } catch (error, stack) {
      _lastError = 'Izin notifikasi belum dapat diubah.';
      DevLog.e('push', 'Gagal mengaktifkan notifikasi native', error, stack);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> pauseUpdates() async {
    if (!supported || _busy) return;
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      await initialize();
      if (_initialized) {
        final state = await _channel.invokeMapMethod<String, dynamic>('optOut');
        _applyState(state ?? const <String, dynamic>{});
        await _setPaused(true);
      }
    } catch (error, stack) {
      _lastError = 'Langganan notifikasi belum dapat dijeda.';
      DevLog.e('push', 'Gagal menjeda notifikasi native', error, stack);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _setPaused(bool value) async {
    try {
      final store = await Store.open();
      await store.setBool(_pausedKey, value);
    } catch (error) {
      DevLog.w('push', 'Penanda jeda gagal disimpan', '$error');
    }
  }

  void _onNotificationClick(Map<String, dynamic> data) {
    final articleId = data['article_id']?.toString();
    final slug = data['slug']?.toString();
    if (articleId != null && slug != null) {
      _pendingNews = _PendingNewsNavigation(articleId: articleId, slug: slug);
      _flushPendingNewsNavigation();
      return;
    }
    if (AppUpdateDetails.isUpdateDestination(data, actionId: data['action_id']?.toString())) {
      _pendingUpdate = AppUpdateDetails.fromPayload(
        notificationTitle: data['title']?.toString(),
        notificationBody: data['body']?.toString(),
        data: data,
      );
      flushPendingNavigation();
    }
  }

  void _flushPendingNewsNavigation() {
    final pending = _pendingNews;
    if (pending == null) return;
    final callback = onNewsNavigate;
    if (callback != null) {
      _pendingNews = null;
      callback(pending.articleId, pending.slug);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _flushPendingNewsNavigation());
    }
  }

  void flushPendingNavigation() {
    if (_pendingUpdate == null || _navigationScheduled || _updateRouteOpen) return;
    _navigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationScheduled = false;
      final navigator = appNavigatorKey.currentState;
      final details = _pendingUpdate;
      if (navigator == null || details == null || _updateRouteOpen) return;
      _pendingUpdate = null;
      _updateRouteOpen = true;
      navigator.push<void>(
        MaterialPageRoute(
          settings: const RouteSettings(name: NotificationConfig.updateRouteName),
          builder: (_) => UpdatePage(details: details),
        ),
      ).whenComplete(() {
        _updateRouteOpen = false;
        flushPendingNavigation();
      });
    });
  }
}

class _PendingNewsNavigation {
  const _PendingNewsNavigation({required this.articleId, required this.slug});

  final String articleId;
  final String slug;
}
