class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final String? error;
  final dynamic details;
  final bool isNetworkError;
  final Map<String, dynamic>? rawData;

  ApiException({
    this.statusCode,
    required this.message,
    this.error,
    this.details,
    this.isNetworkError = false,
    this.rawData,
  });

  num? get distance => rawData?['distance'] as num?;
  num? get radius => rawData?['radius'] as num?;
  num? get accuracy => rawData?['accuracy'] as num?;

  @override
  String toString() {
    return 'ApiException(statusCode: $statusCode, message: $message, error: $error, isNetworkError: $isNetworkError)';
  }

  factory ApiException.fromDioError(dynamic err) {
    if (err is! Exception) {
      return ApiException(message: err.toString());
    }

    try {
      final response = (err as dynamic).response;
      if (response != null) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return ApiException(
            statusCode: response.statusCode,
            message: (data['message'] ?? data['error'] ?? 'Terjadi kesalahan pada server').toString(),
            error: data['error']?.toString(),
            details: data['details'],
            isNetworkError: false,
            rawData: data,
          );
        }
        return ApiException(
          statusCode: response.statusCode,
          message: 'Error ${response.statusCode}: ${response.statusMessage ?? "Request failed"}',
          isNetworkError: false,
        );
      }
    } catch (_) {}

    return ApiException(
      message: 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      isNetworkError: true,
    );
  }
}

