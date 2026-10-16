import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../models/login_response.dart';
import '../models/auth_tokens.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<LoginResponse> login(String email, String password);
  Future<AuthTokens> refreshToken(String refreshToken);
  Future<UserModel> register({
    String? fullName,
    required String email,
    required String password,
  });
  Future<String> forgotPassword(String email);
  Future<String> resetPassword({
    required String token,
    required String newPassword,
  });
  Future<UserModel> getMe();
  Future<void> logout();
  Future<void> deleteDeviceToken({String? fcmToken});
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;

  AuthRemoteDataSourceImpl({required this.dio});

  @override
  Future<LoginResponse> login(String email, String password) async {
    try {
      final response = await dio.post(
        ApiEndpoints.login,
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return LoginResponse.fromJson(response.data as Map<String, dynamic>);
      }

      throw ApiException(
        statusCode: response.statusCode,
        message: 'Gagal melakukan login',
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<AuthTokens> refreshToken(String refreshToken) async {
    try {
      final response = await dio.post(
        ApiEndpoints.refresh,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200 && response.data != null) {
        final resData = response.data as Map<String, dynamic>;
        final payload = (resData['data'] is Map<String, dynamic>)
            ? resData['data'] as Map<String, dynamic>
            : resData;
        return AuthTokens.fromJson(payload);
      }

      throw ApiException(
        statusCode: response.statusCode,
        message: 'Gagal memperbarui sesi token',
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<UserModel> register({
    String? fullName,
    required String email,
    required String password,
  }) async {
    try {
      final response = await dio.post(
        ApiEndpoints.register,
        data: {
          if (fullName != null && fullName.trim().isNotEmpty)
            'fullName': fullName.trim(),
          'email': email.trim(),
          'password': password,
        },
      );

      if ((response.statusCode == 201 || response.statusCode == 200) &&
          response.data != null) {
        final resData = response.data as Map<String, dynamic>;
        final payload = (resData['data'] is Map<String, dynamic>)
            ? resData['data'] as Map<String, dynamic>
            : resData;
        return UserModel.fromJson(payload);
      }

      throw ApiException(
        statusCode: response.statusCode,
        message: 'Gagal mendaftarkan akun',
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<String> forgotPassword(String email) async {
    try {
      final response = await dio.post(
        ApiEndpoints.forgotPassword,
        data: {'email': email.trim()},
      );

      if (response.statusCode == 200 && response.data != null) {
        final resData = response.data as Map<String, dynamic>;
        return (resData['message'] as String?) ??
            'Jika email terdaftar, link reset password sudah dikirim ke inbox Anda.';
      }

      throw ApiException(
        statusCode: response.statusCode,
        message: 'Gagal memproses permintaan lupa kata sandi',
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<String> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await dio.post(
        ApiEndpoints.resetPassword,
        data: {
          'token': token.trim(),
          'newPassword': newPassword,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final resData = response.data as Map<String, dynamic>;
        return (resData['message'] as String?) ??
            'Password berhasil direset. Silakan login dengan password baru.';
      }

      throw ApiException(
        statusCode: response.statusCode,
        message: 'Gagal mereset kata sandi',
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<UserModel> getMe() async {
    try {
      final response = await dio.get(ApiEndpoints.me);
      if (response.statusCode == 200 && response.data != null) {
        final resData = response.data as Map<String, dynamic>;
        final payload = (resData['data'] is Map<String, dynamic>)
            ? resData['data'] as Map<String, dynamic>
            : resData;
        return UserModel.fromJson(payload);
      }
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Gagal memuat profil pengguna',
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await dio.post(ApiEndpoints.logout);
    } on DioException catch (_) {
      // Best-effort remote revocation; even if offline/failed, local wipe continues
    }
  }

  @override
  Future<void> deleteDeviceToken({String? fcmToken}) async {
    try {
      await dio.delete(
        ApiEndpoints.deviceTokens,
        data: fcmToken != null ? {'fcmToken': fcmToken} : null,
      );
    } on DioException catch (_) {
      // Best-effort device token revocation on logout
    }
  }

  @override
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await dio.put(
        ApiEndpoints.updatePassword,
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final resData = response.data as Map<String, dynamic>;
        return (resData['message'] as String?) ?? 'Password berhasil diubah';
      }

      throw ApiException(
        statusCode: response.statusCode,
        message: 'Gagal mengubah kata sandi',
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

