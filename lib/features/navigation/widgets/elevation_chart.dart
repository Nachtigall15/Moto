import 'dart:math' as math;

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
    final yInterval = _niceInterval(route.maxElevation - route.minElevation, 3);
    final xInterval = _niceInterval(totalKm, 5);

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
          height: 120,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: totalKm == 0 ? 1.0 : totalKm,
                minY: route.minElevation - 10,
                maxY: route.maxElevation + 10,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) => _axisLabel(
                        '${value.round()}',
                        align: TextAlign.right,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: xInterval,
                      getTitlesWidget: (value, meta) {
                        // Letztes Label am rechten Rand weglassen,
                        // damit es nicht mit dem davor kollidiert.
                        if ((totalKm - value).abs() < xInterval * 0.4) {
                          return const SizedBox.shrink();
                        }
                        return _axisLabel('${value.round()}');
                      },
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

  static Widget _axisLabel(String text, {TextAlign align = TextAlign.center}) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, right: 4),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(fontSize: 10),
      ),
    );
  }

  /// Wählt ein „rundes" Intervall, sodass die Achse ca. `targetSteps`
  /// Beschriftungen zeigt – verhindert verschachtelte/überlappende
  /// Achsenwerte (z. B. „533.2487" oder „500547.1").
  static double _niceInterval(double range, int targetSteps) {
    if (range <= 0 || !range.isFinite) return 1.0;
    final raw = range / targetSteps;
    if (raw <= 0) return 1.0;
    final exp = (math.log(raw) / math.ln10).floor();
    final mag = math.pow(10, exp).toDouble();
    final norm = raw / mag;
    final nice = norm < 1.5
        ? 1.0
        : norm < 3
            ? 2.0
            : norm < 7
                ? 5.0
                : 10.0;
    return nice * mag;
  }
}
