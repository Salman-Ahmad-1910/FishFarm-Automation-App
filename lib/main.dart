import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/limits_screen.dart';
import 'screens/temperature_screen.dart';
import 'services/alarm_settings.dart';
import 'services/push_service.dart';
import 'services/update_service.dart';
import 'widgets/alarm_controls.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlarmSettings.instance.load();
  await PushService.init();
  runApp(const FishFarmApp());
}

class FishFarmApp extends StatelessWidget {
  const FishFarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fish Farm Monitoring',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF263746),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF536FC0),
          surface: Color(0xFF172633),
        ),
      ),
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.85,
        maxScaleFactor: 1.15,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final GlobalKey<HistoryScreenState> _historyKey =
      GlobalKey<HistoryScreenState>();

  @override
  void initState() {
    super.initState();
    // Quietly look for a new version once, shortly after the app opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateService.check(context, silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const MasterAlarmBar(),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  const DashboardScreen(),
                  const TemperatureScreen(),
                  const LimitsScreen(),
                  HistoryScreen(key: _historyKey),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          // Always show fresh history when the tab is opened.
          if (i == 3) _historyKey.currentState?.refresh();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.speed_rounded),
            label: 'Pressure',
          ),
          NavigationDestination(
            icon: Icon(Icons.thermostat_rounded),
            label: 'Temperature',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            label: 'Limits',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
