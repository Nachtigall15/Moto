import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../models/route_result.dart';

/// Höhenprofil als Graph + Schieberegler. Beides steuert dieselbe
/// Cursor-Position (Distanz ab Start), die auf der Karte einen Marker
/// setzt.
class ElevationChart extends StatelessWidget {
  const ElevationChart({
    super.key,
    required this.route,
    required this.cursorMeters,
    required this.onCursorChanged,
  });

  final RouteResult route;
  final double cursorMeters;
  final ValueChanged<double> onCursorChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalKm = route.distanceMeters / 1000.0;

    final spots = route.points
        .map((p) => FlSpot(p.cumulativeMeters / 1000.0, p.elevation))
        .toList();

    final cursor = route.pointAtDistance(cursorMeters);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Höhenprofil',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                '${cursor.elevation.toStringAsFixed(0)} m  ·  '
                '${(cursorMeters / 1000).toStringAsFixed(1)} km',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: totalKm == 0 ? 1.0 : totalKm,
                minY: route.minElevation - 10,
                maxY: route.maxElevation + 10,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    barWidth: 2,
                    color: scheme.primary,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: scheme.primary.withValues(alpha: 0.18),
                    ),
                  ),
                ],
                extraLinesData: ExtraLinesData(
                  verticalLines: [
                    VerticalLine(
                      x: cursorMeters / 1000.0,
                      color: scheme.secondary,
                      strokeWidth: 2,
                    ),
                  ],
                ),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: false,
                  touchCallback: (event, response) {
                    final spots = response?.lineBarSpots;
                    if (spots != null && spots.isNotEmpty) {
                      onCursorChanged(spots.first.x * 1000.0);
                    }
                  },
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Slider(
            value: cursorMeters.clamp(0, route.distanceMeters).toDouble(),
            min: 0,
            max: route.distanceMeters == 0 ? 1.0 : route.distanceMeters,
            label: '${(cursorMeters / 1000).toStringAsFixed(1)} km',
            onChanged: onCursorChanged,
          ),
        ),
      ],
    );
  }
}
