import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/gps_status_card.dart';
import '../../../shared/widgets/payroll_cta_button.dart';
import '../../../shared/widgets/sync_badge.dart';
import '../data/attendance_repository.dart';

class AttendanceScreen extends StatefulWidget {
  final AttendanceRepository attendanceRepository;

  const AttendanceScreen({
    super.key,
    required this.attendanceRepository,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.attendanceRepository.initializeAttendance();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.attendanceRepository,
      builder: (context, _) {
        final repo = widget.attendanceRepository;
        final today = repo.todayAttendance;
        final isCheckedIn = today?.isCheckedIn ?? false;
        final isCheckedOut = today?.isCheckedOut ?? false;
        final isAccValid = repo.isAccuracyValid;

        return Scaffold(
          key: AppKeys.attendanceScreen,
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Absensi GPS'),
            actions: [
              IconButton(
                key: AppKeys.attendanceToHistory,
                icon: const Icon(Icons.history_rounded),
                tooltip: 'Riwayat Absensi',
                onPressed: () => context.push('/attendance/history'),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sync status badge (Terkirim / Menunggu Sinkronisasi / Gagal)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SyncBadge(
                      status: repo.syncStatus,
                      pendingCount: repo.pendingSyncCount,
                      onRetry: () => repo.syncPendingQueue(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),

                  // GPS Status Card (distance 24 Bold, accuracy, location dropdown)
                  GpsStatusCard(
                    gpsState: repo.gpsLockState,
                    distanceMeters: repo.currentDistanceMeters,
                    accuracyMeters: repo.currentAccuracy,
                    locations: repo.locations,
                    selectedLocation: repo.selectedLocation,
                    onLocationChanged: repo.selectLocation,
                  ),
                  const SizedBox(height: AppSpacing.s12),

                  // Pre-check warning banner if accuracy > 100m (ATT-06)
                  if (!isAccValid) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: AppColors.dangerRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusCta),
                        border: Border.all(
                          color: AppColors.dangerRed.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.gps_off_rounded,
                            color: AppColors.dangerRed,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Text(
                              'Akurasi GPS (±${repo.currentAccuracy.round()}m) melebihi batas 100m. '
                              'Tombol absensi dikunci sampai sinyal GPS membaik.',
                              style: AppTypography.body.copyWith(
                                color: AppColors.dangerRed,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                  ],

                  // Error banner (outside radius with distance, server 400/403, or failed sync)
                  if (repo.errorMessage != null) ...[
                    Container(
                      key: AppKeys.attendanceErrorBanner,
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: AppColors.dangerRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusCta),
                        border: Border.all(
                          color: AppColors.dangerRed.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.dangerRed,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Text(
                              repo.errorMessage!,
                              style: AppTypography.body.copyWith(
                                color: AppColors.dangerRed,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                  ],

                  // Honest status / pending sync / server confirmation banner
                  if (repo.statusMessage != null) ...[
                    Container(
                      key: AppKeys.attendanceStatusBanner,
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: repo.syncStatus == SyncStatus.pendingSync
                            ? AppColors.warningAmber.withValues(alpha: 0.14)
                            : AppColors.successEmerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusCta),
                        border: Border.all(
                          color: repo.syncStatus == SyncStatus.pendingSync
                              ? AppColors.warningAmber.withValues(alpha: 0.4)
                              : AppColors.successEmerald.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            repo.syncStatus == SyncStatus.pendingSync
                                ? Icons.schedule_send_rounded
                                : Icons.check_circle_outline_rounded,
                            color: repo.syncStatus == SyncStatus.pendingSync
                                ? AppColors.warningAmber
                                : AppColors.successEmerald,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Text(
                              repo.statusMessage!,
                              style: AppTypography.body.copyWith(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                  ],

                  // Selfie camera stub card (Planning/02 §6 & Planning/05 §2)
                  Card(
                    child: ListTile(
                      key: AppKeys.selfieStubToggle,
                      leading: CircleAvatar(
                        backgroundColor: repo.hasSelfie
                            ? AppColors.successEmerald.withValues(alpha: 0.15)
                            : AppColors.primaryContainer,
                        child: Icon(
                          repo.hasSelfie
                              ? Icons.camera_alt_rounded
                              : Icons.camera_enhance_outlined,
                          color: repo.hasSelfie
                              ? AppColors.successEmerald
                              : AppColors.primaryNavy,
                        ),
                      ),
                      title: Text(
                        repo.hasSelfie
                            ? 'Foto Selfie Siap'
                            : 'Ambil Foto Selfie Kehadiran',
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        repo.hasSelfie
                            ? 'selfie://captured-stub.jpg'
                            : 'Ketuk untuk mengambil foto selfie',
                        style: AppTypography.label,
                      ),
                      trailing: Switch(
                        value: repo.hasSelfie,
                        onChanged: (val) => repo.setSelfieCaptured(val),
                      ),
                      onTap: () => repo.setSelfieCaptured(!repo.hasSelfie),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // Today's attendance summary card
                  if (today != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.s16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status Kehadiran Hari Ini',
                              style: AppTypography.title,
                            ),
                            const SizedBox(height: AppSpacing.s8),
                            Text(
                              'Status: ${today.status.toUpperCase()}',
                              style: AppTypography.body.copyWith(
                                color: AppColors.successEmerald,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (today.checkIn != null)
                              Text(
                                'Check-In: ${today.checkIn!.toIso8601String()}',
                                style: AppTypography.label,
                              ),
                            if (today.checkOut != null)
                              Text(
                                'Check-Out: ${today.checkOut!.toIso8601String()}',
                                style: AppTypography.label,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                  ],

                  // 1-Tap Check-In CTA (blocked if accuracy > 100 or already checked in)
                  PayrollCtaButton(
                    buttonKey: AppKeys.checkinSubmit,
                    text: isCheckedIn ? 'Sudah Check-In Hari Ini' : 'Check-In Sekarang',
                    isLoading: repo.isLoading,
                    onPressed: (!isAccValid || isCheckedIn)
                        ? null
                        : () => repo.submitCheckIn(),
                  ),
                  const SizedBox(height: AppSpacing.s12),

                  // 1-Tap Check-Out CTA (enabled only if checked in, not checked out, and accuracy <= 100)
                  PayrollCtaButton(
                    buttonKey: AppKeys.checkoutSubmit,
                    text: isCheckedOut ? 'Sudah Check-Out Hari Ini' : 'Check-Out Sekarang',
                    variant: PayrollButtonVariant.secondary,
                    isLoading: repo.isLoading,
                    onPressed: (!isAccValid || !isCheckedIn || isCheckedOut)
                        ? null
                        : () => repo.submitCheckOut(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
