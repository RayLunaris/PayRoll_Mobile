import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payrollpro/core/network/auth_interceptor.dart';
import 'package:payrollpro/core/storage/secure_storage_service.dart';
import '../helpers/fake_secure_storage.dart';

class MockHttpClientAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  MockHttpClientAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late FakeSecureStorage fakeStorage;
  late SecureStorageService storageService;
  late Dio dio;
  bool logoutCalled = false;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    storageService = SecureStorageService(storage: fakeStorage);
    logoutCalled = false;
    dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3001'));
  });

  test('AuthInterceptor attaches Bearer token when present in storage', () async {
    await storageService.saveTokens(
      accessToken: 'test-valid-access-token',
      refreshToken: 'test-valid-refresh-token',
    );

    final interceptor = AuthInterceptor(
      dio: dio,
      storageService: storageService,
      onForceLogout: () => logoutCalled = true,
    );

    final options = RequestOptions(path: '/api/attendance/today');
    final handler = RequestInterceptorHandler();

    await interceptor.onRequest(options, handler);

    expect(options.headers['Authorization'], 'Bearer test-valid-access-token');
  });

  test('AuthInterceptor handles 401 by refreshing token once and retrying request', () async {
    await storageService.saveTokens(
      accessToken: 'expired-access-token',
      refreshToken: 'valid-refresh-token',
    );

    final testDio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3001'));
    testDio.httpClientAdapter = MockHttpClientAdapter((options) async {
      if (options.path.contains('/api/auth/refresh')) {
        return ResponseBody.fromString(
          jsonEncode({
            'success': true,
            'data': {
              'accessToken': 'newly-refreshed-token',
              'refreshToken': 'new-refresh-token',
            },
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }

      if (options.path.contains('/api/attendance/today')) {
        final auth = options.headers['Authorization'];
        if (auth == 'Bearer expired-access-token') {
          return ResponseBody.fromString(
            jsonEncode({'error': 'Token expired'}),
            401,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        } else if (auth == 'Bearer newly-refreshed-token') {
          return ResponseBody.fromString(
            jsonEncode({
              'success': true,
              'data': {'attendance': 'ok'},
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
      }

      return ResponseBody.fromString('Not Found', 404);
    });

    final interceptor = AuthInterceptor(
      dio: testDio,
      storageService: storageService,
      onForceLogout: () => logoutCalled = true,
    );

    testDio.interceptors.add(interceptor);

    final response = await testDio.get('/api/attendance/today');

    expect(response.statusCode, 200);
    expect(response.data['data']['attendance'], 'ok');

    // Verify tokens updated in storage
    expect(await storageService.getAccessToken(), 'newly-refreshed-token');
    expect(await storageService.getRefreshToken(), 'new-refresh-token');
    expect(logoutCalled, false);
  });

  test('AuthInterceptor triggers logout-wipe if refresh fails with 401/400', () async {
    await storageService.saveTokens(
      accessToken: 'expired-token',
      refreshToken: 'dead-refresh-token',
    );

    final testDio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3001'));
    testDio.httpClientAdapter = MockHttpClientAdapter((options) async {
      if (options.path.contains('/api/auth/refresh')) {
        return ResponseBody.fromString(
          jsonEncode({'error': 'Invalid refresh token'}),
          401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      }

      return ResponseBody.fromString(
        jsonEncode({'error': 'Token expired'}),
        401,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    final interceptor = AuthInterceptor(
      dio: testDio,
      storageService: storageService,
      onForceLogout: () => logoutCalled = true,
    );

    testDio.interceptors.add(interceptor);

    try {
      await testDio.get('/api/attendance/today');
    } catch (_) {}

    expect(logoutCalled, true);
    // Tokens must be wiped
    expect(await storageService.getAccessToken(), isNull);
    expect(await storageService.getRefreshToken(), isNull);
  });
}
