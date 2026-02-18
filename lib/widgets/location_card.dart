import 'package:flutter/material.dart';

import '../models/location_update.dart';
import '../theme/app_spacing.dart';

class LocationCard extends StatelessWidget {
  const LocationCard({
    super.key,
    required this.index,
    required this.update,
    required this.onCoordinatesTap,
    required this.onOpenMaps,
  });

  final int index;
  final LocationUpdate update;
  final VoidCallback onCoordinatesTap;
  final VoidCallback onOpenMaps;

  static const Map<String, IconData> _activityIcon = {
    'in_vehicle': Icons.directions_car_rounded,
    'moving': Icons.show_chart_rounded,
    'still': Icons.bedtime_rounded,
    'on_foot': Icons.directions_walk_rounded,
  };

  static const Map<String, Color> _activityColor = {
    'in_vehicle': Color(0xFFD32F2F),
    'moving': Color(0xFFFFA000),
    'still': Color(0xFF1565C0),
    'on_foot': Color(0xFF2E7D32),
  };

  @override
  Widget build(BuildContext context) {
    final activity = (update.activity ?? 'unknown').toLowerCase();
    final activityIcon = _activityIcon[activity] ?? Icons.help_outline_rounded;
    final activityColor = _activityColor[activity] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFFE7DDFF),
              child: Text(
                '$index',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF5B35B8),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: onCoordinatesTap,
                    child: Text(
                      '${update.latitude.toStringAsFixed(6)}, ${update.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D76BE),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 18),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          update.timestamp.toLocal().toString(),
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(activityIcon, size: 18, color: activityColor),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        update.activity ?? 'unknown',
                        style: TextStyle(
                          color: activityColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Icon(Icons.gps_fixed_rounded, size: 18),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Accuracy: ${update.accuracyMeters?.toStringAsFixed(1) ?? '--'} m',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onOpenMaps,
              icon: const Icon(Icons.open_in_new_rounded),
              tooltip: 'Open in Maps',
            ),
          ],
        ),
      ),
    );
  }
}
