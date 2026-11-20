import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'screens/limits_screen.dart';
import 'screens/temperature_screen.dart';

void main() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          DashboardScreen(),
          TemperatureScreen(),
          LimitsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
        ],
      ),
    );
  }
}
