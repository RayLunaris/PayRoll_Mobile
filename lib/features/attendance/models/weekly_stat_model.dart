class WeeklyStatModel {
  final String date;
  final String fullDate;
  final int present;
  final int late;
  final int absent;

  WeeklyStatModel({
    required this.date,
    required this.fullDate,
    required this.present,
    required this.late,
    required this.absent,
  });

  factory WeeklyStatModel.fromJson(Map<String, dynamic> json) {
    return WeeklyStatModel(
      date: (json['date'] ?? '').toString(),
      fullDate: (json['fullDate'] ?? '').toString(),
      present: (json['present'] as num?)?.toInt() ?? 0,
      late: (json['late'] as num?)?.toInt() ?? 0,
      absent: (json['absent'] as num?)?.toInt() ?? 0,
    );
  }
}
