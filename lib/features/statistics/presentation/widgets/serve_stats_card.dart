import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:padel_app/l10n/app_localizations.dart';
import 'package:padel_app/core/theme/app_theme.dart';
import 'package:padel_app/features/statistics/domain/models/aggregated_stats.dart';

class ServeStatsCard extends StatelessWidget {
  final ServeAggregation stats;

  const ServeStatsCard({super.key, required this.stats});

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
              l10n.serveStats,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
            ),
            const Divider(),
            // Summary row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statColumn(
                  context,
                  l10n.avgFirstServe,
                  '${stats.avgFirstServePercent.toStringAsFixed(0)}%',
                ),
                _statColumn(
                  context,
                  l10n.acesPerMatch,
                  stats.avgAcesPerMatch.toStringAsFixed(1),
                ),
                _statColumn(
                  context,
                  l10n.doubleFaultsPerMatch,
                  stats.avgDoubleFaultsPerMatch.toStringAsFixed(1),
                ),
              ],
            ),
            // Line chart of first serve % if enough data
            if (stats.firstServePercentByMatch.length >= 2) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: 100,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 25,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey.withAlpha(50),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 25,
                          getTitlesWidget: (value, meta) => Text(
                            '${value.toInt()}%',
                            style: const TextStyle(fontSize: 9),
                          ),
                        ),
                      ),
                      bottomTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: const LineTouchData(enabled: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: stats.firstServePercentByMatch
                            .asMap()
                            .entries
                            .map((e) => FlSpot(e.key.toDouble(), e.value))
                            .toList(),
                        isCurved: true,
                        preventCurveOverShooting: true,
                        color: AppColors.primary,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.primary.withAlpha(20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statColumn(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
