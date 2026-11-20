import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/temperature_reading.dart';
import '../services/temperature_api_service.dart';

const int _sensorCount = 19;

const Color _cardBg = Color(0xFF172633);
const Color _cardBorder = Color(0xFF2A3F52);
const Color _muted = Color(0xFF808B96);
const Color _label = Color(0xFFAAB8C4);
const Color _green = Color(0xFF8BC34A);
const Color _red = Color(0xFFF44336);
const Color _orange = Color(0xFFFF9800);
const Color _blue = Color(0xFF536FC0);

Color _statusColor(String status) {
  switch (status) {
    case 'NORMAL':
      return _green;
    case 'HIGH_TEMPERATURE':
      return _red;
    case 'LOW_TEMPERATURE':
      return _orange;
    case 'NOT_CONFIGURED':
      return _blue;
    default:
      return _muted;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'HIGH_TEMPERATURE':
      return 'HIGH TEMPERATURE';
    case 'LOW_TEMPERATURE':
      return 'LOW TEMPERATURE';
    case 'SENSOR_OFFLINE':
      return 'SENSOR OFFLINE';
    case 'NOT_CONFIGURED':
      return 'NOT CONFIGURED';
    default:
      return status;
  }
}

bool _isAlarm(String status) =>
    status == 'HIGH_TEMPERATURE' ||
    status == 'LOW_TEMPERATURE' ||
    status == 'SENSOR_OFFLINE';

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
  int _activeAlarmCount = 0;
  DateTime? _lastServerUpdate;
  bool _isStale = false;
  bool _hadAlarm = false;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchData();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 4), (_) => _fetchData());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  Future<void> _fetchData() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    if (mounted) setState(() {});

    try {
      final current = await _service.fetchCurrent();
      ActiveTemperatureAlarmsResponse? alarms;
      try {
        alarms = await _service.fetchAlarms();
      } catch (_) {
        alarms = null;
      }

      if (!mounted) return;
      final ordered = _orderedReadings(current.data);
      final hasAlarm = ordered.any((r) => _isAlarm(r.alarmStatus));

      if (hasAlarm && !_hadAlarm) {
        SystemSound.play(SystemSoundType.alert);
      }
      _hadAlarm = hasAlarm;

      setState(() {
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

  List<TemperatureReading> _orderedReadings(List<TemperatureReading> data) {
    final byId = <String, TemperatureReading>{
      for (final r in data) r.sensorId: r,
    };
    return List<TemperatureReading>.generate(_sensorCount, (i) {
      final id = 'temperature_sensor_${(i + 1).toString().padLeft(2, '0')}';
      return byId[id] ?? TemperatureReading.unavailable(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final readings = _readings;
    final onlineCount = readings?.where((r) => r.isOnline).length ?? 0;
    final offlineCount = readings == null ? 0 : readings.length - onlineCount;

    return Scaffold(
      backgroundColor: const Color(0xFF263746),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchData,
          color: _blue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
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
                  total: _sensorCount,
                  onlineCount: onlineCount,
                  offlineCount: offlineCount,
                  activeAlarmCount: _activeAlarmCount,
                ),
                const SizedBox(height: 14),
                if (_initialLoading)
                  const _LoadingSkeleton()
                else
                  _SensorGrid(readings: readings!, stale: _isStale),
                const SizedBox(height: 14),
                _AlarmSection(readings: readings),
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
  final bool serverConnected;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;

  const _Header({
    required this.serverConnected,
    required this.isRefreshing,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final connColor = serverConnected ? _green : _red;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.thermostat_rounded, color: _blue, size: 26),
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
                  'Temperature Monitoring',
                  style: TextStyle(fontSize: 12, color: _label),
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
                  decoration:
                      BoxDecoration(color: connColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  serverConnected ? 'SERVER CONNECTED' : 'SERVER DISCONNECTED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: connColor,
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
                      color: _blue,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: _label),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final int total;
  final int onlineCount;
  final int offlineCount;
  final int activeAlarmCount;

  const _SummaryRow({
    required this.total,
    required this.onlineCount,
    required this.offlineCount,
    required this.activeAlarmCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _Tile(label: 'Total Sensors', value: '$total', color: _blue)),
        const SizedBox(width: 8),
        Expanded(child: _Tile(label: 'Online', value: '$onlineCount', color: _green)),
        const SizedBox(width: 8),
        Expanded(child: _Tile(label: 'Offline', value: '$offlineCount', color: _muted)),
        const SizedBox(width: 8),
        Expanded(child: _Tile(label: 'Alarms', value: '$activeAlarmCount', color: _red)),
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
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
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
              color: _label,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
        final width = constraints.maxWidth;
        final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isAlarm(reading.alarmStatus) && reading.alarmStatus != 'SENSOR_OFFLINE'
              ? color.withValues(alpha: 0.7)
              : _cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reading.displayName.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _label,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: reading.isOnline ? _green : _muted,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: reading.isOnline ? Colors.white : _muted,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: const Text(
                  '°C',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _label,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(
              _statusLabel(reading.alarmStatus),
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
            style: const TextStyle(fontSize: 10, color: _muted),
          ),
          if (stale)
            const Text(
              'STALE DATA',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _red,
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
    final offline = list.where((r) => r.alarmStatus == 'SENSOR_OFFLINE').toList();
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
            color: _muted,
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
              color: _blue,
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
            color: _green,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ALARM STATUS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _label,
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

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _red.withValues(alpha: 0.4)),
      ),
      child: Text(
        'SERVER DISCONNECTED: $message',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _red,
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
        for (var i = 0; i < 3; i++)
          Container(
            height: 110,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
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
      text =
          'Last server update: ${DateFormat('dd MMM yyyy, HH:mm:ss').format(lastServerUpdate!.toLocal())}';
      if (isStale) text += ' (stale)';
    }
    return Center(
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: _muted),
      ),
    );
  }
}
