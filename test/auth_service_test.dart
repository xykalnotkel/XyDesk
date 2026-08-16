import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xydesk/features/auth/auth_service.dart';

void main() {
  group('AuthService', () {
    test('requestOtp membaca cooldown dari backend', () async {
      final service = AuthService(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          expect(request.url.path, '/auth/request-otp');
          return http.Response(
            '{"ok":true,"expires_in":600,"resend_in":45}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final result = await service.requestOtp('user@example.com');
      expect(result.expiresIn, 600);
      expect(result.resendIn, 45);
      service.close();
    });

    test('verifyOtp menghasilkan sesi asli', () async {
      final service = AuthService(
        baseUrl: 'https://example.test',
        client: MockClient((_) async {
          return http.Response(
            '{"token":"jwt-value","user":{"id":"u1","email":"user@example.com","name":"User"}}',
            200,
          );
        }),
      );

      final session = await service.verifyOtp('user@example.com', '123456');
      expect(session.token, 'jwt-value');
      expect(session.user.id, 'u1');
      expect(session.user.name, 'User');
      service.close();
    });

    test('me memvalidasi JWT dan membaca profil', () async {
      final service = AuthService(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/auth/me');
          expect(request.headers['authorization'], 'Bearer restored-jwt');
          return http.Response(
            '{"user":{"id":"u1","email":"user@example.com"}}',
            200,
          );
        }),
      );

      final user = await service.me('restored-jwt');
      expect(user.id, 'u1');
      expect(user.email, 'user@example.com');
      service.close();
    });

    test('error backend dipetakan ke pesan pengguna', () async {
      final service = AuthService(
        baseUrl: 'https://example.test',
        client: MockClient((_) async {
          return http.Response('{"error":"wrong-otp"}', 401);
        }),
      );

      await expectLater(
        service.verifyOtp('user@example.com', '000000'),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', 'wrong-otp')
              .having((e) => e.statusCode, 'status', 401),
        ),
      );
      service.close();
    });

    test('me mempertahankan status unauthorized untuk startup cleanup', () async {
      final service = AuthService(
        baseUrl: 'https://example.test',
        client: MockClient((_) async {
          return http.Response('{"error":"unauthorized"}', 401);
        }),
      );

      await expectLater(
        service.me('expired-jwt'),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', 'unauthorized')
              .having((e) => e.statusCode, 'status', 401),
        ),
      );
      service.close();
    });
  });
}
