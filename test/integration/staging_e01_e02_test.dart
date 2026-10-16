import 'package:flutter_test/flutter_test.dart';
import 'package:payrollpro/core/network/api_client.dart';
import 'package:payrollpro/core/storage/secure_storage_service.dart';
import 'package:payrollpro/features/auth/data/auth_remote_datasource.dart';
import 'package:payrollpro/features/auth/data/auth_repository.dart';
import '../helpers/fake_secure_storage.dart';

void main() {
  group('E01-E02 Integration Test against Staging Gateway (:3001)', () {
    late FakeSecureStorage fakeStorage;
    late SecureStorageService storageService;
    late ApiClient apiClient;
    late AuthRemoteDataSource remoteDataSource;
    late AuthRepository authRepository;

    setUp(() {
      fakeStorage = FakeSecureStorage();
      storageService = SecureStorageService(storage: fakeStorage);
      apiClient = ApiClient(
        baseUrl: 'http://127.0.0.1:3001',
        storageService: storageService,
      );
      remoteDataSource = AuthRemoteDataSourceImpl(dio: apiClient.dio);
      authRepository = AuthRepository(
        remoteDataSource: remoteDataSource,
        storageService: storageService,
      );
    });

    test('1. BUKTI LOGIN 200: Login ke Staging Gateway :3001 berhasil dengan token JWT valid',
        () async {
      final user = await authRepository.login('sinta@payrollpro.com', 'password123');

      expect(user.email, 'sinta@payrollpro.com');
      expect(user.role, 'employee');
      expect(user.employeeId, isNotNull);
      expect(authRepository.isAuthenticated, isTrue);

      final accessToken = await storageService.getAccessToken();
      final refreshToken = await storageService.getRefreshToken();

      expect(accessToken, isNotNull);
      expect(accessToken!.split('.').length, 3); // Valid JWT structure
      expect(refreshToken, isNotNull);
      expect(refreshToken!.split('.').length, 3); // Valid JWT structure
    });

    test('2. B1 DEVICE-TOKENS: Akses endpoint B1 device-tokens dengan token hasil login (insert + upsert idempoten)',
        () async {
      // Login first
      await authRepository.login('sinta@payrollpro.com', 'password123');
      final uniqueToken =
          'fcm-flutter-client-token-${DateTime.now().millisecondsSinceEpoch}';

      // 1st call: insert device token (B1)
      final res1 = await apiClient.dio.post(
        '/api/device-tokens',
        data: {
          'fcmToken': uniqueToken,
          'platform': 'android',
          'appVersion': '1.0.0',
        },
      );

      expect(res1.statusCode, 201);
      expect(res1.data['success'], isTrue);
      expect(res1.data['data']['fcmToken'], uniqueToken);
      expect(res1.data['data']['platform'], 'android');

      // 2nd call with same token: upsert path must also return full record
      final res2 = await apiClient.dio.post(
        '/api/device-tokens',
        data: {
          'fcmToken': uniqueToken,
          'platform': 'android',
          'appVersion': '1.0.1',
        },
      );

      expect(res2.statusCode, 201);
      expect(res2.data['success'], isTrue);
      expect(res2.data['data']['fcmToken'], uniqueToken);
      expect(res2.data['data']['platform'], 'android');
      expect(res2.data['data']['appVersion'], '1.0.1');
    });

    test('3. BUKTI REFRESH-SURVIVE-RESTART: Sesi pulih setelah restart & token di-refresh ke staging',
        () async {
      // Login to obtain initial tokens
      await authRepository.login('sinta@payrollpro.com', 'password123');
      final initialAccessToken = await storageService.getAccessToken();

      // SIMULATE APP RESTART: Instantiate completely new AuthRepository with stored tokens
      final freshBootRepo = AuthRepository(
        remoteDataSource: remoteDataSource,
        storageService: storageService,
      );

      final didRestore = await freshBootRepo.restoreSession();
      expect(didRestore, isTrue);
      expect(freshBootRepo.isAuthenticated, isTrue);
      expect(freshBootRepo.currentUser?.email, 'sinta@payrollpro.com');
      expect(freshBootRepo.accessToken, initialAccessToken);

      // Wait 1 second so unix timestamp advances and yields a refreshed JWT signature
      await Future.delayed(const Duration(seconds: 1));

      // Call E02 refresh endpoint against staging gateway
      final refreshedTokens = await freshBootRepo.refreshSession();
      expect(refreshedTokens.accessToken, isNotEmpty);
      expect(refreshedTokens.accessToken, isNot(equals(initialAccessToken)));

      // Verify new token persisted in secure storage
      final storedAfterRefresh = await storageService.getAccessToken();
      expect(storedAfterRefresh, refreshedTokens.accessToken);
    });

    test('4. BUKTI LOGOUT-WIPE: Logout mencabut token dan menghapus total storage',
        () async {
      // Login first
      await authRepository.login('sinta@payrollpro.com', 'password123');
      expect(authRepository.isAuthenticated, isTrue);

      // Perform logout
      await authRepository.logout();

      // Verify in-memory state reset
      expect(authRepository.isAuthenticated, isFalse);
      expect(authRepository.currentUser, isNull);
      expect(authRepository.accessToken, isNull);

      // Verify secure storage completely wiped
      expect(await storageService.getAccessToken(), isNull);
      expect(await storageService.getRefreshToken(), isNull);
      final userMap = await storageService.getUser();
      expect(userMap['id'], isNull);
      expect(userMap['email'], isNull);
    });

    test('5. E06 GET /api/auth/me: Mengambil profil user aktif & memvalidasi role employee',
        () async {
      await authRepository.login('sinta@payrollpro.com', 'password123');
      final me = await authRepository.fetchMe();

      expect(me.email, 'sinta@payrollpro.com');
      expect(me.role, 'employee');
      expect(me.isEmployee, isTrue);
      expect(authRepository.isEmployee, isTrue);
    });

    test('6. E04 POST /api/auth/forgot-password: Mengembalikan respons generik anti-enumerasi (200)',
        () async {
      final msgExisting = await authRepository.forgotPassword('sinta@payrollpro.com');
      final msgNonExisting = await authRepository.forgotPassword('tidakada@payrollpro.com');

      expect(
        msgExisting,
        'Jika email terdaftar, link reset password sudah dikirim ke inbox Anda.',
      );
      expect(msgNonExisting, equals(msgExisting));
    });

    test('7. E08 PUT /api/auth/password: Menolak currentPassword salah dengan 401',
        () async {
      await authRepository.login('sinta@payrollpro.com', 'password123');

      expect(
        () => authRepository.changePassword(
          currentPassword: 'salah-password-123',
          newPassword: 'passwordBaru123',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}

