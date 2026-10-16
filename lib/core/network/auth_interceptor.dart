import 'dart:async';
import 'package:dio/dio.dart';
import '../storage/secure_storage_service.dart';
import '../constants/api_endpoints.dart';

typedef VoidCallback = void Function();

class AuthInterceptor extends Interceptor {
  final Dio dio;
  final SecureStorageService storageService;
  final VoidCallback? onForceLogout;

  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  AuthInterceptor({
    required this.dio,
    required this.storageService,
    this.onForceLogout,
  });

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Pass Bearer token if not already explicitly set
    if (!options.headers.containsKey('Authorization')) {
      final token = await storageService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final requestOptions = err.requestOptions;

    // Only handle 401 Unauthorized
    if (response?.statusCode != 401) {
      return handler.next(err);
    }

    // Guard 1: Do not refresh if request was already a retry attempt
    final isRetry = requestOptions.extra['isRetry'] == true;
    if (isRetry) {
      await _handleLogout();
      return handler.next(err);
    }

    // Guard 2: Do not refresh if endpoint is login or refresh itself
    final path = requestOptions.path;
    if (path.contains(ApiEndpoints.login) || path.contains(ApiEndpoints.refresh)) {
      if (path.contains(ApiEndpoints.refresh)) {
        await _handleLogout();
      }
      return handler.next(err);
    }

    // 401 Interceptor: Refresh-sekali
    try {
      String? newAccessToken;

      if (_isRefreshing) {
        // Wait for active refresh in-flight
        newAccessToken = await _refreshCompleter?.future;
      } else {
        _isRefreshing = true;
        _refreshCompleter = Completer<String?>();

        final refreshToken = await storageService.getRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          _refreshCompleter?.complete(null);
          _isRefreshing = false;
          await _handleLogout();
          return handler.next(err);
        }

        // Dedicated Dio instance for refresh call to avoid interceptor recursion
        final refreshDio = Dio(
          BaseOptions(
            baseUrl: dio.options.baseUrl,
            headers: {'Content-Type': 'application/json'},
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        )..httpClientAdapter = dio.httpClientAdapter;

        final refreshRes = await refreshDio.post(
          ApiEndpoints.refresh,
          data: {'refreshToken': refreshToken},
        );

        if (refreshRes.statusCode == 200 && refreshRes.data != null) {
          final resData = refreshRes.data;
          // Support {success: true, data: {accessToken: ...}} or direct {accessToken: ...}
          final tokenData = resData['data'] ?? resData;
          newAccessToken = tokenData['accessToken'] as String?;
          final newRefreshToken = (tokenData['refreshToken'] as String?) ?? refreshToken;

          if (newAccessToken != null && newAccessToken.isNotEmpty) {
            await storageService.saveTokens(
              accessToken: newAccessToken,
              refreshToken: newRefreshToken,
            );
            _refreshCompleter?.complete(newAccessToken);
          } else {
            _refreshCompleter?.complete(null);
          }
        } else {
          _refreshCompleter?.complete(null);
        }
      }

      _isRefreshing = false;

      if (newAccessToken == null || newAccessToken.isEmpty) {
        await _handleLogout();
        return handler.next(err);
      }

      // Retry original request with new token
      requestOptions.extra['isRetry'] = true;
      requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';

      final retryRes = await dio.fetch(requestOptions);
      return handler.resolve(retryRes);
    } catch (refreshError) {
      _isRefreshing = false;
      _refreshCompleter?.complete(null);
      await _handleLogout();
      return handler.next(err);
    }
  }

  Future<void> _handleLogout() async {
    await storageService.wipeAll();
    onForceLogout?.call();
  }
}
