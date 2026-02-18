import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

class StatusCard extends StatelessWidget {
  const StatusCard({
    super.key,
    required this.trackingActive,
    required this.updateIntervalMinutes,
    required this.activityLabel,
    required this.recordedCount,
  });

  final bool trackingActive;
  final int updateIntervalMinutes;
  final String activityLabel;
  final int recordedCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: const Color(0xFFDDF0DF),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFF4CAF50), width: 2),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Icon(
              Icons.gps_fixed_rounded,
              size: 72,
              color: trackingActive ? const Color(0xFF2E9446) : Colors.grey,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              trackingActive ? 'Tracking Active' : 'Tracking Stopped',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF16692B),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Updates every $updateIntervalMinutes minutes',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFC6E8FA),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.directions_car_rounded, size: 18),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Activity: ${activityLabel.toUpperCase()}',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFEFE7FF),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              child: Text(
                '$recordedCount locations recorded',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF49308C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
