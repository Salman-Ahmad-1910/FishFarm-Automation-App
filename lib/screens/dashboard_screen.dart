import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/pressure_reading.dart';
import '../models/sensor_limit.dart';
import '../services/limits_api_service.dart';
import '../services/pressure_api_service.dart';
import '../widgets/sensor_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final PressureApiService _service = PressureApiService();
  final LimitsApiService _limitsService = LimitsApiService();

  Map<String, SensorLimit> _limits = {};
  List<PressureReading>? _readings;
  bool _serverConnected = false;
  bool _initialLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  int _activeAlarmCount = 0;
  DateTime? _lastServerUpdate;
  bool _isStale = false;
  DateTime _now = DateTime.now();

  Timer? _refreshTimer;
  Timer? _clockTimer;

  bool _hadAlarm = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchData());
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    } else if (state == AppLifecycleState.resumed) {
      _fetchData();
      _refreshTimer ??= Timer.periodic(const Duration(seconds: 4), (_) => _fetchData());
    }
  }

  Future<void> _fetchData() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    if (mounted) setState(() {});

    try {
      final current = await _service.fetchCurrent();
      ActiveAlarmsResponse? alarms;
      try {
        alarms = await _service.fetchAlarms();
      } catch (_) {
        alarms = null;
      }

      List<SensorLimit>? limits;
      try {
        limits = await _limitsService.fetchLimits();
      } catch (_) {
        limits = null;
      }

      if (!mounted) return;
      final ordered = _orderedReadings(current.data);
      final hasAlarm = ordered.any(
        (r) =>
            r.alarmStatus == 'HIGH_PRESSURE' ||
            r.alarmStatus == 'LOW_PRESSURE' ||
            r.alarmStatus == 'SENSOR_OFFLINE',
      );

      if (hasAlarm && !_hadAlarm) {
        SystemSound.play(SystemSoundType.alert);
      }
      _hadAlarm = hasAlarm;

      setState(() {
        if (limits != null) {
          _limits = {for (final l in limits) l.sensorId: l};
        }
        _readings = ordered;
        _serverConnected = true;
        _errorMessage = null;
        _lastServerUpdate = DateTime.now();
        _isStale = false;
        _initialLoading = false;
        _activeAlarmCount = alarms?.count ??
            ordered.where((r) => r.alarmStatus != 'NORMAL').length;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _serverConnected = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _initialLoading = false;
        _isStale = _readings != null;
      });
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  List<PressureReading> _orderedReadings(List<PressureReading> data) {
    final byId = <String, PressureReading>{
      for (final r in data) r.sensorId: r,
    };
    return [
      byId['pressure_sensor_01'] ??
          PressureReading.unavailable('pressure_sensor_01'),
      byId['pressure_sensor_02'] ??
          PressureReading.unavailable('pressure_sensor_02'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final readings = _readings;
    final onlineCount = readings?.where((r) => r.isOnline).length ?? 0;
    final offlineCount = readings == null ? 0 : readings.length - onlineCount;
    final width = MediaQuery.of(context).size.width;
    final sideBySide = width >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFF263746),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchData,
          color: const Color(0xFF536FC0),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  now: _now,
                  serverConnected: _serverConnected,
                  isRefreshing: _isRefreshing,
                  onRefresh: _fetchData,
                ),
                const SizedBox(height: 14),
                if (_errorMessage != null) ...[
                  _ErrorBanner(message: _errorMessage!),
                  const SizedBox(height: 14),
                ],
                _SummaryRow(
                  onlineCount: onlineCount,
                  offlineCount: offlineCount,
                  activeAlarmCount: _activeAlarmCount,
                ),
                const SizedBox(height: 14),
                if (_initialLoading)
                  const _LoadingSkeleton()
                else if (sideBySide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SensorCard(
                          reading: readings![0],
                          limit: _limits[readings[0].sensorId],
                          stale: _isStale,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SensorCard(
                          reading: readings[1],
                          limit: _limits[readings[1].sensorId],
                          stale: _isStale,
                        ),
                      ),
                    ],
                  )
                else ...[
                  SensorCard(
                    reading: readings![0],
                    limit: _limits[readings[0].sensorId],
                    stale: _isStale,
                  ),
                  const SizedBox(height: 12),
                  SensorCard(
                    reading: readings[1],
                    limit: _limits[readings[1].sensorId],
                    stale: _isStale,
                  ),
                ],
                const SizedBox(height: 14),
                _AlarmSection(readings: readings, isStale: _isStale),
                const SizedBox(height: 14),
                _Footer(lastServerUpdate: _lastServerUpdate, isStale: _isStale),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final DateTime now;
  final bool serverConnected;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;

  const _Header({
    required this.now,
    required this.serverConnected,
    required this.isRefreshing,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF172633),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3F52)),
      ),
      child: Row(
        children: [
          const Icon(Icons.water_rounded, color: Color(0xFF536FC0), size: 26),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fish Farm Monitoring',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Pressure Monitoring',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFAAB8C4),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF203342),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: serverConnected
                        ? const Color(0xFF8BC34A)
                        : const Color(0xFFF44336),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  serverConnected ? 'SERVER CONNECTED' : 'SERVER DISCONNECTED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: serverConnected
                        ? const Color(0xFF8BC34A)
                        : const Color(0xFFF44336),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: isRefreshing ? null : () => onRefresh(),
            icon: isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF536FC0),
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: Color(0xFFAAB8C4)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final int onlineCount;
  final int offlineCount;
  final int activeAlarmCount;

  const _SummaryRow({
    required this.onlineCount,
    required this.offlineCount,
    required this.activeAlarmCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _Tile(label: 'Total Sensors', value: '2', color: const Color(0xFF536FC0))),
        const SizedBox(width: 8),
        Expanded(child: _Tile(label: 'Online', value: onlineCount.toString(), color: const Color(0xFF8BC34A))),
        const SizedBox(width: 8),
        Expanded(child: _Tile(label: 'Offline', value: offlineCount.toString(), color: const Color(0xFF808B96))),
        const SizedBox(width: 8),
        Expanded(child: _Tile(label: 'Alarms', value: activeAlarmCount.toString(), color: const Color(0xFFF44336))),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Tile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF172633),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A3F52)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFFAAB8C4),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlarmSection extends StatelessWidget {
  final List<PressureReading>? readings;
  final bool isStale;

  const _AlarmSection({required this.readings, required this.isStale});

  @override
  Widget build(BuildContext context) {
    final alarms = readings
            ?.where((r) =>
                r.alarmStatus == 'HIGH_PRESSURE' ||
                r.alarmStatus == 'LOW_PRESSURE' ||
                r.alarmStatus == 'SENSOR_OFFLINE' ||
                r.alarmStatus == 'NOT_CONFIGURED')
            .toList() ??
        [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF172633),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A3F52)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ALARM STATUS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFFAAB8C4),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          if (alarms.isEmpty)
            const Text(
              'ALL SENSORS NORMAL',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8BC34A),
              ),
            )
          else
            for (final r in alarms) ...[
              _AlarmRow(reading: r),
              if (r != alarms.last) const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _AlarmRow extends StatelessWidget {
  final PressureReading reading;

  const _AlarmRow({required this.reading});

  Color get _color {
    switch (reading.alarmStatus) {
      case 'HIGH_PRESSURE':
        return const Color(0xFFF44336);
      case 'LOW_PRESSURE':
        return const Color(0xFFFF9800);
      case 'SENSOR_OFFLINE':
        return const Color(0xFF808B96);
      case 'NOT_CONFIGURED':
        return const Color(0xFF536FC0);
      default:
        return const Color(0xFF8BC34A);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${reading.displayName} — ${reading.alarmStatus}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _color,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF44336).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF44336).withValues(alpha: 0.4)),
      ),
      child: Text(
        'SERVER DISCONNECTED: $message',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF44336),
        ),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 2; i++) ...[
          Container(
            height: 260,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF172633),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ],
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  final DateTime? lastServerUpdate;
  final bool isStale;

  const _Footer({required this.lastServerUpdate, required this.isStale});

  @override
  Widget build(BuildContext context) {
    String text;
    if (lastServerUpdate == null) {
      text = 'No successful server update yet.';
    } else {
      text = 'Last server update: ${DateFormat('dd MMM yyyy, HH:mm:ss').format(lastServerUpdate!.toLocal())}';
      if (isStale) text += ' (stale)';
    }
    return Center(
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF808B96),
        ),
      ),
    );
  }
}
