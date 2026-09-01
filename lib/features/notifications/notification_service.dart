import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../../core/devlog.dart';
import '../../core/store.dart';
import 'app_update_details.dart';
import 'notification_config.dart';
import 'update_page.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

/// Integrasi tunggal OneSignal untuk seluruh aplikasi.
///
/// SDK diinisialisasi tanpa memunculkan dialog izin. Dialog sistem hanya
/// dipanggil setelah pengguna menekan tombol opt-in di halaman pengaturan.
class NotificationService extends ChangeNotifier {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  Future<void>? _initializeFuture;
  bool _listenersAttached = false;
  bool _initialized = false;
  bool _busy = false;
  bool _permissionGranted = false;
  bool _canRequestPermission = false;
  bool _optedIn = false;
  String? _lastError;

  /// Kunci penanda "pengguna sengaja menjeda notifikasi". Selama tidak ada,
  /// izin sistem yang sudah diberikan dianggap sebagai persetujuan dan
  /// langganan diaktifkan otomatis.
  static const _pausedKey = 'push_paused_by_user';

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

  Future<void> initialize() async {
    if (_initialized || !supported) return;
    final inFlight = _initializeFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = _initialize();
    _initializeFuture = future;
    try {
      await future;
    } finally {
      // Kegagalan sementara boleh dicoba lagi dari halaman pengaturan.
      if (!_initialized) _initializeFuture = null;
    }
  }

  Future<void> _initialize() async {
    if (!supported) {
      notifyListeners();
      return;
    }
    if (NotificationConfig.oneSignalAppId.trim().isEmpty) {
      _lastError = 'OneSignal App ID belum dikonfigurasi.';
      notifyListeners();
      return;
    }

    _attachListeners();
    try {
      OneSignal.Debug.setLogLevel(
        kDebugMode ? OSLogLevel.warn : OSLogLevel.none,
      );
      await OneSignal.initialize(NotificationConfig.oneSignalAppId);
      _initialized = true;
      _lastError = null;
      _syncState();
      await _syncCanRequest();
      await _autoOptInIfAllowed();
      DevLog.ok('push', 'OneSignal siap', 'izin diminta hanya lewat opt-in');
    } catch (error, stack) {
      _lastError = 'Layanan notifikasi belum dapat dihubungkan.';
      DevLog.e('push', 'Inisialisasi OneSignal gagal', error, stack);
    }
    notifyListeners();
    flushPendingNavigation();
  }

  /// Menyalakan langganan bila izin Android sudah diberikan tetapi SDK masih
  /// berstatus opt-out.
  ///
  /// Ini bukan detail kecil. Perangkat yang izinnya sudah diberikan tapi tidak
  /// pernah opt-in tidak masuk segmen "Subscribed Users", dan push rilis
  /// ditolak OneSignal dengan pesan "All included players are not subscribed".
  /// Itulah sebabnya beberapa rilis terakhir terbit tanpa notifikasi sama
  /// sekali. Pengguna yang sengaja menjeda tetap dihormati lewat penanda
  /// tersimpan.
  Future<void> _autoOptInIfAllowed() async {
    if (!_initialized || !_permissionGranted || _optedIn) return;
    Store? store;
    try {
      store = await Store.open();
    } catch (error) {
      DevLog.w('push', 'Penyimpanan preferensi tidak siap', '$error');
    }
    if (store != null && store.getBool(_pausedKey)) return;
    try {
      await OneSignal.User.pushSubscription.optIn();
      _syncState();
      DevLog.ok('push', 'Langganan dinyalakan', 'izin sistem sudah ada');
    } catch (error, stack) {
      DevLog.e('push', 'Gagal menyalakan langganan otomatis', error, stack);
    }
  }

  void _attachListeners() {
    if (_listenersAttached) return;
    _listenersAttached = true;
    OneSignal.Notifications.addClickListener(_onNotificationClick);
    OneSignal.Notifications.addPermissionObserver(_onPermissionChanged);
    OneSignal.User.pushSubscription.addObserver(_onSubscriptionChanged);
  }

  void _onPermissionChanged(bool granted) {
    _permissionGranted = granted;
    if (granted) {
      _canRequestPermission = false;
    } else {
      unawaited(_syncCanRequest());
    }
    notifyListeners();
  }

  void _onSubscriptionChanged(OSPushSubscriptionChangedState change) {
    _optedIn = change.current.optedIn;
    notifyListeners();
  }

  void _syncState() {
    if (!_initialized) return;
    _permissionGranted = OneSignal.Notifications.permission;
    _optedIn = OneSignal.User.pushSubscription.optedIn ?? false;
  }

  Future<void> _syncCanRequest() async {
    if (!_initialized || _permissionGranted) {
      _canRequestPermission = false;
      return;
    }
    try {
      _canRequestPermission = await OneSignal.Notifications.canRequest();
    } catch (error, stack) {
      DevLog.e('push', 'Status prompt izin tidak tersedia', error, stack);
    }
  }

  Future<void> refresh() async {
    await initialize();
    _syncState();
    await _syncCanRequest();
    notifyListeners();
  }

  /// Meminta izin setelah pengguna memahami manfaatnya dan menekan tombol.
  Future<bool> enableUpdates() async {
    if (!supported || _busy) return false;
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      await initialize();
      if (!_initialized) return false;

      // canRequest membedakan prompt pertama dengan izin yang harus dibuka
      // kembali melalui Settings. fallbackToSettings menangani kasus kedua.
      _canRequestPermission = await OneSignal.Notifications.canRequest();
      final granted = _permissionGranted
          ? true
          : await OneSignal.Notifications.requestPermission(true);
      if (granted) {
        // requestPermission saja tidak membatalkan opt-out SDK sebelumnya.
        await OneSignal.User.pushSubscription.optIn();
        await _setPaused(false);
      }
      _syncState();
      await _syncCanRequest();
      return active;
    } catch (error, stack) {
      _lastError = 'Izin notifikasi belum dapat diubah.';
      DevLog.e('push', 'Gagal mengaktifkan notifikasi', error, stack);
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
        await OneSignal.User.pushSubscription.optOut();
        await _setPaused(true);
        _syncState();
      }
    } catch (error, stack) {
      _lastError = 'Langganan notifikasi belum dapat dijeda.';
      DevLog.e('push', 'Gagal menjeda notifikasi', error, stack);
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

  void _onNotificationClick(OSNotificationClickEvent event) {
    final data = event.notification.additionalData;
    if (!AppUpdateDetails.isUpdateDestination(
      data,
      actionId: event.result.actionId,
    )) {
      DevLog.i('push', 'Notifikasi dibuka', 'tanpa rute internal yang dikenal');
      return;
    }

    _pendingUpdate = AppUpdateDetails.fromPayload(
      notificationTitle: event.notification.title,
      notificationBody: event.notification.body,
      data: data,
    );
    DevLog.i(
      'push',
      'Notifikasi dibuka',
      NotificationConfig.updateRoutePayload,
    );
    flushPendingNavigation();
  }

  /// Aman dipanggil berkali-kali dari MaterialApp builder.
  void flushPendingNavigation() {
    if (_pendingUpdate == null || _navigationScheduled || _updateRouteOpen) {
      return;
    }
    _navigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationScheduled = false;
      final navigator = appNavigatorKey.currentState;
      final details = _pendingUpdate;
      if (navigator == null || details == null || _updateRouteOpen) return;

      _pendingUpdate = null;
      _updateRouteOpen = true;
      navigator
          .push<void>(
            MaterialPageRoute(
              settings: const RouteSettings(
                name: NotificationConfig.updateRouteName,
              ),
              builder: (_) => UpdatePage(details: details),
            ),
          )
          .whenComplete(() {
            _updateRouteOpen = false;
            flushPendingNavigation();
          });
    });
  }
}
