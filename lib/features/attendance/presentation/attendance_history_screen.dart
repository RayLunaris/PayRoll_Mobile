import 'package:flutter/material.dart';
import '../../../core/constants/app_keys.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../data/attendance_repository.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final AttendanceRepository attendanceRepository;

  const AttendanceHistoryScreen({
    super.key,
    required this.attendanceRepository,
  });

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.attendanceRepository.fetchHistoryAndStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.attendanceRepository,
      builder: (context, _) {
        final repo = widget.attendanceRepository;
        final history = repo.history;
        final weekly = repo.weeklyStats;

        return Scaffold(
          key: AppKeys.attendanceHistoryScreen,
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Riwayat Absensi'),
          ),
          body: SafeArea(
            child: repo.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    key: AppKeys.attendanceHistoryList,
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    children: [
                      if (weekly.isNotEmpty) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.s16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Statistik Mingguan Saya',
                                  style: AppTypography.title,
                                ),
                                const SizedBox(height: AppSpacing.s12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: weekly
                                      .map(
                                        (day) => Column(
                                          children: [
                                            Text(
                                              day.date,
                                              style: AppTypography.label,
                                            ),
                                            const SizedBox(
                                              height: AppSpacing.s4,
                                            ),
                                            CircleAvatar(
                                              radius: 14,
                                              backgroundColor: day.present > 0
                                                  ? AppColors.successEmerald
                                                  : day.late > 0
                                                      ? AppColors.warningAmber
                                                      : AppColors.outline,
                                              child: Text(
                                                day.present > 0
                                                    ? 'H'
                                                    : day.late > 0
                                                        ? 'T'
                                                        : '-',
                                                style:
                                                    AppTypography.label.copyWith(
                                                  color: (day.present > 0 ||
                                                          day.late > 0)
                                                      ? AppColors.surface
                                                      : AppColors.onSurface,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),
                      ],
                      if (history.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.s24),
                            child: Center(
                              child: Text(
                                'Belum ada riwayat absensi.',
                                style: AppTypography.body,
                              ),
                            ),
                          ),
                        )
                      else
                        ...history.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.s12,
                            ),
                            child: Card(
                              child: ListTile(
                                title: Text(
                                  item.date ?? 'Hari Ini',
                                  style: AppTypography.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  'Lokasi: ${item.locationName ?? "-"}\n'
                                  'Status: ${item.status} | Lembur: ${item.overtimeHours} jam',
                                  style: AppTypography.label,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
