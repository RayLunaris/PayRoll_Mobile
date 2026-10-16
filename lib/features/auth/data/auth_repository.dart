import 'package:flutter/foundation.dart';
import '../../../core/database/app_database.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/user_model.dart';
import '../models/auth_tokens.dart';
import 'auth_remote_datasource.dart';

class AuthRepository extends ChangeNotifier {
  final AuthRemoteDataSource remoteDataSource;
  final SecureStorageService storageService;
  final AppDatabase? database;

  UserModel? _currentUser;
  String? _accessToken;
  bool _isInitialized = false;

  AuthRepository({
    required this.remoteDataSource,
    required this.storageService,
    this.database,
  });

  UserModel? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  bool get isAuthenticated => _accessToken != null && _currentUser != null;
  bool get isInitialized => _isInitialized;

  /// True only if the authenticated user has role 'employee' (Planning/03 §Aturan Flutter #3)
  bool get isEmployee => _currentUser?.isEmployee ?? false;

  /// Restores session upon app startup/restart (survive restart)
  Future<bool> restoreSession() async {
    try {
      final savedUser = await storageService.getUser();
      final savedRefreshToken = await storageService.getRefreshToken();
      final savedAccessToken = await storageService.getAccessToken();

      if (savedRefreshToken != null &&
          savedRefreshToken.isNotEmpty &&
          savedUser['id'] != null &&
          savedUser['email'] != null &&
          savedUser['role'] != null) {
        _accessToken = savedAccessToken;
        _currentUser = UserModel(
          id: savedUser['id']!,
          email: savedUser['email']!,
          role: savedUser['role']!,
          employeeId: savedUser['employeeId'],
        );
        _isInitialized = true;
        notifyListeners();
        return true;
      }
    } catch (_) {}

    _currentUser = null;
    _accessToken = null;
    _isInitialized = true;
    notifyListeners();
    return false;
  }

  /// E01: Login via email & password
  Future<UserModel> login(String email, String password) async {
    final response = await remoteDataSource.login(email, password);

    _accessToken = response.tokens.accessToken;
    _currentUser = response.user;

    // Persist credentials
    await storageService.saveTokens(
      accessToken: response.tokens.accessToken,
      refreshToken: response.tokens.refreshToken,
    );

    await storageService.saveUser(
      id: response.user.id,
      email: response.user.email,
      role: response.user.role,
      employeeId: response.user.employeeId,
    );

    notifyListeners();
    return response.user;
  }

  /// E02: Refresh token
  Future<AuthTokens> refreshSession() async {
    final refreshToken = await storageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await logout();
      throw Exception('No refresh token available');
    }

    try {
      final tokens = await remoteDataSource.refreshToken(refreshToken);
      _accessToken = tokens.accessToken;
      await storageService.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      notifyListeners();
      return tokens;
    } catch (e) {
      await logout();
      rethrow;
    }
  }

  /// E03: Register new employee account
  Future<UserModel> register({
    String? fullName,
    required String email,
    required String password,
  }) async {
    return remoteDataSource.register(
      fullName: fullName,
      email: email,
      password: password,
    );
  }

  /// E04: Request password reset link (always returns generic anti-enumeration message)
  Future<String> forgotPassword(String email) async {
    return remoteDataSource.forgotPassword(email);
  }

  /// E05: Reset password with token
  Future<String> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    return remoteDataSource.resetPassword(
      token: token,
      newPassword: newPassword,
    );
  }

  /// E06: Fetch current user profile (/api/auth/me) & sync role/employeeId
  Future<UserModel> fetchMe() async {
    final user = await remoteDataSource.getMe();
    _currentUser = user;
    await storageService.saveUser(
      id: user.id,
      email: user.email,
      role: user.role,
      employeeId: user.employeeId,
    );
    notifyListeners();
    return user;
  }

  /// Checks if there are unsynced records in local Drift database before logout
  Future<int> getPendingSyncCount() async {
    if (database == null) return 0;
    return database!.getPendingSyncCount();
  }

  /// Checks if there are any pending sync items
  Future<bool> hasPendingSync() async {
    final count = await getPendingSyncCount();
    return count > 0;
  }

  /// E07: Logout + revoke device token + wipe lokal (secure storage, Drift antrean, session)
  Future<void> logout({String? fcmToken}) async {
    try {
      await remoteDataSource.deleteDeviceToken(fcmToken: fcmToken);
    } catch (_) {}

    try {
      await remoteDataSource.logout();
    } catch (_) {
      // Best-effort remote revocation
    }

    // Wipe local Drift queue & cache
    if (database != null) {
      try {
        await database!.clearAllLocalData();
      } catch (_) {}
    }

    // Full secure storage wipe
    await storageService.wipeAll();
    _currentUser = null;
    _accessToken = null;
    notifyListeners();
  }

  /// E08: Change password (/api/auth/password)
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return remoteDataSource.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }
}

