import 'package:flutter/material.dart';
import 'package:padel_app/l10n/app_localizations.dart';
import 'package:padel_app/core/theme/app_theme.dart';
import 'package:padel_app/features/statistics/domain/models/aggregated_stats.dart';

class OverviewCard extends StatelessWidget {
  final OverviewStats stats;

  const OverviewCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.overview,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
            ),
            const Divider(),
            Row(
              children: [
                // Win rate circle
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: stats.winRate,
                        strokeWidth: 8,
                        backgroundColor: AppColors.loss.withAlpha(40),
                        valueColor: const AlwaysStoppedAnimation(AppColors.win),
                      ),
                      Text(
                        '${(stats.winRate * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _statLine(
                        context,
                        l10n.matchesPlayed,
                        '${stats.totalMatches}',
                      ),
                      const SizedBox(height: 8),
                      _statLine(
                        context,
                        l10n.wins,
                        '${stats.wins}',
                        color: AppColors.win,
                      ),
                      const SizedBox(height: 8),
                      _statLine(
                        context,
                        l10n.losses,
                        '${stats.losses}',
                        color: AppColors.loss,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statLine(BuildContext context, String label, String value,
      {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.onSurfaceVariant)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
