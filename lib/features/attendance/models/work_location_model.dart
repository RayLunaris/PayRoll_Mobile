import 'dart:math' as math;

class WorkLocationModel {
  final String id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final int radiusMeters;

  WorkLocationModel({
    required this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 100,
  });

  factory WorkLocationModel.fromJson(Map<String, dynamic> json) {
    final rawLat = json['latitude'];
    final rawLng = json['longitude'];
    final rawRadius = json['radiusMeters'];

    return WorkLocationModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Lokasi Kerja').toString(),
      address: json['address']?.toString(),
      latitude: rawLat is num ? rawLat.toDouble() : double.tryParse(rawLat?.toString() ?? '0') ?? 0.0,
      longitude: rawLng is num ? rawLng.toDouble() : double.tryParse(rawLng?.toString() ?? '0') ?? 0.0,
      radiusMeters: rawRadius is num ? rawRadius.toInt() : int.tryParse(rawRadius?.toString() ?? '100') ?? 100,
    );
  }

  /// Calculates Haversine distance in meters between a point and this work location
  double distanceFrom(double userLat, double userLng) {
    return calculateDistanceMeters(latitude, longitude, userLat, userLng);
  }

  bool isWithinRadius(double userLat, double userLng) {
    return distanceFrom(userLat, userLng) <= radiusMeters;
  }

  /// Exact Haversine formula matching backend locations.ts:148-160
  static double calculateDistanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371e3; // meters
    final double phi1 = lat1 * math.pi / 180.0;
    final double phi2 = lat2 * math.pi / 180.0;
    final double deltaPhi = (lat2 - lat1) * math.pi / 180.0;
    final double deltaLambda = (lng2 - lng1) * math.pi / 180.0;

    final double a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(deltaLambda / 2) *
            math.sin(deltaLambda / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }
}
