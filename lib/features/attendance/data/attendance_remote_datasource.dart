import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../models/attendance_model.dart';
import '../models/today_summary_model.dart';
import '../models/weekly_stat_model.dart';
import '../models/work_location_model.dart';

abstract class AttendanceRemoteDataSource {
  /// E09: GET /api/locations
  Future<List<WorkLocationModel>> getLocations();

  /// E10: POST /api/attendance/check-in (accuracy is ALWAYS sent)
  Future<AttendanceModel> checkIn({
    required double latitude,
    required double longitude,
    required double accuracy,
    required String locationId,
    String? photoUrl,
    String? employeeId,
  });

  /// E11: POST /api/attendance/check-out (accuracy is ALWAYS sent)
  Future<AttendanceModel> checkOut({
    required double latitude,
    required double longitude,
    required double accuracy,
    String? employeeId,
  });

  /// E12: GET /api/attendance/today
  Future<AttendanceModel?> getToday({String? employeeId});

  /// E13: GET /api/attendance/history
  Future<List<AttendanceModel>> getHistory({
    int? page,
    int? limit,
    String? startDate,
    String? endDate,
    String? employeeId,
  });

  /// E13 (report): GET /api/attendance/report
  Future<List<Map<String, dynamic>>> getReport({int? month, int? year});

  /// E13 (weekly): GET /api/attendance/weekly-stats
  Future<List<WeeklyStatModel>> getWeeklyStats();

  /// E14: GET /api/attendance/today-summary (only isSelfCheckedIn is retained)
  Future<TodaySummaryModel> getTodaySummary();
}

class AttendanceRemoteDataSourceImpl implements AttendanceRemoteDataSource {
  final Dio dio;

  AttendanceRemoteDataSourceImpl({required this.dio});

  @override
  Future<List<WorkLocationModel>> getLocations() async {
    try {
      final response = await dio.get(ApiEndpoints.locations);
      if (response.statusCode == 200 && response.data != null) {
        final resData = response.data as Map<String, dynamic>;
        final list = (resData['data'] as List<dynamic>?) ?? const [];
        return list
            .whereType<Map<String, dynamic>>()
            .map(WorkLocationModel.fromJson)
            .toList();
      }
      throw ApiException(
        statusCode: response.statusCode,
        message: 'Gagal memuat daftar lokasi kerja',
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
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
    try {
      final response = await dio.post(
        ApiEndpoints.attendanceCheckIn,
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy, // Strictly required by ATT-06 & Planning/01 §13
          'locationId': locationId,
          if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
          if (employeeId != null && employeeId.isNotEmpty) 'employeeId': employeeId,
        },
      );

      if ((response.statusCode == 201 || response.statusCode == 200) &&
          response.data != null) {
        final resData = response.data as Map<String, dynamic>;
        final payload = (resData['data'] is Map<String, dynamic>)
            ? resData['data'] as Map<String, dynamic>
            : resData;
        return AttendanceModel.fromJson(payload);
      }

      throw ApiException(
        statusCode: response.statusCode,
        message: 'Gagal melakukan check-in',
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<AttendanceModel> checkOut({
    required double latitude,
    required double longitude,
    required double accuracy,
    String? employeeId,
  }) async {
    try {
      final response = await dio.post(
        ApiEndpoints.attendanceCheckOut,
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy, // Strictly required by B3 & ATT-06
          if (employeeId != null && employeeId.isNotEmpty) 'employeeId': employeeId,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final resData = response.data as Map<String, dynamic>;
        final payload = (resData['data'] is Map<String, dynamic>)
            ? resData['data'] as Map<String, dynamic>
            : resData;
        return AttendanceModel.fromJson(payload);
      }

      throw ApiException(
        statusCode: response.statusCode,
        message: 'Gagal melakukan check-out',
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<AttendanceModel?> getToday({String? employeeId}) async {
    try {
      final response = await dio.get(
        ApiEndpoints.attendanceToday,
        queryParameters: {
          if (employeeId != null && employeeId.isNotEmpty) 'employeeId': employeeId,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final resData = response.data as Map<String, dynamic>;
        final payload = resData['data'];
        if (payload == null) return null;
        if (payload is Map<String, dynamic>) {
          return AttendanceModel.fromJson(payload);
        }
        return null;
      }

      throw ApiException(
        statusCode: response.statusCode,
        message: 'Gagal memuat status absensi hari ini',
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<List<AttendanceModel>> getHistory({
    int? page,
    int? limit,
    String? startDate,
    String? endDate,
    String? employeeId,
  }) async {
    try {
      final response = await dio.get(
        ApiEndpoints.attendanceHistory,
        queryParameters: {
          if (page != null) 'page': page,
          if (limit != null) 'limit': limit,
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
          if (employeeId != null && employeeId.isNotEmpty) 'employeeId': employeeId,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final resData = response.data as Map<String, dynamic>;
        final list = (resData['data'] as List<dynamic>?) ?? const [];
        return list
            .whereType<Map<String, dynamic>>()
            .map(AttendanceModel.fromJson)
            .toList();
      }

      throw ApiException(
        statusCode: response.statusCode,
        message: 'Gagal memuat riwayat absensi',
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getReport({int? month, int? year}) async {
    try {
      final response = await dio.get(
        ApiEndpoints.attendanceReport,
        queryParameters: {
          if (month != null) 'month': month,
          if (year != null) 'year': year,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final resData = response.data as Map<String, dynamic>;
        final list = (resData['data'] as List<dynamic>?) ?? const [];
        return list.whereType<Map<String, dynamic>>().toList();
      }

      throw ApiException(
        statusCode: response.statusCode,
        message: 'Gagal memuat laporan absensi',
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<List<WeeklyStatModel>> getWeeklyStats() async {
    try {
      final response = await dio.get(ApiEndpoints.attendanceWeeklyStats);
      if (response.statusCode == 200 && response.data != null) {
        final resData = response.data as Map<String, dynamic>;
        final list = (resData['data'] as List<dynamic>?) ?? const [];
        return list
            .whereType<Map<String, dynamic>>()
            .map(WeeklyStatModel.fromJson)
            .toList();
      }

      throw ApiException(
        statusCode: response.statusCode,
        message: 'Gagal memuat statistik mingguan',
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  @override
  Future<TodaySummaryModel> getTodaySummary() async {
    try {
      final response = await dio.get(ApiEndpoints.attendanceTodaySummary);
      if (response.statusCode == 200 && response.data != null) {
        final resData = response.data as Map<String, dynamic>;
        final payload = (resData['data'] is Map<String, dynamic>)
            ? resData['data'] as Map<String, dynamic>
            : resData;
        return TodaySummaryModel.fromJson(payload);
      }

      throw ApiException(
        statusCode: response.statusCode,
        message: 'Gagal memuat ringkasan absensi hari ini',
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
