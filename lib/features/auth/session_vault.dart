import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SessionVault {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<void> deleteToken();
}

/// Penyimpanan JWT menggunakan keystore/keychain milik platform.
class SecureSessionVault implements SessionVault {
  SecureSessionVault({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'xydesk.auth.jwt';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() => _storage.read(key: _tokenKey);

  @override
  Future<void> writeToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  @override
  Future<void> deleteToken() => _storage.delete(key: _tokenKey);
}

/// Default aman untuk test/widget preview yang tidak memiliki plugin platform.
class NoopSessionVault implements SessionVault {
  const NoopSessionVault();

  @override
  Future<String?> readToken() async => null;

  @override
  Future<void> writeToken(String token) async {}

  @override
  Future<void> deleteToken() async {}
}

final sessionVaultProvider = Provider<SessionVault>(
  (_) => const NoopSessionVault(),
);

/// Diisi main() setelah token dibaca dari secure storage.
final initialAuthTokenProvider = Provider<String?>((_) => null);
