import 'package:flutter/material.dart';
import '../../core/constants/app_keys.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../features/attendance/models/work_location_model.dart';

enum GpsLockState {
  searching,
  locked,
  denied,
  outside,
  lowAccuracy,
}

/// GpsStatusCard component required by Planning/02 §6 & §7
/// Shows distance in meters (24 Bold), accuracy (±Xm), status state, and location dropdown.
class GpsStatusCard extends StatelessWidget {
  final GpsLockState gpsState;
  final double distanceMeters;
  final double accuracyMeters;
  final List<WorkLocationModel> locations;
  final WorkLocationModel? selectedLocation;
  final ValueChanged<WorkLocationModel?>? onLocationChanged;

  const GpsStatusCard({
    super.key,
    required this.gpsState,
    required this.distanceMeters,
    required this.accuracyMeters,
    required this.locations,
    required this.selectedLocation,
    this.onLocationChanged,
  });

  @override
  Widget build(BuildContext context) {
    final Color stateColor;
    final IconData stateIcon;
    final String stateText;
    final int maxRadius = selectedLocation?.radiusMeters ?? 100;

    switch (gpsState) {
      case GpsLockState.locked:
        stateColor = AppColors.successEmerald;
        stateIcon = Icons.gps_fixed_rounded;
        stateText = 'Di Dalam Radius Kerja (≤${maxRadius}m)';
        break;
      case GpsLockState.searching:
        stateColor = AppColors.primaryNavy;
        stateIcon = Icons.gps_not_fixed_rounded;
        stateText = 'Mencari Sinyal GPS...';
        break;
      case GpsLockState.outside:
        stateColor = AppColors.warningAmber;
        stateIcon = Icons.location_off_outlined;
        stateText = 'Di Luar Radius Kerja (Maks ${maxRadius}m)';
        break;
      case GpsLockState.lowAccuracy:
        stateColor = AppColors.dangerRed;
        stateIcon = Icons.warning_amber_rounded;
        stateText = 'Akurasi GPS Rendah (>100m — Diblokir)';
        break;
      case GpsLockState.denied:
        stateColor = AppColors.dangerRed;
        stateIcon = Icons.gps_off_rounded;
        stateText = 'Izin Lokasi Ditolak / GPS Mati';
        break;
    }

    return Card(
      key: AppKeys.gpsStatusCard,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(stateIcon, color: stateColor, size: 22),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    stateText,
                    style: AppTypography.body.copyWith(
                      color: stateColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jarak ke Lokasi',
                      style: AppTypography.label.copyWith(
                        color: AppColors.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      '${distanceMeters.round()} m',
                      key: AppKeys.gpsDistanceText,
                      style: AppTypography.display.copyWith(
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Akurasi GPS',
                      style: AppTypography.label.copyWith(
                        color: AppColors.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      '±${accuracyMeters.round()}m (Maks 100m)',
                      key: AppKeys.gpsAccuracyText,
                      style: AppTypography.label.copyWith(
                        color: accuracyMeters > 100
                            ? AppColors.dangerRed
                            : AppColors.successEmerald,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (locations.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s16),
              DropdownButtonFormField<String>(
                key: AppKeys.locationDropdown,
                initialValue: selectedLocation?.id ?? locations.first.id,
                decoration: const InputDecoration(
                  labelText: 'Lokasi Kerja',
                  prefixIcon: Icon(Icons.business_rounded),
                ),
                items: locations
                    .map(
                      (loc) => DropdownMenuItem<String>(
                        value: loc.id,
                        child: Text('${loc.name} (${loc.radiusMeters}m)'),
                      ),
                    )
                    .toList(),
                onChanged: (locId) {
                  if (locId != null && onLocationChanged != null) {
                    final matched = locations.firstWhere(
                      (l) => l.id == locId,
                      orElse: () => locations.first,
                    );
                    onLocationChanged!(matched);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
