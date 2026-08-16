import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/feeding/feeding_screen.dart';
import 'features/health/medication_screen.dart';
import 'features/health/vaccination_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/sleep/sleep_screen.dart';
import 'features/training/training_screen.dart';
import 'features/treats/treats_screen.dart';
import 'features/weight/weight_screen.dart';
import 'state/app_state.dart';

/// Positionen in der unteren Navigationsleiste. Als Konstanten, damit
/// Sprünge aus der Übersicht heraus nicht an Zahlen hängen.
class Tabs {
  Tabs._();

  static const uebersicht = 0;
  static const alltag = 1;
  static const gesundheit = 2;
  static const kalender = 3;
  static const training = 4;
}

class DogApp extends StatelessWidget {
  const DogApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        title: 'Hunde-App',
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        // Ohne feste Sprache kämen Datums- und Uhrzeit-Dialoge auf
        // Englisch und mit AM/PM.
        locale: const Locale('de', 'DE'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('de', 'DE')],
        // Zusätzlich zur Sprache: 24-Stunden-Anzeige unabhängig davon,
        // wie das Gerät eingestellt ist.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
        home: const HomeShell(),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = Tabs.uebersicht;

  /// Innerhalb einer Gruppe soll beim Sprung aus der Übersicht auch
  /// der richtige Unter-Reiter aufgehen (z. B. „Gewicht").
  int? _unterreiter;

  void _open(int index, {int? unterreiter}) => setState(() {
        _index = index;
        _unterreiter = unterreiter;
      });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardScreen(onOpen: _open),
      _GroupPage(
        titel: 'Alltag',
        startIndex: _index == Tabs.alltag ? _unterreiter : null,
        reiter: const [
          ('Fütterung', FeedingScreen()),
          ('Schlaf', SleepScreen()),
          ('Leckerli', TreatsScreen()),
        ],
      ),
      _GroupPage(
        titel: 'Gesundheit',
        startIndex: _index == Tabs.gesundheit ? _unterreiter : null,
        reiter: const [
          ('Gewicht', WeightScreen()),
          ('Medikamente', MedicationScreen()),
          ('Impfungen', VaccinationScreen()),
        ],
      ),
      const CalendarScreen(),
      const TrainingScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _open,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Übersicht',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label: 'Alltag',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Gesundheit',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Kalender',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Training',
          ),
        ],
      ),
    );
  }
}

/// Fasst verwandte Screens unter einer Überschrift mit Reitern
/// zusammen. Ohne diese Bündelung stünden acht Einträge in der unteren
/// Leiste – auf einem Handy unbedienbar.
class _GroupPage extends StatefulWidget {
  const _GroupPage({
    required this.titel,
    required this.reiter,
    this.startIndex,
  });

  final String titel;
  final List<(String, Widget)> reiter;
  final int? startIndex;

  @override
  State<_GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<_GroupPage>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: widget.reiter.length,
    vsync: this,
    initialIndex: widget.startIndex ?? 0,
  );

  @override
  void didUpdateWidget(_GroupPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ziel = widget.startIndex;
    if (ziel != null && ziel != oldWidget.startIndex) {
      _controller.index = ziel;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titel),
        bottom: TabBar(
          controller: _controller,
          tabs: [for (final r in widget.reiter) Tab(text: r.$1)],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: [for (final r in widget.reiter) r.$2],
      ),
    );
  }
}

/// Der Heimtierausweis hängt nicht in der Navigationsleiste – er wird
/// selten geöffnet und dann gezielt.
void openProfile(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
  );
}
