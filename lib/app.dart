import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'features/navigation/navigation_controller.dart';
import 'features/navigation/navigation_screen.dart';
import 'features/weather/weather_screen.dart';

class MotoApp extends StatelessWidget {
  const MotoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NavigationController(),
      child: MaterialApp(
        title: 'Moto',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _HomeShell(),
      ),
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell();

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _index = 0;

  static const _tabs = [NavigationScreen(), WeatherScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Navigation',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud),
            label: 'Wetter',
          ),
        ],
      ),
    );
  }
}
