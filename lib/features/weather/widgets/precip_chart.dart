import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../models/weather.dart';

/// Niederschlag (mm) entlang der Strecke; Regen-Fenster als markierte
/// Bereiche.
class PrecipChart extends StatelessWidget {
  const PrecipChart({super.key, required this.weather});

  final RouteWeather weather;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = weather.samples;
    final maxKm =
        s.isEmpty ? 1.0 : s.last.cumulativeMeters / 1000.0;
    final maxY = s.isEmpty
        ? 1.0
        : s.map((e) => e.precipitation).fold<double>(1.0, (a, b) => b > a ? b : a);

    return SizedBox(
      height: 170,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 4),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: maxKm == 0 ? 1.0 : maxKm,
            minY: 0,
            maxY: maxY * 1.2,
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: const FlTitlesData(
              topTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 34),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 22),
              ),
            ),
            rangeAnnotations: RangeAnnotations(
              verticalRangeAnnotations: [
                for (final rw in weather.rainWindows)
                  VerticalRangeAnnotation(
                    x1: rw.startMeters / 1000.0,
                    x2: rw.endMeters / 1000.0,
                    color: scheme.primary.withValues(alpha: 0.15),
                  ),
              ],
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (final e in s)
                    FlSpot(e.cumulativeMeters / 1000.0, e.precipitation),
                ],
                isCurved: true,
                barWidth: 2,
                color: scheme.primary,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: scheme.primary.withValues(alpha: 0.18),
                ),
              ),
            ],
            lineTouchData: const LineTouchData(enabled: false),
          ),
        ),
      ),
    );
  }
}
