import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:padel_app/l10n/app_localizations.dart';
import 'package:padel_app/core/theme/app_theme.dart';
import 'package:padel_app/features/statistics/domain/models/aggregated_stats.dart';

// TODO(Sprint 3): replace with CV-generated data from match_analyses result JSONB
class ShotDistributionCard extends StatelessWidget {
  final ShotDistribution stats;

  const ShotDistributionCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasShots =
        stats.totalWinners > 0 || stats.totalUnforcedErrors > 0;
    final hasPadelShots = stats.totalPadelShots > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.shotDistribution,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
            ),
            const Divider(),

            // Winners vs Errors bar
            if (hasShots) ...[
              Text(l10n.winnersVsErrors,
                  style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: _maxVal([
                      stats.totalWinners,
                      stats.totalUnforcedErrors,
                      stats.totalForcedErrors,
                    ]),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            switch (value.toInt()) {
                              case 0:
                                return Text(l10n.winners,
                                    style: const TextStyle(fontSize: 10));
                              case 1:
                                return Text('UE',
                                    style: const TextStyle(fontSize: 10));
                              case 2:
                                return Text('FE',
                                    style: const TextStyle(fontSize: 10));
                              default:
                                return const SizedBox.shrink();
                            }
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      _bar(0, stats.totalWinners.toDouble(), AppColors.win),
                      _bar(1, stats.totalUnforcedErrors.toDouble(),
                          AppColors.loss),
                      _bar(2, stats.totalForcedErrors.toDouble(),
                          AppColors.draw),
                    ],
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, gIndex, rod, rIndex) =>
                            BarTooltipItem(
                          rod.toY.toInt().toString(),
                          const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // Padel shot pie chart
            if (hasPadelShots) ...[
              const SizedBox(height: 16),
              Text(l10n.padelShotBreakdown,
                  style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: Row(
                  children: [
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 30,
                          sections: _pieSections(l10n),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _legend(Colors.amber, l10n.bandeja, stats.bandejaWinners),
                        _legend(Colors.deepPurple, l10n.vibora, stats.viboraWinners),
                        _legend(Colors.red, l10n.smash, stats.smashWinners),
                        _legend(Colors.blue, l10n.lob, stats.lobWinners),
                        _legend(Colors.teal, l10n.volley, stats.volleyWinners),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            if (!hasShots && !hasPadelShots)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    l10n.noStatsYet,
                    style: const TextStyle(color: AppColors.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _maxVal(List<int> values) {
    final m = values.fold<int>(0, (a, b) => a > b ? a : b);
    return (m * 1.2).ceilToDouble().clamp(1, double.infinity);
  }

  BarChartGroupData _bar(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 28,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
    );
  }

  List<PieChartSectionData> _pieSections(AppLocalizations l10n) {
    final total = stats.totalPadelShots;
    if (total == 0) return [];

    PieChartSectionData section(int value, Color color) {
      final pct = (value / total * 100).toStringAsFixed(0);
      return PieChartSectionData(
        value: value.toDouble(),
        color: color,
        radius: 40,
        title: '$pct%',
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }

    return [
      if (stats.bandejaWinners > 0) section(stats.bandejaWinners, Colors.amber),
      if (stats.viboraWinners > 0) section(stats.viboraWinners, Colors.deepPurple),
      if (stats.smashWinners > 0) section(stats.smashWinners, Colors.red),
      if (stats.lobWinners > 0) section(stats.lobWinners, Colors.blue),
      if (stats.volleyWinners > 0) section(stats.volleyWinners, Colors.teal),
    ];
  }

  Widget _legend(Color color, String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('$label: $value', style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
