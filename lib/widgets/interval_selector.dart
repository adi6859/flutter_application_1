import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

class IntervalSelector extends StatelessWidget {
  const IntervalSelector({
    super.key,
    required this.values,
    required this.selectedValue,
    required this.enabled,
    required this.onChanged,
  });

  final List<int> values;
  final int selectedValue;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.timer_rounded),
                Text(
                  'Update Interval',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (!enabled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE4BD),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: const Text(
                      'Stop to change',
                      style: TextStyle(
                        color: Color(0xFFB85F00),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: values.map((value) {
                final isSelected = value == selectedValue;
                return SizedBox(
                  width: 90,
                  child: ElevatedButton(
                    onPressed: enabled ? () => onChanged(value) : null,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSm,
                        ),
                      ),
                      backgroundColor: WidgetStateColor.resolveWith((states) {
                        if (isSelected) return colorScheme.primary;
                        return const Color(0xFFEFEFEF);
                      }),
                      foregroundColor: WidgetStateColor.resolveWith((states) {
                        if (isSelected) return Colors.white;
                        return Colors.black54;
                      }),
                      disabledBackgroundColor: isSelected
                          ? colorScheme.primary
                          : const Color(0xFFEFEFEF),
                      disabledForegroundColor: isSelected
                          ? Colors.white
                          : Colors.black54,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      '$value min',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
