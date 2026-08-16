import 'dart:convert';

import 'package:http/http.dart' as http;

/// Klien auth XyDesk — memanggil endpoint auth asli di Cloudflare Worker.
///
/// Menggantikan "Google tiruan" + OTP palsu di AuthScreen dengan alur nyata:
///   - requestOtp(email)          → server kirim OTP (hashed, rate-limited)
///   - verifyOtp(email, otp)      → { token } (JWT sesi 30 hari)
///   - signInWithGoogle(idToken)  → { token } (Google OAuth asli)
///   - me(token)                  → info user dari sesi
///
/// Base URL: https://signal.xystudio.my.id (endpoint /auth/*).
class AuthService {
  AuthService({required this.baseUrl});

  final String baseUrl;

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  /// Minta OTP 6 digit untuk [email]. Melempar [AuthException] bila gagal.
  Future<void> requestOtp(String email) async {
    final res = await http
        .post(_u('/auth/request-otp'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'email': email}))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw AuthException.fromResponse(res);
    }
  }

  /// Verifikasi OTP → kembalikan [AuthSession] (token + user).
  Future<AuthSession> verifyOtp(String email, String otp) async {
    final res = await http
        .post(_u('/auth/verify-otp'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'email': email, 'otp': otp}))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw AuthException.fromResponse(res);
    }
    return AuthSession.fromJson(jsonDecode(res.body));
  }

  /// Tukar ID token Google (dari google_sign_in) → [AuthSession].
  Future<AuthSession> signInWithGoogle(String idToken) async {
    final res = await http
        .post(_u('/auth/google'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'id_token': idToken}))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw AuthException.fromResponse(res);
    }
    return AuthSession.fromJson(jsonDecode(res.body));
  }

  /// Ambil profil user dari JWT sesi.
  Future<AuthUser> me(String token) async {
    final res = await http.get(_u('/auth/me'),
        headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw AuthException.fromResponse(res);
    }
    return AuthUser.fromJson((jsonDecode(res.body)['user']) as Map<String, dynamic>);
  }
}

/// Sesi login (token JWT + user).
class AuthSession {
  AuthSession({required this.token, required this.user});

  final String token;
  final AuthUser user;

  factory AuthSession.fromJson(Map<String, dynamic> j) => AuthSession(
        token: j['token'] as String,
        user: AuthUser.fromJson(j['user'] as Map<String, dynamic>),
      );
}

class AuthUser {
  AuthUser({required this.id, required this.email, this.name});

  final String id;
  final String email;
  final String? name;

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'] as String,
        email: j['email'] as String,
        name: j['name'] as String?,
      );
}

class AuthException implements Exception {
  AuthException(this.code, this.message);

  final String code;
  final String message;

  factory AuthException.fromResponse(http.Response res) {
    String code = 'http-${res.statusCode}';
    String message = 'Gagal: ${res.statusCode}';
    try {
      final b = jsonDecode(res.body) as Map<String, dynamic>;
      code = b['error'] as String? ?? code;
      message = switch (code) {
        'invalid-email' => 'Alamat email tidak valid.',
        'cooldown' => 'Tunggu beberapa saat sebelum kirim ulang.',
        'wrong-otp' => 'Kode OTP salah.',
        'otp-expired' => 'Kode OTP kedaluwarsa, minta yang baru.',
        'too-many-attempts' => 'Terlalu banyak percobaan, minta OTP baru.',
        'google-not-configured' => 'Google login belum dikonfigurasi.',
        'unauthorized' => 'Sesi tidak valid, silakan masuk ulang.',
        _ => 'Terjadi kesalahan ($code).',
      };
    } catch (_) {}
    return AuthException(code, message);
  }

  @override
  String toString() => message;
}
