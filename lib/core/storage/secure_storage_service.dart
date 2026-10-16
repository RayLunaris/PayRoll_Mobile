import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/storage_keys.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: StorageKeys.accessToken, value: accessToken);
    await _storage.write(key: StorageKeys.refreshToken, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: StorageKeys.accessToken);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: StorageKeys.refreshToken);
  }

  Future<void> saveUser({
    required String id,
    required String email,
    required String role,
    String? employeeId,
  }) async {
    await _storage.write(key: StorageKeys.userId, value: id);
    await _storage.write(key: StorageKeys.userEmail, value: email);
    await _storage.write(key: StorageKeys.userRole, value: role);
    if (employeeId != null) {
      await _storage.write(key: StorageKeys.employeeId, value: employeeId);
    } else {
      await _storage.delete(key: StorageKeys.employeeId);
    }
  }

  Future<Map<String, String?>> getUser() async {
    return {
      'id': await _storage.read(key: StorageKeys.userId),
      'email': await _storage.read(key: StorageKeys.userEmail),
      'role': await _storage.read(key: StorageKeys.userRole),
      'employeeId': await _storage.read(key: StorageKeys.employeeId),
    };
  }

  /// Wipes all credentials upon logout or authorization revocation
  Future<void> wipeAll() async {
    await _storage.deleteAll();
  }
}
