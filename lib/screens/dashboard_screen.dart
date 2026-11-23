import 'dart:async';

import 'package:flutter/material.dart';

import '../models/pressure_reading.dart';
import '../models/sensor_limit.dart';
import '../services/alarm_notifier.dart';
import '../services/alarm_settings.dart';
import '../services/limits_api_service.dart';
import '../services/pressure_api_service.dart';
import '../widgets/alarm_controls.dart';
import '../widgets/common_ui.dart';
import '../widgets/sensor_card.dart';

/// The only pressure sensor in use.
const String _pressureSensorId = 'pressure_sensor_01';

/// A sensor that never sent any data is simply not connected, so it does not
/// alarm. A sensor that reported before and then went silent does.
bool _isAlarm(PressureReading r) {
  final s = r.alarmStatus;
  if (s == 'HIGH_PRESSURE' || s == 'LOW_PRESSURE') return true;
  return s == 'SENSOR_OFFLINE' && r.lastSeen != null;
}

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
  PressureReading? _reading;
  bool _serverConnected = false;
  bool _initialLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  DateTime? _lastServerUpdate;
  bool _isStale = false;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AlarmSettings.instance.addListener(_syncAlarm);
    _fetchData();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 4), (_) => _fetchData());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AlarmSettings.instance.removeListener(_syncAlarm);
    _refreshTimer?.cancel();
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
      _refreshTimer ??=
          Timer.periodic(const Duration(seconds: 4), (_) => _fetchData());
    }
  }

  /// Rings for sensors that are in alarm AND have their alarm switched on
  /// (master switch and sensor switch). Stops when none are left.
  void _syncAlarm() {
    final r = _reading;
    final alarming = <String>[
      if (r != null &&
          _isAlarm(r) &&
          AlarmSettings.instance.sensorActive(r.sensorId))
        r.displayName,
    ];
    AlarmNotifier.sync('pressure', alarming);
  }

  Future<void> _fetchData() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    if (mounted) setState(() {});

    try {
      final current = await _service.fetchCurrent();

      List<SensorLimit>? limits;
      try {
        limits = await _limitsService.fetchLimits();
      } catch (_) {
        limits = null;
      }

      if (!mounted) return;
      final reading = current.data.firstWhere(
        (r) => r.sensorId == _pressureSensorId,
        orElse: () => PressureReading.unavailable(_pressureSensorId),
      );

      _reading = reading;
      _syncAlarm();

      setState(() {
        if (limits != null) {
          _limits = {for (final l in limits) l.sensorId: l};
        }
        _serverConnected = true;
        _errorMessage = null;
        _lastServerUpdate = DateTime.now();
        _isStale = false;
        _initialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _serverConnected = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _initialLoading = false;
        _isStale = _reading != null;
      });
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reading = _reading;
    final online = reading != null && reading.isOnline;
    final alarmCount = reading != null && _isAlarm(reading) ? 1 : 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchData,
          color: AppColors.blue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ResponsiveBody(
              maxWidth: 700,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppHeader(
                    icon: Icons.water_rounded,
                    subtitle: 'Pressure Monitoring',
                    serverConnected: _serverConnected,
                    isRefreshing: _isRefreshing,
                    onRefresh: _fetchData,
                  ),
                  const SizedBox(height: 12),
                  if (_errorMessage != null) ...[
                    ErrorBanner(message: _errorMessage!),
                    const SizedBox(height: 12),
                  ],
                  const PageAlarmToggle(
                    label: 'Pressure',
                    sensorIds: [_pressureSensorId],
                  ),
                  const SizedBox(height: 12),
                  SummaryTiles(
                    tiles: [
                      const SummaryTileData(
                          'Total Sensors', '1', AppColors.blue),
                      SummaryTileData(
                          'Online', online ? '1' : '0', AppColors.green),
                      SummaryTileData(
                          'Offline', online ? '0' : '1', AppColors.muted),
                      SummaryTileData('Alarms', '$alarmCount', AppColors.red),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_initialLoading || reading == null)
                    const SkeletonBlock(height: 300)
                  else
                    SensorCard(
                      reading: reading,
                      limit: _limits[reading.sensorId],
                      stale: _isStale,
                    ),
                  const SizedBox(height: 12),
                  _AlarmStatus(reading: reading),
                  const SizedBox(height: 12),
                  LastUpdateFooter(
                    lastServerUpdate: _lastServerUpdate,
                    isStale: _isStale,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlarmStatus extends StatelessWidget {
  final PressureReading? reading;
  const _AlarmStatus({required this.reading});

  Color _color(String status) {
    switch (status) {
      case 'HIGH_PRESSURE':
        return AppColors.red;
      case 'LOW_PRESSURE':
        return AppColors.orange;
      case 'NOT_CONFIGURED':
        return AppColors.blue;
      default:
        return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = reading;
    final inAlarm = r != null &&
        (_isAlarm(r) || r.alarmStatus == 'NOT_CONFIGURED');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ALARM STATUS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.label,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          if (!inAlarm)
            const Text(
              'ALL SENSORS NORMAL',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.green,
              ),
            )
          else
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _color(r.alarmStatus),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${r.displayName} - ${r.alarmStatus}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _color(r.alarmStatus),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
