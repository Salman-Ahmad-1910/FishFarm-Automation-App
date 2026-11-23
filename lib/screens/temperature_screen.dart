import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/temperature_reading.dart';
import '../services/alarm_notifier.dart';
import '../services/alarm_settings.dart';
import '../services/temperature_api_service.dart';
import '../widgets/alarm_controls.dart';
import '../widgets/common_ui.dart';

const int _sensorCount = 19;

final List<String> _sensorIds = List<String>.generate(
  _sensorCount,
  (i) => 'temperature_sensor_${(i + 1).toString().padLeft(2, '0')}',
);

Color _statusColor(String status) {
  switch (status) {
    case 'NORMAL':
      return AppColors.green;
    case 'HIGH_TEMPERATURE':
      return AppColors.red;
    case 'LOW_TEMPERATURE':
      return AppColors.orange;
    case 'NOT_CONFIGURED':
      return AppColors.blue;
    default:
      return AppColors.muted;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'HIGH_TEMPERATURE':
      return 'HIGH TEMP';
    case 'LOW_TEMPERATURE':
      return 'LOW TEMP';
    case 'SENSOR_OFFLINE':
      return 'OFFLINE';
    case 'NOT_CONFIGURED':
      return 'NOT SET';
    default:
      return status;
  }
}

/// A sensor that never sent any data is simply not connected, so it does not
/// alarm. A sensor that reported before and then went silent does.
bool _isAlarm(TemperatureReading r) {
  final s = r.alarmStatus;
  if (s == 'HIGH_TEMPERATURE' || s == 'LOW_TEMPERATURE') return true;
  return s == 'SENSOR_OFFLINE' && r.lastSeen != null;
}

class TemperatureScreen extends StatefulWidget {
  const TemperatureScreen({super.key});

  @override
  State<TemperatureScreen> createState() => _TemperatureScreenState();
}

class _TemperatureScreenState extends State<TemperatureScreen>
    with WidgetsBindingObserver {
  final TemperatureApiService _service = TemperatureApiService();

  List<TemperatureReading>? _readings;
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
    final list = _readings;
    if (list == null) return;
    final alarming = <String>[
      for (final r in list)
        if (_isAlarm(r) &&
            AlarmSettings.instance.sensorActive(r.sensorId))
          r.displayName,
    ];
    AlarmNotifier.sync('temperature', alarming);
  }

  Future<void> _fetchData() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    if (mounted) setState(() {});

    try {
      final current = await _service.fetchCurrent();
      if (!mounted) return;
      _readings = _orderedReadings(current.data);
      _syncAlarm();

      setState(() {
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
        _isStale = _readings != null;
      });
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  List<TemperatureReading> _orderedReadings(List<TemperatureReading> data) {
    final byId = <String, TemperatureReading>{
      for (final r in data) r.sensorId: r,
    };
    return [
      for (final id in _sensorIds) byId[id] ?? TemperatureReading.unavailable(id),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final readings = _readings;
    final onlineCount = readings?.where((r) => r.isOnline).length ?? 0;
    final offlineCount = readings == null ? 0 : readings.length - onlineCount;
    final alarmCount =
        readings?.where(_isAlarm).length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchData,
          color: AppColors.blue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ResponsiveBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppHeader(
                    icon: Icons.thermostat_rounded,
                    subtitle: 'Temperature Monitoring',
                    serverConnected: _serverConnected,
                    isRefreshing: _isRefreshing,
                    onRefresh: _fetchData,
                  ),
                  const SizedBox(height: 12),
                  if (_errorMessage != null) ...[
                    ErrorBanner(message: _errorMessage!),
                    const SizedBox(height: 12),
                  ],
                  PageAlarmToggle(
                    label: 'Temperature',
                    sensorIds: _sensorIds,
                  ),
                  const SizedBox(height: 12),
                  SummaryTiles(
                    tiles: [
                      const SummaryTileData(
                          'Total Sensors', '$_sensorCount', AppColors.blue),
                      SummaryTileData(
                          'Online', '$onlineCount', AppColors.green),
                      SummaryTileData(
                          'Offline', '$offlineCount', AppColors.muted),
                      SummaryTileData('Alarms', '$alarmCount', AppColors.red),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_initialLoading || readings == null)
                    const _LoadingSkeleton()
                  else
                    _SensorGrid(readings: readings, stale: _isStale),
                  const SizedBox(height: 12),
                  _AlarmSection(readings: readings),
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

class _SensorGrid extends StatelessWidget {
  final List<TemperatureReading> readings;
  final bool stale;

  const _SensorGrid({required this.readings, required this.stale});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        const minCardWidth = 165.0;
        final width = constraints.maxWidth;
        final columns = ((width + spacing) / (minCardWidth + spacing))
            .floor()
            .clamp(2, 6)
            .toInt();
        final cardWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final r in readings)
              SizedBox(
                width: cardWidth,
                child: _TemperatureCard(reading: r, stale: stale),
              ),
          ],
        );
      },
    );
  }
}

class _TemperatureCard extends StatelessWidget {
  final TemperatureReading reading;
  final bool stale;

  const _TemperatureCard({required this.reading, required this.stale});

  String _formatTime(DateTime? time) {
    if (time == null) return 'Never';
    return DateFormat('dd MMM, HH:mm:ss').format(time.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(reading.alarmStatus);
    final value = reading.temperatureC ?? 0;
    final limitAlarm = reading.alarmStatus == 'HIGH_TEMPERATURE' ||
        reading.alarmStatus == 'LOW_TEMPERATURE';

    return AppCard(
      radius: 16,
      padding: const EdgeInsets.all(12),
      borderColor: limitAlarm ? color.withValues(alpha: 0.7) : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: reading.isOnline ? AppColors.green : AppColors.muted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  reading.displayName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              AlarmSwitch(sensorId: reading.sensorId),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: reading.isOnline ? Colors.white : AppColors.muted,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 4),
                const Padding(
                  padding: EdgeInsets.only(bottom: 3),
                  child: Text(
                    '°C',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.label,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(
              _statusLabel(reading.alarmStatus),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatTime(reading.lastSeen),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppColors.muted),
          ),
          if (stale)
            const Text(
              'STALE DATA',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.red,
              ),
            ),
        ],
      ),
    );
  }
}

class _AlarmSection extends StatelessWidget {
  final List<TemperatureReading>? readings;

  const _AlarmSection({required this.readings});

  @override
  Widget build(BuildContext context) {
    final list = readings ?? <TemperatureReading>[];
    final limitAlarms = list
        .where((r) =>
            r.alarmStatus == 'HIGH_TEMPERATURE' ||
            r.alarmStatus == 'LOW_TEMPERATURE')
        .toList();
    final offline = list
        .where((r) => r.alarmStatus == 'SENSOR_OFFLINE' && r.lastSeen != null)
        .toList();
    final notConnected = list
        .where((r) => r.alarmStatus == 'SENSOR_OFFLINE' && r.lastSeen == null)
        .length;
    final notConfigured =
        list.where((r) => r.alarmStatus == 'NOT_CONFIGURED').length;

    final children = <Widget>[];
    for (final r in limitAlarms) {
      final c = _statusColor(r.alarmStatus);
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${r.displayName} - ${_statusLabel(r.alarmStatus)} '
                  '(${(r.temperatureC ?? 0).toStringAsFixed(1)} °C)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (offline.isNotEmpty) {
      children.add(
        Text(
          offline.length == list.length
              ? 'ALL SENSORS OFFLINE'
              : '${offline.length} sensor(s) offline: '
                  '${offline.map((r) => r.sensorId.split('_').last).join(', ')}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
          ),
        ),
      );
    }
    if (notConnected > 0) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '$notConnected sensor(s) not connected yet (no alarm).',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
      );
    }
    if (notConfigured > 0) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Temperature limits not configured on the server '
            '($notConfigured sensors).',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.blue,
            ),
          ),
        ),
      );
    }
    if (children.isEmpty) {
      children.add(
        const Text(
          'ALL SENSORS NORMAL',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.green,
          ),
        ),
      );
    }

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
          ...children,
        ],
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonBlock(height: 110),
        SizedBox(height: 10),
        SkeletonBlock(height: 110),
        SizedBox(height: 10),
        SkeletonBlock(height: 110),
      ],
    );
  }
}
