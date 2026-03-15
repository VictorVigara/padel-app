import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:padel_app/l10n/app_localizations.dart';
import 'package:padel_app/core/theme/app_theme.dart';
import 'package:padel_app/features/statistics/domain/models/aggregated_stats.dart';

class PerformanceBreakdownCard extends StatelessWidget {
  final List<SurfaceBreakdown> bySurface;
  final List<MatchTypeBreakdown> byType;

  const PerformanceBreakdownCard({
    super.key,
    required this.bySurface,
    required this.byType,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // By surface
            if (bySurface.isNotEmpty) ...[
              Text(
                l10n.performanceBySurface,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: BarChart(
                  _buildBarChart(
                    bySurface.map((s) => _BarItem(
                      label: _formatSurface(s.surface, l10n),
                      wins: s.wins,
                      losses: s.matches - s.wins,
                    )).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // By match type
            if (byType.isNotEmpty) ...[
              Text(
                l10n.performanceByType,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: BarChart(
                  _buildBarChart(
                    byType.map((t) => _BarItem(
                      label: _formatType(t.matchType, l10n),
                      wins: t.wins,
                      losses: t.matches - t.wins,
                    )).toList(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  BarChartData _buildBarChart(List<_BarItem> items) {
    final maxY = items.fold<int>(
            0, (m, i) => (i.wins + i.losses) > m ? (i.wins + i.losses) : m) *
        1.2;

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY.ceilToDouble().clamp(1, double.infinity),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx >= 0 && idx < items.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(items[idx].label,
                      style: const TextStyle(fontSize: 10)),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
      barGroups: items.asMap().entries.map((e) {
        return BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: (e.value.wins + e.value.losses).toDouble(),
              width: 24,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
              rodStackItems: [
                BarChartRodStackItem(
                    0, e.value.wins.toDouble(), AppColors.win),
                BarChartRodStackItem(e.value.wins.toDouble(),
                    (e.value.wins + e.value.losses).toDouble(), AppColors.loss),
              ],
              color: Colors.transparent,
            ),
          ],
        );
      }).toList(),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, gIndex, rod, rIndex) {
            final item = items[gIndex];
            return BarTooltipItem(
              '${item.wins}W / ${item.losses}L',
              const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            );
          },
        ),
      ),
    );
  }

  String _formatSurface(String surface, AppLocalizations l10n) {
    switch (surface) {
      case 'glass':
        return l10n.glass;
      case 'cement':
        return l10n.cement;
      case 'turf':
        return l10n.turf;
      default:
        return l10n.other;
    }
  }

  String _formatType(String type, AppLocalizations l10n) {
    switch (type) {
      case 'friendly':
        return l10n.friendly;
      case 'league':
        return l10n.league;
      case 'tournament':
        return l10n.tournament;
      default:
        return type;
    }
  }
}

class _BarItem {
  final String label;
  final int wins;
  final int losses;

  const _BarItem(
      {required this.label, required this.wins, required this.losses});
}
