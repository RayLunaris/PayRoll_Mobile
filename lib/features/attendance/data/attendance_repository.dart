import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/gps_status_card.dart';
import '../../../shared/widgets/sync_badge.dart';
import '../models/attendance_model.dart';
import '../models/today_summary_model.dart';
import '../models/weekly_stat_model.dart';
import '../models/work_location_model.dart';
import 'attendance_remote_datasource.dart';

class AttendanceRepository extends ChangeNotifier {
  final AttendanceRemoteDataSource remoteDataSource;
  final AppDatabase? database;

  List<WorkLocationModel> _locations = [];
  WorkLocationModel? _selectedLocation;
  AttendanceModel? _todayAttendance;
  TodaySummaryModel? _todaySummary;
  List<AttendanceModel> _history = [];
  List<WeeklyStatModel> _weeklyStats = [];

  // Default GPS state (simulated/injected for device & test)
  double _currentLatitude = -6.2088;
  double _currentLongitude = 106.8456;
  double _currentAccuracy = 12.0;
  bool _isGpsDenied = false;
  bool _hasSelfie = true;

  SyncStatus _syncStatus = SyncStatus.synced;
  int _pendingSyncCount = 0;
  bool _isLoading = false;
  String? _errorMessage;
  String? _statusMessage;

  AttendanceRepository({
    required this.remoteDataSource,
    this.database,
  });

  List<WorkLocationModel> get locations => _locations;
  WorkLocationModel? get selectedLocation => _selectedLocation;
  AttendanceModel? get todayAttendance => _todayAttendance;
  TodaySummaryModel? get todaySummary => _todaySummary;
  List<AttendanceModel> get history => _history;
  List<WeeklyStatModel> get weeklyStats => _weeklyStats;

  double get currentLatitude => _currentLatitude;
  double get currentLongitude => _currentLongitude;
  double get currentAccuracy => _currentAccuracy;
  bool get isGpsDenied => _isGpsDenied;
  bool get hasSelfie => _hasSelfie;

  SyncStatus get syncStatus => _syncStatus;
  int get pendingSyncCount => _pendingSyncCount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get statusMessage => _statusMessage;

  /// Client-side Haversine distance to selected work location in meters
  double get currentDistanceMeters {
    final loc = _selectedLocation;
    if (loc == null) return 0.0;
    return loc.distanceFrom(_currentLatitude, _currentLongitude);
  }

  /// Pre-check rule (ATT-06): accuracy > 100m is blocked in UI
  bool get isAccuracyValid => _currentAccuracy <= 100.0;

  /// Computes current GpsLockState for GpsStatusCard
  GpsLockState get gpsLockState {
    if (_isGpsDenied) return GpsLockState.denied;
    if (!isAccuracyValid) return GpsLockState.lowAccuracy;
    final loc = _selectedLocation;
    if (loc != null && currentDistanceMeters > loc.radiusMeters) {
      return GpsLockState.outside;
    }
    return GpsLockState.locked;
  }

  /// Updates current GPS coordinates & accuracy (used by GPS provider or test fixture)
  void updateGpsPosition({
    required double latitude,
    required double longitude,
    required double accuracy,
    bool isDenied = false,
  }) {
    _currentLatitude = latitude;
    _currentLongitude = longitude;
    _currentAccuracy = accuracy;
    _isGpsDenied = isDenied;
    notifyListeners();
  }

  void selectLocation(WorkLocationModel? location) {
    _selectedLocation = location;
    _errorMessage = null;
    notifyListeners();
  }

  void setSelfieCaptured(bool captured) {
    _hasSelfie = captured;
    notifyListeners();
  }

  /// Loads initial attendance state: E09 locations, E12 today, E14 today-summary, and pending queue count
  Future<void> initializeAttendance() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _refreshPendingCount();
      if (database != null) {
        await database!.purgeExpiredPendingSyncs(retentionDays: 30);
      }

      final results = await Future.wait([
        remoteDataSource.getLocations().catchError((_) => <WorkLocationModel>[]),
        remoteDataSource.getToday().catchError((_) => null),
        remoteDataSource
            .getTodaySummary()
            .catchError((_) => const TodaySummaryModel(isSelfCheckedIn: false)),
      ]);

      _locations = results[0] as List<WorkLocationModel>;
      if (_selectedLocation == null && _locations.isNotEmpty) {
        _selectedLocation = _locations.first;
      }
      _todayAttendance = results[1] as AttendanceModel?;
      _todaySummary = results[2] as TodaySummaryModel?;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// E09: Fetch work locations
  Future<List<WorkLocationModel>> fetchLocations() async {
    final locs = await remoteDataSource.getLocations();
    _locations = locs;
    if (_selectedLocation == null && _locations.isNotEmpty) {
      _selectedLocation = _locations.first;
    }
    notifyListeners();
    return locs;
  }

  /// E12: Fetch today's attendance (also supports IDOR verification when employeeId is passed)
  Future<AttendanceModel?> fetchToday({String? employeeId}) async {
    final today = await remoteDataSource.getToday(employeeId: employeeId);
    if (employeeId == null) {
      _todayAttendance = today;
      notifyListeners();
    }
    return today;
  }

  /// E13: Fetch attendance history & weekly stats
  Future<void> fetchHistoryAndStats({
    int? page,
    int? limit,
    String? startDate,
    String? endDate,
    String? employeeId,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final hist = await remoteDataSource.getHistory(
        page: page,
        limit: limit,
        startDate: startDate,
        endDate: endDate,
        employeeId: employeeId,
      );
      if (employeeId == null) {
        _history = hist;
        _weeklyStats = await remoteDataSource
            .getWeeklyStats()
            .catchError((_) => <WeeklyStatModel>[]);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// E14: Fetch today-summary (strictly exposes only isSelfCheckedIn)
  Future<TodaySummaryModel> fetchTodaySummary() async {
    final summary = await remoteDataSource.getTodaySummary();
    _todaySummary = summary;
    notifyListeners();
    return summary;
  }

  /// E10: Submit Check-In with GPS accuracy pre-check, offline queue, and race reconciliation
  Future<bool> submitCheckIn({
    String? photoUrl,
    String? employeeId,
    bool bypassClientAccuracyPreCheck = false,
  }) async {
    _errorMessage = null;
    _statusMessage = null;

    // 1. Pre-check accuracy > 100m in client (ATT-06)
    if (!bypassClientAccuracyPreCheck && _currentAccuracy > 100.0) {
      _errorMessage =
          'Akurasi GPS (±${_currentAccuracy.round()}m) tidak memenuhi syarat (maksimal 100m). Mohon pindah ke area terbuka.';
      notifyListeners();
      return false;
    }

    final locId = _selectedLocation?.id;
    if (locId == null || locId.isEmpty) {
      _errorMessage = 'Pilih lokasi kerja terlebih dahulu.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final record = await remoteDataSource.checkIn(
        latitude: _currentLatitude,
        longitude: _currentLongitude,
        accuracy: _currentAccuracy, // ALWAYS sent!
        locationId: locId,
        photoUrl: photoUrl ?? (_hasSelfie ? 'selfie://captured-stub.jpg' : null),
        employeeId: employeeId,
      );

      _todayAttendance = record;
      _todaySummary = const TodaySummaryModel(isSelfCheckedIn: true);
      _syncStatus = SyncStatus.synced;
      _statusMessage = 'Check-in berhasil tercatat di server.';
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      return await _handleAttendanceWriteError(
        exception: e,
        isCheckIn: true,
        endpoint: ApiEndpoints.attendanceCheckIn,
        payloadMap: {
          'latitude': _currentLatitude,
          'longitude': _currentLongitude,
          'accuracy': _currentAccuracy,
          'locationId': locId,
          if (photoUrl != null || _hasSelfie)
            'photoUrl': photoUrl ?? 'selfie://captured-stub.jpg',
        },
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// E11: Submit Check-Out with GPS accuracy pre-check, offline queue, and race reconciliation
  Future<bool> submitCheckOut({
    String? employeeId,
    bool bypassClientAccuracyPreCheck = false,
  }) async {
    _errorMessage = null;
    _statusMessage = null;

    // 1. Pre-check accuracy > 100m in client (B3 + ATT-06)
    if (!bypassClientAccuracyPreCheck && _currentAccuracy > 100.0) {
      _errorMessage =
          'Akurasi GPS (±${_currentAccuracy.round()}m) tidak memenuhi syarat (maksimal 100m). Mohon pindah ke area terbuka.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final record = await remoteDataSource.checkOut(
        latitude: _currentLatitude,
        longitude: _currentLongitude,
        accuracy: _currentAccuracy, // ALWAYS sent!
        employeeId: employeeId,
      );

      _todayAttendance = record;
      _syncStatus = SyncStatus.synced;
      _statusMessage = 'Check-out berhasil tercatat di server.';
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      return await _handleAttendanceWriteError(
        exception: e,
        isCheckIn: false,
        endpoint: ApiEndpoints.attendanceCheckOut,
        payloadMap: {
          'latitude': _currentLatitude,
          'longitude': _currentLongitude,
          'accuracy': _currentAccuracy,
        },
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _handleAttendanceWriteError({
    required ApiException exception,
    required bool isCheckIn,
    required String endpoint,
    required Map<String, dynamic> payloadMap,
    String? existingClientRequestId,
  }) async {
    // Case A: Offline / Network Disconnected -> Enqueue in Drift PendingSyncs (ATT-03)
    if (exception.isNetworkError) {
      final clientReqId = existingClientRequestId ?? _generateUuidV4();
      if (database != null && existingClientRequestId == null) {
        final fullPayload = {
          ...payloadMap,
          'clientRequestId': clientReqId,
          'deviceTime': DateTime.now().toIso8601String(),
        };
        await database!.enqueuePendingSync(
          clientRequestId: clientReqId,
          endpoint: endpoint,
          payload: jsonEncode(fullPayload),
        );
      }
      await _refreshPendingCount();
      _syncStatus = SyncStatus.pendingSync;
      // Honest offline state: NEVER claim "success" when offline!
      _statusMessage =
          'Koneksi offline. Data disimpan dalam antrean lokal (Menunggu Sinkronisasi).';
      _errorMessage = null;
      notifyListeners();
      return false;
    }

    final errCode = (exception.error ?? '').toLowerCase();
    final errMsg = exception.message.toLowerCase();

    // Case B: Race condition / Retry after server already saved (ATT-04)
    // "Already checked in today" or "Already checked out today" -> Reconcile via GET /api/attendance/today
    final isAlreadyCheckedIn =
        isCheckIn && (errCode.contains('already checked in') || errMsg.contains('already checked in'));
    final isAlreadyCheckedOut =
        !isCheckIn && (errCode.contains('already checked out') || errMsg.contains('already checked out'));

    if (exception.statusCode == 400 && (isAlreadyCheckedIn || isAlreadyCheckedOut)) {
      try {
        final reconciled = await remoteDataSource.getToday();
        final isVerifiedOnServer = isCheckIn
            ? (reconciled != null && reconciled.isCheckedIn)
            : (reconciled != null && reconciled.isCheckedOut);

        if (isVerifiedOnServer) {
          _todayAttendance = reconciled;
          _todaySummary = const TodaySummaryModel(isSelfCheckedIn: true);
          if (database != null && existingClientRequestId != null) {
            await database!.deleteSyncedItem(existingClientRequestId);
          }
          await _refreshPendingCount();
          _syncStatus = _pendingSyncCount > 0 ? SyncStatus.pendingSync : SyncStatus.synced;
          _statusMessage = 'Terekonsiliasi dengan server (Terkirim).';
          _errorMessage = null;
          notifyListeners();
          return true;
        }
      } catch (_) {}
    }

    // Case C: Outside allowed work location radius (ATT-02)
    if (exception.statusCode == 400 &&
        (errCode.contains('outside work area') || errMsg.contains('outside work area'))) {
      final dist = exception.distance ?? currentDistanceMeters.round();
      final rad = exception.radius ?? (_selectedLocation?.radiusMeters ?? 100);
      _errorMessage =
          'Di luar area kerja: jarak Anda ${dist}m dari kantor (maksimal ${rad}m).';
      if (existingClientRequestId != null && database != null) {
        await database!.updatePendingSyncStatus(existingClientRequestId, 'failed');
        _syncStatus = SyncStatus.failed;
      }
      notifyListeners();
      return false;
    }

    // Case D: Low GPS accuracy rejected by server (ATT-06 / B3)
    if (exception.statusCode == 400 &&
        (errCode.contains('low gps accuracy') || errMsg.contains('akurasi gps'))) {
      final acc = exception.accuracy ?? _currentAccuracy.round();
      _errorMessage =
          'Akurasi GPS (±${acc.round()}m) tidak memenuhi syarat (maksimal 100m). Mohon pindah ke area terbuka.';
      if (existingClientRequestId != null && database != null) {
        await database!.updatePendingSyncStatus(existingClientRequestId, 'failed');
        _syncStatus = SyncStatus.failed;
      }
      notifyListeners();
      return false;
    }

    // Case E: Other rejections (403 IDOR, 400 period locked, etc. - ATT-05)
    if (existingClientRequestId != null && database != null) {
      await database!.updatePendingSyncStatus(existingClientRequestId, 'failed');
      _syncStatus = SyncStatus.failed;
      _errorMessage = '${exception.message}. Silakan ajukan koreksi ke HRD.';
    } else {
      _errorMessage = exception.message;
    }
    notifyListeners();
    return false;
  }

  /// Replays all pending items in Drift PendingSyncs queue (ATT-03 & ATT-04)
  Future<void> syncPendingQueue() async {
    if (database == null) return;
    final items = await database!.getPendingSyncItems();
    if (items.isEmpty) {
      _pendingSyncCount = 0;
      _syncStatus = SyncStatus.synced;
      notifyListeners();
      return;
    }

    _syncStatus = SyncStatus.syncing;
    _errorMessage = null;
    notifyListeners();

    for (final item in items) {
      await database!.updatePendingSyncStatus(item.clientRequestId, 'syncing');
      final Map<String, dynamic> data =
          jsonDecode(item.payload) as Map<String, dynamic>;
      final isCheckIn = item.endpoint == ApiEndpoints.attendanceCheckIn;

      try {
        if (isCheckIn) {
          final record = await remoteDataSource.checkIn(
            latitude: (data['latitude'] as num).toDouble(),
            longitude: (data['longitude'] as num).toDouble(),
            accuracy: (data['accuracy'] as num).toDouble(),
            locationId: data['locationId'] as String,
            photoUrl: data['photoUrl'] as String?,
          );
          _todayAttendance = record;
          _todaySummary = const TodaySummaryModel(isSelfCheckedIn: true);
        } else {
          final record = await remoteDataSource.checkOut(
            latitude: (data['latitude'] as num).toDouble(),
            longitude: (data['longitude'] as num).toDouble(),
            accuracy: (data['accuracy'] as num).toDouble(),
          );
          _todayAttendance = record;
        }

        await database!.deleteSyncedItem(item.clientRequestId);
        _statusMessage = 'Antrean offline berhasil disinkronkan (Terkirim).';
      } on ApiException catch (e) {
        await _handleAttendanceWriteError(
          exception: e,
          isCheckIn: isCheckIn,
          endpoint: item.endpoint,
          payloadMap: data,
          existingClientRequestId: item.clientRequestId,
        );
      }
    }

    await _refreshPendingCount();
    if (_syncStatus != SyncStatus.failed) {
      _syncStatus =
          _pendingSyncCount > 0 ? SyncStatus.pendingSync : SyncStatus.synced;
    }
    notifyListeners();
  }

  Future<void> _refreshPendingCount() async {
    if (database == null) {
      _pendingSyncCount = 0;
      return;
    }
    _pendingSyncCount = await database!.getPendingSyncCount();
    if (_pendingSyncCount > 0 && _syncStatus == SyncStatus.synced) {
      _syncStatus = SyncStatus.pendingSync;
    }
  }

  static String _generateUuidV4() {
    final rng = math.Random();
    String hex(int digits) =>
        List.generate(digits, (_) => rng.nextInt(16).toRadixString(16)).join();
    final variant = (8 + rng.nextInt(4)).toRadixString(16);
    return '${hex(8)}-${hex(4)}-4${hex(3)}-$variant${hex(3)}-${hex(12)}';
  }
}
