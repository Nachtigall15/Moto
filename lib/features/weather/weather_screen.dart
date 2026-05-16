import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../navigation/navigation_controller.dart';
import 'widgets/precip_chart.dart';

class WeatherScreen extends StatelessWidget {
  const WeatherScreen({super.key});

  static String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = context.watch<NavigationController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Moto · Wetter auf der Strecke')),
      body: c.route == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Zuerst im Tab „Navigation" eine Route berechnen.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _DepartureRow(controller: c),
                const SizedBox(height: 12),
                if (c.loadingWeather)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (c.weatherError != null)
                  Text(
                    c.weatherError!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error),
                  )
                else if (c.weather != null) ...[
                  _RainSummary(controller: c),
                  const SizedBox(height: 8),
                  PrecipChart(weather: c.weather!),
                  const SizedBox(height: 12),
                  ...c.weather!.samples.map(
                    (s) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        s.isRain
                            ? Icons.umbrella
                            : Icons.wb_sunny_outlined,
                        color: s.isRain
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(
                        '${(s.cumulativeMeters / 1000).toStringAsFixed(0)} km '
                        '· ${_hm(s.eta)} · ${s.condition}',
                      ),
                      trailing: Text(
                        '${s.temperature.toStringAsFixed(0)}°C\n'
                        '${s.precipitation.toStringAsFixed(1)} mm',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _DepartureRow extends StatelessWidget {
  const _DepartureRow({required this.controller});

  final NavigationController controller;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: controller.departure,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 14)),
    );
    if (d == null || !context.mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(controller.departure),
    );
    if (t == null) return;
    controller.setDeparture(
      DateTime(d.year, d.month, d.day, t.hour, t.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dep = controller.departure;
    return Row(
      children: [
        const Icon(Icons.schedule),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Abfahrt: ${dep.day}.${dep.month}. '
            '${WeatherScreen._hm(dep)}',
          ),
        ),
        TextButton(
          onPressed: () => _pick(context),
          child: const Text('Ändern'),
        ),
      ],
    );
  }
}

class _RainSummary extends StatelessWidget {
  const _RainSummary({required this.controller});

  final NavigationController controller;

  @override
  Widget build(BuildContext context) {
    final w = controller.weather!;
    if (!w.hasRain) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.check_circle_outline),
          title: Text('Trocken auf der ganzen Strecke.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Regen erwartet',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            ...w.rainWindows.map((rw) {
              final km1 = (rw.startMeters / 1000).toStringAsFixed(0);
              final km2 = (rw.endMeters / 1000).toStringAsFixed(0);
              final mins = rw.duration.inMinutes;
              return Text(
                '• ab km $km1 (${WeatherScreen._hm(rw.startEta)}) '
                'bis km $km2 – ca. $mins min',
              );
            }),
            const SizedBox(height: 10),
            if (controller.hasPause)
              Row(
                children: [
                  const Icon(Icons.local_cafe, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Pause: ${controller.pauseStop?.name ?? 'Rastmöglichkeit'}'
                      ' · ${controller.pauseDuration.inMinutes} min',
                    ),
                  ),
                  TextButton(
                    onPressed: controller.loading
                        ? null
                        : controller.clearPause,
                    child: const Text('Entfernen'),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: controller.loading
                      ? null
                      : controller.suggestPause,
                  icon: const Icon(Icons.local_cafe),
                  label: const Text('Pause vorschlagen'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
