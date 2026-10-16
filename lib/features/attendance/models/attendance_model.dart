class AttendanceModel {
  final String id;
  final String? employeeId;
  final String? locationId;
  final String? date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String status;
  final double overtimeHours;
  final String? checkInPhotoUrl;
  final String? locationName;
  final num? distance;
  final String? notes;

  AttendanceModel({
    required this.id,
    this.employeeId,
    this.locationId,
    this.date,
    this.checkIn,
    this.checkOut,
    this.status = 'present',
    this.overtimeHours = 0.0,
    this.checkInPhotoUrl,
    this.locationName,
    this.distance,
    this.notes,
  });

  bool get isCheckedIn => checkIn != null;
  bool get isCheckedOut => checkOut != null;

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString());
    }

    double parseOvertime(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    final locMap = json['location'] is Map<String, dynamic>
        ? json['location'] as Map<String, dynamic>
        : null;

    return AttendanceModel(
      id: (json['id'] ?? '').toString(),
      employeeId: json['employeeId']?.toString(),
      locationId: json['locationId']?.toString(),
      date: json['date']?.toString(),
      checkIn: parseDate(json['checkIn']),
      checkOut: parseDate(json['checkOut']),
      status: (json['status'] ?? 'present').toString(),
      overtimeHours: parseOvertime(json['overtimeHours']),
      checkInPhotoUrl: json['checkInPhotoUrl']?.toString(),
      locationName: (locMap?['name'] ?? json['locationName'])?.toString(),
      distance: locMap?['distance'] as num?,
      notes: json['notes']?.toString(),
    );
  }
}
