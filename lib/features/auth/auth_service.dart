import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// Konfigurasi publik yang ditanam saat build.
///
/// Contoh:
/// `flutter build apk --dart-define=GOOGLE_CLIENT_ID=xxx.apps.googleusercontent.com`
abstract final class AuthConfig {
  static const baseUrl = String.fromEnvironment(
    'XYDESK_API_URL',
    defaultValue: 'https://signal.xystudio.my.id',
  );

  // OAuth client ID bukan secret, tetapi tetap dipasok dari konfigurasi build
  // agar APK dev/prod dapat memakai project Google yang berbeda.
  static const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
}

final authServiceProvider = Provider<AuthService>((ref) {
  final service = AuthService(baseUrl: AuthConfig.baseUrl);
  ref.onDispose(service.close);
  return service;
});

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService(ref.watch(authServiceProvider));
});

/// HTTP client untuk autentikasi XyDesk di Cloudflare Worker.
class AuthService {
  AuthService({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  void close() => _client.close();

  Future<OtpRequestResult> requestOtp(
    String email, {
    required String name,
  }) async {
    final body = await _post('/auth/request-otp', {
      'email': email,
      'name': name,
    });
    return OtpRequestResult(
      expiresIn: (body['expires_in'] as num?)?.toInt() ?? 600,
      resendIn: (body['resend_in'] as num?)?.toInt() ?? 60,
    );
  }

  Future<AuthSession> verifyOtp(String email, String otp) async {
    final body = await _post('/auth/verify-otp', {'email': email, 'otp': otp});
    return AuthSession.fromJson(body);
  }

  Future<AuthSession> signInWithGoogle(String idToken) async {
    final body = await _post('/auth/google', {'id_token': idToken});
    return AuthSession.fromJson(body);
  }

  Future<AuthUser> me(String token) async {
    try {
      final response = await _client
          .get(_uri('/auth/me'), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 10));
      final body = _decode(response);
      if (response.statusCode != 200) {
        throw AuthException.fromBody(response.statusCode, body);
      }
      return AuthUser.fromJson(body['user'] as Map<String, dynamic>);
    } on TimeoutException {
      throw const AuthException('timeout', 'Server terlalu lama merespons.');
    } on http.ClientException {
      throw const AuthException(
        'network',
        'Tidak dapat terhubung ke server. Periksa koneksi internet.',
      );
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _client
          .post(
            _uri(path),
            headers: {'content-type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      final body = _decode(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException.fromBody(response.statusCode, body);
      }
      return body;
    } on TimeoutException {
      throw const AuthException('timeout', 'Server terlalu lama merespons.');
    } on http.ClientException {
      throw const AuthException(
        'network',
        'Tidak dapat terhubung ke server. Periksa koneksi internet.',
      );
    }
  }

  static Map<String, dynamic> _decode(http.Response response) {
    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is Map<String, dynamic>) return value;
    } catch (_) {
      // Diubah menjadi error terstruktur di bawah.
    }
    return {'error': 'invalid-response'};
  }
}

/// Mengambil Google ID token lalu menukarnya dengan JWT XyDesk.
///
/// Android memakai OAuth Web Client ID sebagai `serverClientId`. Web wajib
/// memakai tombol resmi GIS dan akan ditangani sebagai tahap terpisah; email OTP
/// tetap berfungsi di Web, Windows, dan Android.
class GoogleAuthService {
  GoogleAuthService(this._api);

  final AuthService _api;
  Future<void>? _initializing;

  Future<AuthSession> signIn() async {
    final signIn = GoogleSignIn.instance;

    if (kIsWeb || !signIn.supportsAuthenticate()) {
      throw const AuthException(
        'google-platform-unsupported',
        'Google masuk langsung sementara tersedia di aplikasi Android. Gunakan email OTP pada platform ini.',
      );
    }

    await (_initializing ??= _initialize(signIn));

    try {
      final account = await signIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException(
          'google-no-id-token',
          'Google tidak memberikan ID token. Periksa konfigurasi OAuth.',
        );
      }
      // Await di dalam blok try agar kegagalan HTTP tetap melewati pemetaan
      // error di bawah, bukan lolos sebagai Future error mentah ke UI.
      return await _api.signInWithGoogle(idToken);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthException(
          'google-canceled',
          'Masuk dengan Google dibatalkan.',
        );
      }
      throw AuthException(
        'google-sign-in',
        'Google Sign-In gagal (${error.code.name}).',
      );
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Sesi XyDesk tetap harus dapat dihapus walau plugin tidak tersedia.
    }
  }

  Future<void> _initialize(GoogleSignIn signIn) async {
    final clientId = AuthConfig.googleClientId.trim();
    if (clientId.isEmpty) {
      throw const AuthException(
        'google-client-id-missing',
        'Google Client ID belum ditanam pada build aplikasi.',
      );
    }
    await signIn.initialize(serverClientId: clientId);
  }
}

class OtpRequestResult {
  const OtpRequestResult({required this.expiresIn, required this.resendIn});

  final int expiresIn;
  final int resendIn;
}

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AuthUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final token = json['token'];
    final user = json['user'];
    if (token is! String || token.isEmpty || user is! Map<String, dynamic>) {
      throw const AuthException(
        'invalid-response',
        'Respons sesi dari server tidak valid.',
      );
    }
    return AuthSession(token: token, user: AuthUser.fromJson(user));
  }
}

class AuthUser {
  const AuthUser({required this.id, required this.email, this.name});

  final String id;
  final String email;
  final String? name;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email'];
    if (id is! String || email is! String) {
      throw const AuthException(
        'invalid-response',
        'Data pengguna dari server tidak valid.',
      );
    }
    return AuthUser(id: id, email: email, name: json['name'] as String?);
  }
}

class AuthException implements Exception {
  const AuthException(this.code, this.message, {this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  factory AuthException.fromBody(int statusCode, Map<String, dynamic> body) {
    final code = body['error'] as String? ?? 'http-$statusCode';
    final retry = (body['resend_in'] as num?)?.toInt();
    final message = switch (code) {
      'invalid-email' => 'Alamat email tidak valid.',
      'invalid-name' => 'Nama harus terdiri dari 2 sampai 80 karakter.',
      'invalid-input' => 'Data yang dimasukkan tidak valid.',
      'cooldown' =>
        retry == null
            ? 'Tunggu sebelum mengirim ulang kode.'
            : 'Tunggu $retry detik sebelum mengirim ulang.',
      'wrong-otp' => 'Kode OTP salah.',
      'otp-expired' => 'Kode OTP kedaluwarsa. Minta kode yang baru.',
      'too-many-attempts' => 'Terlalu banyak percobaan. Minta OTP baru.',
      'email-not-configured' => 'Layanan email OTP belum dikonfigurasi.',
      'email-send-failed' =>
        'Email OTP gagal dikirim. Coba beberapa saat lagi.',
      'auth-not-configured' => 'Layanan autentikasi belum dikonfigurasi.',
      'google-not-configured' => 'Google login belum dikonfigurasi di server.',
      'email-not-verified' => 'Email Google belum diverifikasi.',
      'identity-conflict' => 'Identitas Google bertentangan dengan akun ini.',
      'unauthorized' => 'Sesi tidak valid. Silakan masuk ulang.',
      'invalid-token' => 'Token Google tidak valid.',
      'invalid-response' => 'Respons server tidak dapat dibaca.',
      _ => 'Terjadi kesalahan ($code).',
    };
    return AuthException(code, message, statusCode: statusCode);
  }

  @override
  String toString() => message;
}
