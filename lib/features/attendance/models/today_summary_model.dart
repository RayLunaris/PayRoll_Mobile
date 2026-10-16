/// E14: GET /api/attendance/today-summary
/// Strict rule (Planning/01 §11, Planning/11 §E14):
/// Mobile employee UI ONLY consumes `isSelfCheckedIn` and ignores any team/admin fields.
class TodaySummaryModel {
  final bool isSelfCheckedIn;

  const TodaySummaryModel({
    required this.isSelfCheckedIn,
  });

  factory TodaySummaryModel.fromJson(Map<String, dynamic> json) {
    return TodaySummaryModel(
      isSelfCheckedIn: json['isSelfCheckedIn'] == true,
    );
  }
}
