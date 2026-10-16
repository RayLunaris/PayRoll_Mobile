import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payrollpro/core/constants/app_keys.dart';
import 'package:payrollpro/core/database/app_database.dart';
import 'package:payrollpro/core/network/api_exception.dart';
import 'package:payrollpro/core/router/app_router.dart';
import 'package:payrollpro/core/storage/secure_storage_service.dart';
import 'package:payrollpro/features/attendance/data/attendance_remote_datasource.dart';
import 'package:payrollpro/features/attendance/data/attendance_repository.dart';
import 'package:payrollpro/features/attendance/models/attendance_model.dart';
import 'package:payrollpro/features/attendance/models/today_summary_model.dart';
import 'package:payrollpro/features/attendance/models/weekly_stat_model.dart';
import 'package:payrollpro/features/attendance/models/work_location_model.dart';
import 'package:payrollpro/features/auth/data/auth_remote_datasource.dart';
import 'package:payrollpro/features/auth/data/auth_repository.dart';
import 'package:payrollpro/features/auth/models/auth_tokens.dart';
import 'package:payrollpro/features/auth/models/login_response.dart';
import 'package:payrollpro/features/auth/models/user_model.dart';
import 'package:payrollpro/main.dart';
import 'package:payrollpro/shared/widgets/payroll_cta_button.dart';
import 'package:payrollpro/shared/widgets/sync_badge.dart';

import '../../helpers/fake_secure_storage.dart';

class FakeAuthRemoteForJ2 implements AuthRemoteDataSource {
  @override
  Future<LoginResponse> login(String email, String password) async {
    return LoginResponse(
      tokens: AuthTokens(accessToken: 'jwt-acc', refreshToken: 'jwt-ref'),
      user: UserModel(
        id: '11111111-1111-4111-8111-111111111111',
        email: email,
        role: 'employee',
        employeeId: '22222222-2222-4222-8222-222222222222',
      ),
    );
  }

  @override
  Future<AuthTokens> refreshToken(String refreshToken) async =>
      AuthTokens(accessToken: 'jwt-acc-2', refreshToken: 'jwt-ref-2');

  @override
  Future<UserModel> register({
    String? fullName,
    required String email,
    required String password,
  }) async => UserModel(id: 'u1', email: email, role: 'employee');

  @override
  Future<String> forgotPassword(String email) async => 'ok';

  @override
  Future<String> resetPassword({
    required String token,
    required String newPassword,
  }) async => 'ok';

  @override
  Future<UserModel> getMe() async => UserModel(
    id: '11111111-1111-4111-8111-111111111111',
    email: 'sinta@payrollpro.com',
    role: 'employee',
    employeeId: '22222222-2222-4222-8222-222222222222',
  );

  @override
  Future<void> logout() async {}

  @override
  Future<void> deleteDeviceToken({String? fcmToken}) async {}

  @override
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => 'ok';
}

class MockAttendanceRemoteDataSource implements AttendanceRemoteDataSource {
  static const String ownEmployeeId = '22222222-2222-4222-8222-222222222222';
  static const String hqLocationId = '33333333-3333-4333-8333-333333333333';
  static const String branchLocationId = '44444444-4444-4444-8444-444444444444';

  bool isOffline = false;
  bool simulateLostResponseAfterServerSave = false;
  AttendanceModel? serverTodayRecord;
  double? lastSentCheckInAccuracy;
  double? lastSentCheckOutAccuracy;

  final List<WorkLocationModel> mockLocations = [
    WorkLocationModel(
      id: hqLocationId,
      name: 'Kantor Pusat Jakarta',
      address: 'Jl. Sudirman No. 1',
      latitude: -6.2088,
      longitude: 106.8456,
      radiusMeters: 100,
    ),
    WorkLocationModel(
      id: branchLocationId,
      name: 'Pabrik Cikarang',
      address: 'Kawasan Industri Jababeka',
      latitude: -6.2845,
      longitude: 107.1705,
      radiusMeters: 150,
    ),
  ];

  @override
  Future<List<WorkLocationModel>> getLocations() async {
    if (isOffline) {
      throw ApiException(message: 'Network error', isNetworkError: true);
    }
    return mockLocations;
  }

  @override
  Future<AttendanceModel> checkIn({
    required double latitude,
    required double longitude,
    required double accuracy,
    required String locationId,
    String? photoUrl,
    String? employeeId,
  }) async {
    lastSentCheckInAccuracy = accuracy;

    if (employeeId != null && employeeId != ownEmployeeId) {
      throw ApiException(
        statusCode: 403,
        error: 'Forbidden: Cannot check-in for another employee',
        message: 'Forbidden: Cannot check-in for another employee',
      );
    }

    if (isOffline) {
      throw ApiException(message: 'Offline connection', isNetworkError: true);
    }

    // Server accuracy check (>100m -> 400)
    if (accuracy > 100) {
      throw ApiException(
        statusCode: 400,
        error: 'Low GPS accuracy',
        message:
            'Akurasi GPS (±${accuracy.round()}m) tidak memenuhi syarat (maksimal 100m).',
        rawData: {'accuracy': accuracy, 'error': 'Low GPS accuracy'},
      );
    }

    final loc = mockLocations.firstWhere(
      (l) => l.id == locationId,
      orElse: () => mockLocations.first,
    );
    final dist = loc.distanceFrom(latitude, longitude).round();
    if (dist > loc.radiusMeters) {
      throw ApiException(
        statusCode: 400,
        error: 'Outside work area',
        message: 'Outside work area',
        rawData: {
          'error': 'Outside work area',
          'distance': dist,
          'radius': loc.radiusMeters,
          'accuracy': accuracy,
        },
      );
    }

    if (serverTodayRecord != null && serverTodayRecord!.isCheckedIn) {
      throw ApiException(
        statusCode: 400,
        error: 'Already checked in today',
        message: 'Already checked in today',
      );
    }

    final created = AttendanceModel(
      id: 'att-today-001',
      employeeId: ownEmployeeId,
      locationId: locationId,
      date: '2026-10-16',
      checkIn: DateTime.parse('2026-10-16T08:00:00Z'),
      status: 'present',
      checkInPhotoUrl: photoUrl,
      locationName: loc.name,
      distance: dist,
    );
    serverTodayRecord = created;

    if (simulateLostResponseAfterServerSave) {
      simulateLostResponseAfterServerSave = false;
      throw ApiException(
        message: 'Socket closed before response received',
        isNetworkError: true,
      );
    }

    return created;
  }

  @override
  Future<AttendanceModel> checkOut({
    required double latitude,
    required double longitude,
    required double accuracy,
    String? employeeId,
  }) async {
    lastSentCheckOutAccuracy = accuracy;

    if (employeeId != null && employeeId != ownEmployeeId) {
      throw ApiException(
        statusCode: 403,
        error: 'Forbidden: Cannot check-out for another employee',
        message: 'Forbidden: Cannot check-out for another employee',
      );
    }

    if (isOffline) {
      throw ApiException(message: 'Offline connection', isNetworkError: true);
    }

    // B3: Server accuracy check on check-out (>100m -> 400)
    if (accuracy > 100) {
      throw ApiException(
        statusCode: 400,
        error: 'Low GPS accuracy',
        message:
            'Akurasi GPS (±${accuracy.round()}m) tidak memenuhi syarat (maksimal 100m).',
        rawData: {'accuracy': accuracy, 'error': 'Low GPS accuracy'},
      );
    }

    if (serverTodayRecord == null || !serverTodayRecord!.isCheckedIn) {
      throw ApiException(
        statusCode: 400,
        error: 'No check-in found for today',
        message: 'No check-in found for today',
      );
    }

    if (serverTodayRecord!.isCheckedOut) {
      throw ApiException(
        statusCode: 400,
        error: 'Already checked out today',
        message: 'Already checked out today',
      );
    }

    final loc = mockLocations.firstWhere(
      (l) => l.id == serverTodayRecord!.locationId,
      orElse: () => mockLocations.first,
    );
    final dist = loc.distanceFrom(latitude, longitude).round();
    if (dist > loc.radiusMeters) {
      throw ApiException(
        statusCode: 400,
        error: 'Outside work area',
        message: 'Outside work area',
        rawData: {
          'error': 'Outside work area',
          'distance': dist,
          'radius': loc.radiusMeters,
          'accuracy': accuracy,
        },
      );
    }

    final updated = AttendanceModel(
      id: serverTodayRecord!.id,
      employeeId: ownEmployeeId,
      locationId: serverTodayRecord!.locationId,
      date: serverTodayRecord!.date,
      checkIn: serverTodayRecord!.checkIn,
      checkOut: DateTime.parse('2026-10-16T17:05:00Z'),
      status: serverTodayRecord!.status,
      overtimeHours: 0.0,
      locationName: loc.name,
    );
    serverTodayRecord = updated;

    if (simulateLostResponseAfterServerSave) {
      simulateLostResponseAfterServerSave = false;
      throw ApiException(
        message: 'Socket closed before response received',
        isNetworkError: true,
      );
    }

    return updated;
  }

  @override
  Future<AttendanceModel?> getToday({String? employeeId}) async {
    if (employeeId != null) {
      throw ApiException(
        statusCode: 403,
        error: 'Forbidden: Karyawan tidak diizinkan menggunakan parameter employeeId',
        message: 'Forbidden: Karyawan tidak diizinkan menggunakan parameter employeeId',
      );
    }
    if (isOffline) {
      throw ApiException(message: 'Offline', isNetworkError: true);
    }
    return serverTodayRecord;
  }

  @override
  Future<List<AttendanceModel>> getHistory({
    int? page,
    int? limit,
    String? startDate,
    String? endDate,
    String? employeeId,
  }) async {
    if (employeeId != null) {
      throw ApiException(
        statusCode: 403,
        error: 'Forbidden: Karyawan tidak diizinkan menggunakan parameter employeeId',
        message: 'Forbidden: Karyawan tidak diizinkan menggunakan parameter employeeId',
      );
    }
    return [
      if (serverTodayRecord != null) serverTodayRecord!,
      AttendanceModel(
        id: 'att-prev-001',
        employeeId: ownEmployeeId,
        locationId: hqLocationId,
        date: '2026-10-15',
        checkIn: DateTime.parse('2026-10-15T07:55:00Z'),
        checkOut: DateTime.parse('2026-10-15T17:10:00Z'),
        status: 'present',
        overtimeHours: 0.0,
        locationName: 'Kantor Pusat Jakarta',
      ),
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getReport({int? month, int? year}) async {
    return [
      {
        'employeeId': ownEmployeeId,
        'totalDays': 22,
        'presentDays': 20,
        'lateDays': 1,
        'absentDays': 1,
        'totalOvertime': 2.5,
      },
    ];
  }

  @override
  Future<List<WeeklyStatModel>> getWeeklyStats() async {
    return [
      WeeklyStatModel(
        date: 'Sen',
        fullDate: '2026-10-12',
        present: 1,
        late: 0,
        absent: 0,
      ),
      WeeklyStatModel(
        date: 'Sel',
        fullDate: '2026-10-13',
        present: 1,
        late: 0,
        absent: 0,
      ),
    ];
  }

  @override
  Future<TodaySummaryModel> getTodaySummary() async {
    // Simulates raw JSON containing extra fields to prove TodaySummaryModel only retains isSelfCheckedIn
    final rawJson = <String, dynamic>{
      'presentCount': 42,
      'totalCount': 50,
      'isSelfCheckedIn': serverTodayRecord?.isCheckedIn ?? false,
      'checkedInEmployees': [
        {'name': 'Leak PII Should Be Ignored'},
      ],
    };
    return TodaySummaryModel.fromJson(rawJson);
  }
}

void main() {
  late FakeSecureStorage fakeStorage;
  late SecureStorageService storageService;
  late AppDatabase inMemoryDb;
  late AuthRepository authRepository;
  late MockAttendanceRemoteDataSource mockAttendanceRemote;
  late AttendanceRepository attendanceRepository;

  setUp(() async {
    fakeStorage = FakeSecureStorage();
    storageService = SecureStorageService(storage: fakeStorage);
    inMemoryDb = AppDatabase(NativeDatabase.memory());
    authRepository = AuthRepository(
      remoteDataSource: FakeAuthRemoteForJ2(),
      storageService: storageService,
      database: inMemoryDb,
    );
    mockAttendanceRemote = MockAttendanceRemoteDataSource();
    attendanceRepository = AttendanceRepository(
      remoteDataSource: mockAttendanceRemote,
      database: inMemoryDb,
    );

    await authRepository.login('sinta@payrollpro.com', 'password123');
  });

  tearDown(() async {
    await inMemoryDb.close();
  });

  group(
    'Patrol / Widget J2 Suite — Attendance E09-E14 (ATT-01..06 & IDOR)',
    () {
      testWidgets(
        '1. J2 Happy Path (ATT-01, E09-E14): Pilih lokasi -> selfie stub -> check-in (accuracy terkirim) -> check-out -> history & weekly-stats',
        (WidgetTester tester) async {
          final router = AppRouter.createRouter(
            authRepository,
            attendanceRepository: attendanceRepository,
          );

          await tester.pumpWidget(PayrollProApp(router: router));
          await tester.pumpAndSettle();

          // Navigate from HomeScreen to AttendanceScreen
          expect(find.byKey(AppKeys.homeTodaySummaryCard), findsOneWidget);
          await tester.tap(find.byKey(AppKeys.homeToAttendance));
          await tester.pumpAndSettle();

          expect(find.byKey(AppKeys.attendanceScreen), findsOneWidget);
          expect(find.byKey(AppKeys.gpsStatusCard), findsOneWidget);
          expect(find.byKey(AppKeys.locationDropdown), findsOneWidget);
          expect(find.byKey(AppKeys.selfieStubToggle), findsOneWidget);

          // Position is inside Kantor Pusat Jakarta (-6.2088, 106.8456, accuracy 15m)
          attendanceRepository.updateGpsPosition(
            latitude: -6.2088,
            longitude: 106.8456,
            accuracy: 15.0,
          );
          await tester.pumpAndSettle();

          expect(find.text('0 m'), findsOneWidget);
          expect(find.text('±15m (Maks 100m)'), findsOneWidget);

          // Tap Check-In CTA
          await tester.ensureVisible(find.byKey(AppKeys.checkinSubmit));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(AppKeys.checkinSubmit));
          await tester.pumpAndSettle();

          // Verify accuracy was ALWAYS sent in POST /api/attendance/check-in
          expect(mockAttendanceRemote.lastSentCheckInAccuracy, 15.0);
          expect(attendanceRepository.todayAttendance?.isCheckedIn, isTrue);
          expect(attendanceRepository.todaySummary?.isSelfCheckedIn, isTrue);
          expect(attendanceRepository.syncStatus, SyncStatus.synced);
          expect(find.byKey(AppKeys.attendanceStatusBanner), findsOneWidget);
          expect(
            find.text('Check-in berhasil tercatat di server.'),
            findsOneWidget,
          );

          // Tap Check-Out CTA
          attendanceRepository.updateGpsPosition(
            latitude: -6.2088,
            longitude: 106.8456,
            accuracy: 18.0,
          );
          await tester.pumpAndSettle();

          await tester.ensureVisible(find.byKey(AppKeys.checkoutSubmit));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(AppKeys.checkoutSubmit));
          await tester.pumpAndSettle();

          // Verify accuracy was ALWAYS sent in POST /api/attendance/check-out
          expect(mockAttendanceRemote.lastSentCheckOutAccuracy, 18.0);
          expect(attendanceRepository.todayAttendance?.isCheckedOut, isTrue);
          expect(
            find.text('Check-out berhasil tercatat di server.'),
            findsOneWidget,
          );

          // Navigate to History Screen (E13 history + weekly-stats)
          await tester.tap(find.byKey(AppKeys.attendanceToHistory));
          await tester.pumpAndSettle();

          expect(find.byKey(AppKeys.attendanceHistoryScreen), findsOneWidget);
          expect(find.byKey(AppKeys.attendanceHistoryList), findsOneWidget);
          expect(find.text('Statistik Mingguan Saya'), findsOneWidget);
          expect(find.text('2026-10-15'), findsOneWidget);
        },
      );

      testWidgets(
        '2. J2 Outside Radius (ATT-02): Menolak check-in di luar radius kerja & menampilkan jarak aktual + batas radius',
        (WidgetTester tester) async {
          final router = AppRouter.createRouter(
            authRepository,
            attendanceRepository: attendanceRepository,
          );

          await tester.pumpWidget(PayrollProApp(router: router));
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(AppKeys.homeToAttendance));
          await tester.pumpAndSettle();

          // Move 350m away from Kantor Pusat Jakarta (outside 100m radius)
          attendanceRepository.updateGpsPosition(
            latitude: -6.2120,
            longitude: 106.8456,
            accuracy: 12.0,
          );
          await tester.pumpAndSettle();

          expect(find.textContaining('Di Luar Radius Kerja'), findsOneWidget);

          await tester.tap(find.byKey(AppKeys.checkinSubmit));
          await tester.pumpAndSettle();

          expect(find.byKey(AppKeys.attendanceErrorBanner), findsOneWidget);
          expect(
            find.textContaining('Di luar area kerja: jarak Anda'),
            findsOneWidget,
          );
          expect(find.textContaining('(maksimal 100m)'), findsOneWidget);
          expect(attendanceRepository.todayAttendance, isNull);
        },
      );

      testWidgets(
        '3. J2 Low Accuracy (ATT-06 & B3): Pre-check >100m memblokir tombol di UI + menangani 400 Low GPS accuracy dari server',
        (WidgetTester tester) async {
          final router = AppRouter.createRouter(
            authRepository,
            attendanceRepository: attendanceRepository,
          );

          await tester.pumpWidget(PayrollProApp(router: router));
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(AppKeys.homeToAttendance));
          await tester.pumpAndSettle();

          // Set GPS accuracy = 145m (> 100m threshold)
          attendanceRepository.updateGpsPosition(
            latitude: -6.2088,
            longitude: 106.8456,
            accuracy: 145.0,
          );
          await tester.pumpAndSettle();

          // Verify UI pre-check blocks Check-In button
          final checkInButton = tester.widget<PayrollCtaButton>(
            find.byWidgetPredicate(
              (w) =>
                  w is PayrollCtaButton && w.buttonKey == AppKeys.checkinSubmit,
            ),
          );
          expect(checkInButton.onPressed, isNull);
          expect(
            find.textContaining('Akurasi GPS (±145m) melebihi batas 100m'),
            findsOneWidget,
          );

          // Also test server 400 Low GPS accuracy handling on both Check-In and Check-Out
          final resIn = await attendanceRepository.submitCheckIn(
            bypassClientAccuracyPreCheck: true,
          );
          await tester.pumpAndSettle();
          expect(resIn, isFalse);
          expect(find.byKey(AppKeys.attendanceErrorBanner), findsOneWidget);
          expect(
            find.textContaining(
              'Akurasi GPS (±145m) tidak memenuhi syarat (maksimal 100m)',
            ),
            findsOneWidget,
          );

          // Test B3 check-out server 400 Low GPS accuracy handling
          final resOut = await attendanceRepository.submitCheckOut(
            bypassClientAccuracyPreCheck: true,
          );
          await tester.pumpAndSettle();
          expect(resOut, isFalse);
          expect(
            find.textContaining(
              'Akurasi GPS (±145m) tidak memenuhi syarat (maksimal 100m)',
            ),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        '4. J2 Offline Queue (ATT-03): Saat offline disimpan ke Drift PendingSyncs dengan clientRequestId UUID & tampil Menunggu Sinkronisasi (BUKAN success)',
        (WidgetTester tester) async {
          final router = AppRouter.createRouter(
            authRepository,
            attendanceRepository: attendanceRepository,
          );

          await tester.pumpWidget(PayrollProApp(router: router));
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(AppKeys.homeToAttendance));
          await tester.pumpAndSettle();

          // Go offline before tapping check-in
          mockAttendanceRemote.isOffline = true;
          await tester.tap(find.byKey(AppKeys.checkinSubmit));
          await tester.pumpAndSettle();

          // Verify NOT marked as synced/success; must be pendingSync
          expect(attendanceRepository.syncStatus, SyncStatus.pendingSync);
          expect(attendanceRepository.pendingSyncCount, 1);
          expect(find.text('Menunggu Sinkronisasi (1)'), findsOneWidget);
          expect(
            find.text('Check-in berhasil tercatat di server.'),
            findsNothing,
          );
          expect(
            find.textContaining(
              'Koneksi offline. Data disimpan dalam antrean lokal',
            ),
            findsOneWidget,
          );

          // Verify Drift PendingSyncs row has a valid UUID v4 clientRequestId and accuracy in payload
          final queuedItems = await inMemoryDb.getPendingSyncItems();
          expect(queuedItems.length, 1);
          expect(queuedItems.first.clientRequestId.length, 36);
          final payloadMap =
              jsonDecode(queuedItems.first.payload) as Map<String, dynamic>;
          expect(payloadMap['accuracy'], 12.0);
          expect(
            payloadMap['clientRequestId'],
            queuedItems.first.clientRequestId,
          );

          // Reconnect online and tap retry on SyncBadge
          mockAttendanceRemote.isOffline = false;
          await tester.tap(find.byKey(AppKeys.syncRetryButton));
          await tester.pumpAndSettle();

          expect(attendanceRepository.syncStatus, SyncStatus.synced);
          expect(attendanceRepository.pendingSyncCount, 0);
          expect(attendanceRepository.todayAttendance?.isCheckedIn, isTrue);
          expect(find.text('Terkirim'), findsOneWidget);
        },
      );

      testWidgets(
        '5. J2 Race Respons-Hilang (ATT-04): Server simpan check-in tapi respons putus -> retry dapat 400 Already checked in today -> rekonsiliasi GET /today = synced',
        (WidgetTester tester) async {
          final router = AppRouter.createRouter(
            authRepository,
            attendanceRepository: attendanceRepository,
          );

          await tester.pumpWidget(PayrollProApp(router: router));
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(AppKeys.homeToAttendance));
          await tester.pumpAndSettle();

          // Simulate race condition: server saves the check-in record, but network drops before client receives 201
          mockAttendanceRemote.simulateLostResponseAfterServerSave = true;
          await tester.tap(find.byKey(AppKeys.checkinSubmit));
          await tester.pumpAndSettle();

          // Client queued the request as pending_sync because response was lost
          expect(attendanceRepository.syncStatus, SyncStatus.pendingSync);
          expect(attendanceRepository.pendingSyncCount, 1);
          // Meanwhile server ALREADY has the checkIn record!
          expect(mockAttendanceRemote.serverTodayRecord?.isCheckedIn, isTrue);

          // Client retries sync -> server throws 400 'Already checked in today' -> client reconciles via GET /today -> synced!
          await tester.tap(find.byKey(AppKeys.syncRetryButton));
          await tester.pumpAndSettle();

          expect(attendanceRepository.syncStatus, SyncStatus.synced);
          expect(attendanceRepository.pendingSyncCount, 0);
          expect(attendanceRepository.errorMessage, isNull);
          expect(attendanceRepository.todayAttendance?.isCheckedIn, isTrue);
          expect(
            find.text('Terekonsiliasi dengan server (Terkirim).'),
            findsOneWidget,
          );
        },
      );

      test('6. IDOR Protection (Planning/01 §13 & 03-H4): Akses check-in/out/today/history dengan employeeId orang lain ditolak 403', () async {
        const otherEmployeeId = '99999999-9999-4999-8999-999999999999';

        // 1. GET /api/attendance/today?employeeId=other -> 403
        expect(
          () => attendanceRepository.fetchToday(employeeId: otherEmployeeId),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403),
          ),
        );

        // 2. GET /api/attendance/history?employeeId=other -> 403
        expect(
          () => attendanceRepository.fetchHistoryAndStats(
            employeeId: otherEmployeeId,
          ),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403),
          ),
        );

        // 3. POST /api/attendance/check-in untuk employeeId lain -> 403
        await attendanceRepository.initializeAttendance();
        final okIn = await attendanceRepository.submitCheckIn(
          employeeId: otherEmployeeId,
        );
        expect(okIn, isFalse);
        expect(attendanceRepository.errorMessage, contains('Forbidden'));

        // 4. POST /api/attendance/check-out untuk employeeId lain -> 403
        final okOut = await attendanceRepository.submitCheckOut(
          employeeId: otherEmployeeId,
        );
        expect(okOut, isFalse);
        expect(attendanceRepository.errorMessage, contains('Forbidden'));
      });
    },
  );
}
