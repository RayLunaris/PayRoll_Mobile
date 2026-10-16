import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payrollpro/core/constants/app_keys.dart';
import 'package:payrollpro/core/constants/storage_keys.dart';
import 'package:payrollpro/core/database/app_database.dart';
import 'package:payrollpro/core/network/api_exception.dart';
import 'package:payrollpro/core/router/app_router.dart';
import 'package:payrollpro/core/storage/secure_storage_service.dart';
import 'package:payrollpro/features/auth/data/auth_remote_datasource.dart';
import 'package:payrollpro/features/auth/data/auth_repository.dart';
import 'package:payrollpro/features/auth/models/auth_tokens.dart';
import 'package:payrollpro/features/auth/models/login_response.dart';
import 'package:payrollpro/features/auth/models/user_model.dart';
import 'package:payrollpro/main.dart';
import '../../helpers/fake_secure_storage.dart';

class MockAuthRemoteDataSource implements AuthRemoteDataSource {
  bool shouldFailLogin = false;
  bool shouldFailRegisterDuplicate = false;
  bool shouldFailResetToken = false;
  bool shouldFailCurrentPassword = false;
  bool logoutCalled = false;
  bool deleteDeviceTokenCalled = false;
  int refreshCallCount = 0;
  String loginRole = 'employee';
  String meRole = 'employee';
  Map<String, String>? lastChangePasswordArgs;

  @override
  Future<LoginResponse> login(String email, String password) async {
    if (shouldFailLogin) {
      throw ApiException(statusCode: 401, message: 'Invalid credentials');
    }
    return LoginResponse(
      tokens: AuthTokens(
        accessToken: 'mock-access-token-jwt-12345',
        refreshToken: 'mock-refresh-token-jwt-67890',
      ),
      user: UserModel(
        id: 'usr-1111-2222',
        email: email,
        role: loginRole,
        employeeId: loginRole == 'employee' ? 'emp-3333-4444' : null,
      ),
    );
  }

  @override
  Future<AuthTokens> refreshToken(String refreshToken) async {
    refreshCallCount++;
    return AuthTokens(
      accessToken: 'mock-new-access-token',
      refreshToken: 'mock-new-refresh-token',
    );
  }

  @override
  Future<UserModel> register({
    String? fullName,
    required String email,
    required String password,
  }) async {
    if (shouldFailRegisterDuplicate) {
      throw ApiException(statusCode: 409, message: 'Email already exists');
    }
    return UserModel(
      id: 'usr-new-9999',
      email: email,
      role: 'employee',
      employeeId: 'emp-new-9999',
    );
  }

  @override
  Future<String> forgotPassword(String email) async {
    return 'Jika email terdaftar, link reset password sudah dikirim ke inbox Anda.';
  }

  @override
  Future<String> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    if (shouldFailResetToken) {
      throw ApiException(
        statusCode: 400,
        message: 'Token tidak valid atau sudah kedaluwarsa.',
      );
    }
    return 'Password berhasil direset. Silakan login dengan password baru.';
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  Future<void> deleteDeviceToken({String? fcmToken}) async {
    deleteDeviceTokenCalled = true;
  }

  @override
  Future<UserModel> getMe() async {
    return UserModel(
      id: 'usr-1111-2222',
      email: 'sinta@payrollpro.com',
      role: meRole,
      employeeId: meRole == 'employee' ? 'emp-3333-4444' : null,
      isActive: true,
    );
  }

  @override
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    lastChangePasswordArgs = {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    };
    if (shouldFailCurrentPassword) {
      throw ApiException(statusCode: 401, message: 'Password saat ini salah');
    }
    return 'Password berhasil diubah';
  }
}

void main() {
  late FakeSecureStorage fakeStorage;
  late SecureStorageService storageService;
  late MockAuthRemoteDataSource mockRemote;
  late AppDatabase inMemoryDb;
  late AuthRepository authRepository;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    storageService = SecureStorageService(storage: fakeStorage);
    mockRemote = MockAuthRemoteDataSource();
    inMemoryDb = AppDatabase(NativeDatabase.memory());
    authRepository = AuthRepository(
      remoteDataSource: mockRemote,
      storageService: storageService,
      database: inMemoryDb,
    );
  });

  tearDown(() async {
    await inMemoryDb.close();
  });

  group('J1 Auth Suite E01-E08 (Login, Register, Forgot/Reset, /me, Password, Role Guard, Pending-Sync Wipe)', () {
    testWidgets('BUKTI 1 (E01): Login 200 via UI saves tokens and navigates to HomeScreen',
        (WidgetTester tester) async {
      final router = AppRouter.createRouter(authRepository);

      await tester.pumpWidget(PayrollProApp(router: router));
      await tester.pumpAndSettle();

      // Verify on LoginScreen initially
      expect(find.byKey(AppKeys.loginEmail), findsOneWidget);
      expect(find.byKey(AppKeys.loginPassword), findsOneWidget);
      expect(find.byKey(AppKeys.loginSubmit), findsOneWidget);

      // Enter credentials
      await tester.enterText(find.byKey(AppKeys.loginEmail), 'sinta@payrollpro.com');
      await tester.enterText(find.byKey(AppKeys.loginPassword), 'password123');
      await tester.tap(find.byKey(AppKeys.loginSubmit));
      await tester.pumpAndSettle();

      // Verify authenticated & tokens saved
      expect(authRepository.isAuthenticated, isTrue);
      expect(authRepository.isEmployee, isTrue);
      expect(authRepository.currentUser?.email, 'sinta@payrollpro.com');
      expect(await fakeStorage.read(key: StorageKeys.accessToken), 'mock-access-token-jwt-12345');
      expect(await fakeStorage.read(key: StorageKeys.refreshToken), 'mock-refresh-token-jwt-67890');
      expect(await fakeStorage.read(key: StorageKeys.userId), 'usr-1111-2222');

      // Verify navigated to HomeScreen
      expect(find.byKey(AppKeys.homeScreen), findsOneWidget);
      expect(find.text('sinta@payrollpro.com'), findsOneWidget);
    });

    testWidgets('E01 failure: Login displays error banner when credentials invalid (401)',
        (WidgetTester tester) async {
      mockRemote.shouldFailLogin = true;
      final router = AppRouter.createRouter(authRepository);

      await tester.pumpWidget(PayrollProApp(router: router));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.loginEmail), 'wrong@payrollpro.com');
      await tester.enterText(find.byKey(AppKeys.loginPassword), 'wrongpassword');
      await tester.tap(find.byKey(AppKeys.loginSubmit));
      await tester.pumpAndSettle();

      expect(authRepository.isAuthenticated, isFalse);
      expect(find.byKey(AppKeys.loginError), findsOneWidget);
      expect(find.text('Email atau kata sandi tidak valid'), findsOneWidget);
    });

    testWidgets('BUKTI 2 (E02): Refresh-survive-restart restores authenticated session without re-login',
        (WidgetTester tester) async {
      await storageService.saveTokens(
        accessToken: 'initial-access-token',
        refreshToken: 'saved-refresh-token',
      );
      await storageService.saveUser(
        id: 'usr-persistent-1',
        email: 'dimas@payrollpro.com',
        role: 'employee',
        employeeId: 'emp-5555',
      );

      final restartedAuthRepo = AuthRepository(
        remoteDataSource: mockRemote,
        storageService: storageService,
        database: inMemoryDb,
      );

      final didRestore = await restartedAuthRepo.restoreSession();
      expect(didRestore, isTrue);
      expect(restartedAuthRepo.isAuthenticated, isTrue);
      expect(restartedAuthRepo.currentUser?.email, 'dimas@payrollpro.com');
      expect(restartedAuthRepo.currentUser?.employeeId, 'emp-5555');

      final router = AppRouter.createRouter(restartedAuthRepo);
      await tester.pumpWidget(PayrollProApp(router: router));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.homeScreen), findsOneWidget);
      expect(find.text('dimas@payrollpro.com'), findsOneWidget);
      expect(find.byKey(AppKeys.loginSubmit), findsNothing);

      final newTokens = await restartedAuthRepo.refreshSession();
      expect(newTokens.accessToken, 'mock-new-access-token');
      expect(restartedAuthRepo.accessToken, 'mock-new-access-token');
      expect(mockRemote.refreshCallCount, 1);
    });

    testWidgets('BUKTI 3 (E07): Logout-wipe clears all tokens, revokes device token, and wipes storage',
        (WidgetTester tester) async {
      await authRepository.login('sinta@payrollpro.com', 'password123');
      final router = AppRouter.createRouter(authRepository);

      await tester.pumpWidget(PayrollProApp(router: router));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.homeScreen), findsOneWidget);

      await tester.tap(find.byKey(AppKeys.logoutSubmit));
      await tester.pumpAndSettle();

      expect(mockRemote.logoutCalled, isTrue);
      expect(mockRemote.deleteDeviceTokenCalled, isTrue);
      expect(authRepository.isAuthenticated, isFalse);
      expect(authRepository.currentUser, isNull);
      expect(authRepository.accessToken, isNull);

      expect(await fakeStorage.read(key: StorageKeys.accessToken), isNull);
      expect(await fakeStorage.read(key: StorageKeys.refreshToken), isNull);
      expect(await fakeStorage.read(key: StorageKeys.userId), isNull);
      expect(await fakeStorage.read(key: StorageKeys.userEmail), isNull);

      expect(find.byKey(AppKeys.loginSubmit), findsOneWidget);
      expect(find.byKey(AppKeys.homeScreen), findsNothing);
    });

    testWidgets('E07 Pending-Sync Modal: Shows confirmation dialog when PendingSyncs has unsynced items and wipes DB on confirm',
        (WidgetTester tester) async {
      await authRepository.login('sinta@payrollpro.com', 'password123');

      // Seed 1 pending sync item in Drift database
      await inMemoryDb.into(inMemoryDb.pendingSyncs).insert(
            PendingSyncsCompanion.insert(
              clientRequestId: 'req-offline-001',
              endpoint: '/api/attendance/check-in',
              payload: '{"latitude":-6.2,"longitude":106.8}',
            ),
          );
      expect(await authRepository.getPendingSyncCount(), 1);

      final router = AppRouter.createRouter(authRepository);
      await tester.pumpWidget(PayrollProApp(router: router));
      await tester.pumpAndSettle();

      // Tap logout -> modal must appear
      await tester.tap(find.byKey(AppKeys.logoutSubmit));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.logoutConfirmModal), findsOneWidget);
      expect(find.textContaining('Ada 1 antrean absensi/data offline'), findsOneWidget);

      // Tap Cancel -> stays logged in & preserves queue
      await tester.tap(find.byKey(AppKeys.logoutConfirmCancel));
      await tester.pumpAndSettle();
      expect(authRepository.isAuthenticated, isTrue);
      expect(await authRepository.getPendingSyncCount(), 1);

      // Tap logout again -> confirm proceed -> wipes Drift queue & logs out
      await tester.tap(find.byKey(AppKeys.logoutSubmit));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(AppKeys.logoutConfirmProceed));
      await tester.pumpAndSettle();

      expect(authRepository.isAuthenticated, isFalse);
      expect(await authRepository.getPendingSyncCount(), 0);
      expect(find.byKey(AppKeys.loginSubmit), findsOneWidget);
    });

    testWidgets('E03 Register: Happy path (201) redirects to login & duplicate email (409) shows error banner',
        (WidgetTester tester) async {
      final router = AppRouter.createRouter(authRepository);
      await tester.pumpWidget(PayrollProApp(router: router));
      await tester.pumpAndSettle();

      // Navigate from Login to Register
      await tester.tap(find.byKey(AppKeys.loginToRegister));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.registerEmail), findsOneWidget);

      // Test 409 duplicate email first
      mockRemote.shouldFailRegisterDuplicate = true;
      await tester.enterText(find.byKey(AppKeys.registerFullName), 'Budi Santoso');
      await tester.enterText(find.byKey(AppKeys.registerEmail), 'existing@payrollpro.com');
      await tester.enterText(find.byKey(AppKeys.registerPassword), 'password123');
      await tester.tap(find.byKey(AppKeys.registerSubmit));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.registerError), findsOneWidget);
      expect(find.text('Email sudah terdaftar'), findsOneWidget);

      // Test 201 success
      mockRemote.shouldFailRegisterDuplicate = false;
      await tester.enterText(find.byKey(AppKeys.registerEmail), 'budi.baru@payrollpro.com');
      await tester.tap(find.byKey(AppKeys.registerSubmit));
      await tester.pumpAndSettle();

      // Redirected back to /login
      expect(find.byKey(AppKeys.loginSubmit), findsOneWidget);
    });

    testWidgets('E04 & E05 Forgot & Reset Password: Anti-enumeration banner and token reset flow',
        (WidgetTester tester) async {
      final router = AppRouter.createRouter(authRepository);
      await tester.pumpWidget(PayrollProApp(router: router));
      await tester.pumpAndSettle();

      // Navigate to Forgot Password
      await tester.tap(find.byKey(AppKeys.loginToForgot));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.forgotEmail), 'anyone@payrollpro.com');
      await tester.tap(find.byKey(AppKeys.forgotSubmit));
      await tester.pumpAndSettle();

      // Verify anti-enumeration banner
      expect(find.byKey(AppKeys.forgotSuccessBanner), findsOneWidget);
      expect(
        find.text('Jika email terdaftar, link reset password sudah dikirim ke inbox Anda.'),
        findsOneWidget,
      );

      // Navigate to Reset Password screen
      await tester.tap(find.byKey(AppKeys.forgotToReset));
      await tester.pumpAndSettle();

      // Failure: invalid/expired token (400)
      mockRemote.shouldFailResetToken = true;
      await tester.enterText(find.byKey(AppKeys.resetToken), 'expired-token');
      await tester.enterText(find.byKey(AppKeys.resetNewPassword), 'newpass123');
      await tester.tap(find.byKey(AppKeys.resetSubmit));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.resetError), findsOneWidget);
      expect(find.text('Token tidak valid atau sudah kedaluwarsa.'), findsOneWidget);

      // Happy path: valid token (200)
      mockRemote.shouldFailResetToken = false;
      await tester.enterText(find.byKey(AppKeys.resetToken), 'valid-reset-token-123');
      await tester.tap(find.byKey(AppKeys.resetSubmit));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.resetSuccessBanner), findsOneWidget);
      expect(
        find.text('Password berhasil direset. Silakan login dengan password baru.'),
        findsOneWidget,
      );
    });

    testWidgets('E06 / Role Guard: Non-employee role (manager / hr_admin) is blocked with "Gunakan versi web"',
        (WidgetTester tester) async {
      mockRemote.loginRole = 'manager';
      final router = AppRouter.createRouter(authRepository);

      await tester.pumpWidget(PayrollProApp(router: router));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(AppKeys.loginEmail), 'manager@payrollpro.com');
      await tester.enterText(find.byKey(AppKeys.loginPassword), 'password123');
      await tester.tap(find.byKey(AppKeys.loginSubmit));
      await tester.pumpAndSettle();

      // Must NOT show HomeScreen; must show NonEmployeeScreen with "Gunakan versi web"
      expect(find.byKey(AppKeys.homeScreen), findsNothing);
      expect(find.byKey(AppKeys.nonEmployeeScreen), findsOneWidget);
      expect(find.text('Gunakan versi web'), findsOneWidget);

      // Logout button from NonEmployeeScreen works and returns to LoginScreen
      await tester.tap(find.byKey(AppKeys.nonEmployeeLogoutButton));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.loginSubmit), findsOneWidget);
    });

    testWidgets('E06 fetchMe: Syncs profile and blocks if /api/auth/me returns non-employee role',
        (WidgetTester tester) async {
      await authRepository.login('sinta@payrollpro.com', 'password123');
      final router = AppRouter.createRouter(authRepository);

      await tester.pumpWidget(PayrollProApp(router: router));
      await tester.pumpAndSettle();
      expect(find.byKey(AppKeys.homeScreen), findsOneWidget);

      // Server updates role to hr_admin on /api/auth/me
      mockRemote.meRole = 'hr_admin';
      await authRepository.fetchMe();
      await tester.pumpAndSettle();

      expect(authRepository.isEmployee, isFalse);
      expect(find.byKey(AppKeys.nonEmployeeScreen), findsOneWidget);
      expect(find.text('Gunakan versi web'), findsOneWidget);
    });

    testWidgets('E08 Change Password (/profile/password): Sends currentPassword & newPassword, handles 401 & 200',
        (WidgetTester tester) async {
      await authRepository.login('sinta@payrollpro.com', 'password123');
      final router = AppRouter.createRouter(authRepository);

      await tester.pumpWidget(PayrollProApp(router: router));
      await tester.pumpAndSettle();

      // Navigate to /profile/password from HomeScreen
      await tester.tap(find.byKey(AppKeys.homeToChangePassword));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.changeCurrentPassword), findsOneWidget);
      expect(find.byKey(AppKeys.changeNewPassword), findsOneWidget);

      // Test 401 wrong current password
      mockRemote.shouldFailCurrentPassword = true;
      await tester.enterText(find.byKey(AppKeys.changeCurrentPassword), 'wrongoldpass');
      await tester.enterText(find.byKey(AppKeys.changeNewPassword), 'newsecure123');
      await tester.tap(find.byKey(AppKeys.changePasswordSubmit));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.changePasswordError), findsOneWidget);
      expect(find.text('Password saat ini salah'), findsOneWidget);

      // Test 200 success
      mockRemote.shouldFailCurrentPassword = false;
      await tester.enterText(find.byKey(AppKeys.changeCurrentPassword), 'password123');
      await tester.enterText(find.byKey(AppKeys.changeNewPassword), 'newsecure123');
      await tester.tap(find.byKey(AppKeys.changePasswordSubmit));
      await tester.pumpAndSettle();

      expect(find.byKey(AppKeys.changePasswordSuccess), findsOneWidget);
      expect(find.text('Password berhasil diubah'), findsOneWidget);
      expect(mockRemote.lastChangePasswordArgs, {
        'currentPassword': 'password123',
        'newPassword': 'newsecure123',
      });
    });
  });
}

