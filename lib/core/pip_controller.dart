import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Nama kanal Picture-in-Picture yang didaftarkan `MainActivity.kt`.
///
/// Satu konstanta untuk sisi Dart (pendaftaran handler di `main.dart` dan
/// pemanggilan di [PipController]) supaya namanya tidak bisa menyimpang
/// diam-diam di dua tempat. Sisi Kotlin punya salinannya sendiri
/// (`MainActivity.PIP_CHANNEL`) — kalau nama ini berubah, ubah keduanya.
const pipChannelName = 'com.xystudio.xydesk/pip';

/// Picture-in-Picture controller untuk floating window saat sesi aktif.
///
/// Ketika app di-minimize saat sesi remote desktop berjalan, PiP mode
/// menampilkan video stream dalam jendela kecil mengambang agar user
/// tetap bisa monitor sesi tanpa harus membuka app penuh.
class PipController {
  PipController._();
  static final PipController instance = PipController._();

  bool _isInPipMode = false;
  bool get isInPipMode => _isInPipMode;

  /// Callback saat PiP mode berubah
  VoidCallback? onPipModeChanged;

  /// Enter PiP mode - dipanggil saat app di-minimize dan sesi aktif
  Future<void> enterPipMode() async {
    if (_isInPipMode) return;

    try {
      // Android: Enter picture-in-picture mode
      if (defaultTargetPlatform == TargetPlatform.android) {
        await const MethodChannel(pipChannelName).invokeMethod('enterPipMode');
        _isInPipMode = true;
        onPipModeChanged?.call();
      }
    } catch (e) {
      debugPrint('PiP enter failed: $e');
    }
  }

  /// Exit PiP mode
  Future<void> exitPipMode() async {
    if (!_isInPipMode) return;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await const MethodChannel(pipChannelName).invokeMethod('exitPipMode');
        _isInPipMode = false;
        onPipModeChanged?.call();
      }
    } catch (e) {
      debugPrint('PiP exit failed: $e');
    }
  }

  /// Handle PiP mode changed dari native side
  void handlePipModeChanged(bool isInPip) {
    _isInPipMode = isInPip;
    onPipModeChanged?.call();
  }
}

/// Mixin untuk widget yang perlu handle PiP mode
mixin PipModeMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    PipController.instance.onPipModeChanged = _onPipModeChanged;
  }

  @override
  void dispose() {
    PipController.instance.onPipModeChanged = null;
    super.dispose();
  }

  void _onPipModeChanged() {
    if (mounted) {
      setState(() {});
      onPipModeChanged();
    }
  }

  /// Override untuk handle PiP mode changed
  void onPipModeChanged() {}
}
