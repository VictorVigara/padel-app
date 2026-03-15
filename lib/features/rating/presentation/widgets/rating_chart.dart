import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:padel_app/core/theme/app_theme.dart';
import 'package:padel_app/features/rating/domain/models/rating_record.dart';

class RatingChart extends StatelessWidget {
  final List<RatingRecord> history;

  const RatingChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.length < 2) return const SizedBox.shrink();

    final spots = history.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.rating);
    }).toList();

    final ratings = history.map((r) => r.rating).toList();
    final minY = (ratings.reduce(min) - 50).floorToDouble();
    final maxY = (ratings.reduce(max) + 50).ceilToDouble();

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 50,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withAlpha(50),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                interval: 50,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
                ),
              ),
            ),
            bottomTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((spot) {
                final record = history[spot.spotIndex];
                final change = record.ratingChange;
                final changeStr = change >= 0 ? '+${change.toStringAsFixed(0)}' : change.toStringAsFixed(0);
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(0)} ($changeStr)',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              preventCurveOverShooting: true,
              color: AppColors.secondary,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 3,
                  color: AppColors.secondary,
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.secondary.withAlpha(30),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
