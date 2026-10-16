import 'package:dio/dio.dart';
import '../constants/api_endpoints.dart';
import '../storage/secure_storage_service.dart';
import 'auth_interceptor.dart';

class ApiClient {
  final Dio dio;
  final SecureStorageService storageService;

  ApiClient({
    String? baseUrl,
    SecureStorageService? storageService,
    VoidCallback? onForceLogout,
  })  : storageService = storageService ?? SecureStorageService(),
        dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? ApiEndpoints.defaultBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ) {
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        storageService: this.storageService,
        onForceLogout: onForceLogout,
      ),
    );
  }
}
