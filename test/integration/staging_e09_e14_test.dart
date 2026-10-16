import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payrollpro/core/database/app_database.dart';
import 'package:payrollpro/core/network/api_client.dart';
import 'package:payrollpro/core/network/api_exception.dart';
import 'package:payrollpro/core/storage/secure_storage_service.dart';
import 'package:payrollpro/features/attendance/data/attendance_remote_datasource.dart';
import 'package:payrollpro/features/attendance/data/attendance_repository.dart';
import 'package:payrollpro/features/auth/data/auth_remote_datasource.dart';
import 'package:payrollpro/features/auth/data/auth_repository.dart';
import 'package:payrollpro/shared/widgets/sync_badge.dart';
import '../helpers/fake_secure_storage.dart';

void main() {
  group('E09-E14 Live Integration Test against Staging Gateway (:3001)', () {
    late FakeSecureStorage fakeStorage;
    late SecureStorageService storageService;
    late AppDatabase inMemoryDb;
    late ApiClient apiClient;
    late AuthRepository authRepository;
    late AttendanceRemoteDataSource attendanceRemote;
    late AttendanceRepository attendanceRepository;

    setUp(() async {
      fakeStorage = FakeSecureStorage();
      storageService = SecureStorageService(storage: fakeStorage);
      inMemoryDb = AppDatabase(NativeDatabase.memory());
      apiClient = ApiClient(
        baseUrl: 'http://127.0.0.1:3001',
        storageService: storageService,
      );
      final authRemote = AuthRemoteDataSourceImpl(dio: apiClient.dio);
      authRepository = AuthRepository(
        remoteDataSource: authRemote,
        storageService: storageService,
        database: inMemoryDb,
      );
      attendanceRemote = AttendanceRemoteDataSourceImpl(dio: apiClient.dio);
      attendanceRepository = AttendanceRepository(
        remoteDataSource: attendanceRemote,
        database: inMemoryDb,
      );

      await authRepository.login('sinta@payrollpro.com', 'password123');
    });

    tearDown(() async {
      await inMemoryDb.close();
    });

    test('1. E09 GET /api/locations: Memuat daftar lokasi kerja & menghitung jarak Haversine',
        () async {
      final locations = await attendanceRepository.fetchLocations();

      expect(locations, isNotEmpty);
      expect(locations.first.id, '33333333-3333-4333-8333-333333333333');
      expect(locations.first.name, 'Kantor Pusat Jakarta');
      expect(locations.first.radiusMeters, 100);
      expect(
        locations.first.distanceFrom(-6.2088, 106.8456),
        lessThan(1.0),
      );
    });

    test(
        '2. E10 & E11 Accuracy > 100m (ATT-06 & B3): Server menolak 400 Low GPS accuracy pada check-in & check-out',
        () async {
      await attendanceRepository.fetchLocations();
      attendanceRepository.updateGpsPosition(
        latitude: -6.2088,
        longitude: 106.8456,
        accuracy: 155.0,
      );

      // Check-in with accuracy 155m -> 400 Low GPS accuracy
      final okIn = await attendanceRepository.submitCheckIn(
        bypassClientAccuracyPreCheck: true,
      );
      expect(okIn, isFalse);
      expect(
        attendanceRepository.errorMessage,
        contains('Akurasi GPS (±155m) tidak memenuhi syarat (maksimal 100m)'),
      );

      // Check-out (B3) with accuracy 155m -> 400 Low GPS accuracy
      final okOut = await attendanceRepository.submitCheckOut(
        bypassClientAccuracyPreCheck: true,
      );
      expect(okOut, isFalse);
      expect(
        attendanceRepository.errorMessage,
        contains('Akurasi GPS (±155m) tidak memenuhi syarat (maksimal 100m)'),
      );
    });

    test(
        '3. E10 & E11 Outside Radius (ATT-02): Server menolak 400 Outside work area + mengembalikan jarak & batas radius',
        () async {
      await attendanceRepository.fetchLocations();
      // ~460m from Kantor Pusat Jakarta (-6.2088, 106.8456)
      attendanceRepository.updateGpsPosition(
        latitude: -6.2130,
        longitude: 106.8456,
        accuracy: 12.0,
      );

      final okIn = await attendanceRepository.submitCheckIn();
      expect(okIn, isFalse);
      expect(
        attendanceRepository.errorMessage,
        contains('Di luar area kerja: jarak Anda'),
      );
      expect(attendanceRepository.errorMessage, contains('(maksimal 100m)'));

      final okOut = await attendanceRepository.submitCheckOut();
      expect(okOut, isFalse);
      expect(
        attendanceRepository.errorMessage,
        contains('Di luar area kerja: jarak Anda'),
      );
    });

    test(
        '4. E10 + E12 Race Rekonsiliasi & E11 Check-Out 200: Already checked in -> GET /today = synced, lalu Check-Out 200',
        () async {
      await attendanceRepository.fetchLocations();
      attendanceRepository.updateGpsPosition(
        latitude: -6.2088,
        longitude: 106.8456,
        accuracy: 14.0,
      );

      // Staging mock DB already has today's check-in row -> returns 400 Already checked in today
      // Repository automatically reconciles via E12 GET /api/attendance/today -> marks synced!
      final okIn = await attendanceRepository.submitCheckIn();
      expect(okIn, isTrue);
      expect(attendanceRepository.syncStatus, SyncStatus.synced);
      expect(attendanceRepository.todayAttendance?.isCheckedIn, isTrue);

      // E11 POST /api/attendance/check-out -> 200 OK
      final okOut = await attendanceRepository.submitCheckOut();
      expect(okOut, isTrue);
      expect(attendanceRepository.todayAttendance?.isCheckedOut, isTrue);
    });

    test(
        '5. E13 History & Weekly-Stats + E14 Today-Summary (hanya isSelfCheckedIn)',
        () async {
      await attendanceRepository.fetchHistoryAndStats();
      expect(attendanceRepository.history, isNotEmpty);
      expect(attendanceRepository.weeklyStats.length, 7);

      final summary = await attendanceRepository.fetchTodaySummary();
      expect(summary.isSelfCheckedIn, isTrue);
    });

    test(
        '6. IDOR Protection Live (:3001): Employee kirim employeeId orang lain -> 403 Forbidden pada check-in, check-out, today, dan history',
        () async {
      await attendanceRepository.fetchLocations();
      const otherEmpUuid = '99999999-9999-4999-8999-999999999999';

      // GET /api/attendance/today?employeeId=... -> 403
      await expectLater(
        attendanceRemote.getToday(employeeId: otherEmpUuid),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403),
        ),
      );

      // GET /api/attendance/history?employeeId=... -> 403
      await expectLater(
        attendanceRemote.getHistory(employeeId: otherEmpUuid),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403),
        ),
      );

      // POST /api/attendance/check-in with other employeeId -> 403
      await expectLater(
        attendanceRemote.checkIn(
          latitude: -6.2088,
          longitude: 106.8456,
          accuracy: 10.0,
          locationId: '33333333-3333-4333-8333-333333333333',
          employeeId: otherEmpUuid,
        ),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403),
        ),
      );

      // POST /api/attendance/check-out with other employeeId -> 403
      await expectLater(
        attendanceRemote.checkOut(
          latitude: -6.2088,
          longitude: 106.8456,
          accuracy: 10.0,
          employeeId: otherEmpUuid,
        ),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });
  });
}
