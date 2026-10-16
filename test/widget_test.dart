import 'package:flutter_test/flutter_test.dart';
import 'package:payrollpro/core/constants/app_keys.dart';
import 'package:payrollpro/core/router/app_router.dart';
import 'package:payrollpro/core/storage/secure_storage_service.dart';
import 'package:payrollpro/features/auth/data/auth_repository.dart';
import 'package:payrollpro/main.dart';
import 'features/auth/auth_flow_test.dart';
import 'helpers/fake_secure_storage.dart';

void main() {
  testWidgets('PayrollPro smoke test: boots to login screen with semantic keys',
      (WidgetTester tester) async {
    final fakeStorage = FakeSecureStorage();
    final storageService = SecureStorageService(storage: fakeStorage);
    final mockRemote = MockAuthRemoteDataSource();
    final authRepository = AuthRepository(
      remoteDataSource: mockRemote,
      storageService: storageService,
    );

    await authRepository.restoreSession();
    final router = AppRouter.createRouter(authRepository);

    await tester.pumpWidget(PayrollProApp(router: router));
    await tester.pumpAndSettle();

    // Verify login screen elements with semantic keys (Planning/05 §3)
    expect(find.byKey(AppKeys.loginEmail), findsOneWidget);
    expect(find.byKey(AppKeys.loginPassword), findsOneWidget);
    expect(find.byKey(AppKeys.loginSubmit), findsOneWidget);
  });
}
