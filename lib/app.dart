import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'features/navigation/navigation_controller.dart';
import 'features/navigation/navigation_screen.dart';

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
        home: const NavigationScreen(),
      ),
    );
  }
}
