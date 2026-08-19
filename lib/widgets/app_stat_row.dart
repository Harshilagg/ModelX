import 'package:flutter/material.dart';
import '../ui/app_theme.dart';

/// One label/value pair for [AppStatRow].
class AppStat {
  final String label;
  final String value;
  final Color? valueColor;
  const AppStat(this.label, this.value, {this.valueColor});
}

/// A glanceable, horizontally-scannable stat row — label small/caps
/// above, value bold below, evenly divided by hairlines. Built for the
/// profile screens' primary-stats treatment (the handful of facts
/// someone actually scans first), replacing a dense uncategorized
/// `Wrap` of every field the profile has.
class AppStatRow extends StatelessWidget {
  final List<AppStat> stats;

  const AppStatRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 8, horizontal: 6),
                decoration: BoxDecoration(
                  border: i == stats.length - 1
                      ? null
                      : const Border(right: BorderSide(color: AppColors.line)),
                ),
                child: Column(
                  children: [
                    Text(
                      stats[i].label,
                      textAlign: TextAlign.center,
                      style: AppTypography.label.copyWith(letterSpacing: 0.06),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      stats[i].value,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: stats[i].valueColor ?? AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
