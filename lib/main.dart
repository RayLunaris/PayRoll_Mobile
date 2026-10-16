import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/database/app_database.dart';
import 'core/network/api_client.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/attendance/data/attendance_remote_datasource.dart';
import 'features/attendance/data/attendance_repository.dart';
import 'features/auth/data/auth_remote_datasource.dart';
import 'features/auth/data/auth_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = SecureStorageService();
  final database = AppDatabase();
  late final AuthRepository authRepository;

  final apiClient = ApiClient(
    storageService: storageService,
    onForceLogout: () {
      authRepository.logout();
    },
  );

  final remoteDataSource = AuthRemoteDataSourceImpl(dio: apiClient.dio);
  final attendanceRemote = AttendanceRemoteDataSourceImpl(dio: apiClient.dio);

  authRepository = AuthRepository(
    remoteDataSource: remoteDataSource,
    storageService: storageService,
    database: database,
  );

  final attendanceRepository = AttendanceRepository(
    remoteDataSource: attendanceRemote,
    database: database,
  );

  // Restore session from secure storage (survive restart)
  await authRepository.restoreSession();

  final router = AppRouter.createRouter(
    authRepository,
    attendanceRepository: attendanceRepository,
  );

  runApp(PayrollProApp(router: router));
}

class PayrollProApp extends StatelessWidget {
  final GoRouter router;

  const PayrollProApp({
    super.key,
    required this.router,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PayrollPro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
