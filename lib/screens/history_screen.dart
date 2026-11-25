import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/history.dart';
import '../services/history_api_service.dart';
import '../widgets/common_ui.dart';
import '../widgets/history_chart.dart';

/// History tab: 6-hour averages (pressure, temperature) and sensor uptime.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  final HistoryApiService _api = HistoryApiService();

  int _tab = 0;
  bool _loading = true;
  String? _error;
  List<HistorySeries> _pressure = [];
  List<HistorySeries> _temperature = [];
  List<SensorStatus> _status = [];
  String? _tempSensor;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final readings = await Future.wait([
        _api.fetchReadings('pressure'),
        _api.fetchReadings('temperature'),
      ]);
      final status = await _api.fetchStatus();
      if (!mounted) return;
      setState(() {
        _pressure = readings[0];
        _temperature = readings[1];
        _status = status;
        final ids = _temperature.map((s) => s.sensorId).toList();
        if (_tempSensor == null || !ids.contains(_tempSensor)) {
          _tempSensor = ids.isEmpty ? null : ids.first;
        }
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveBody(
      child: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _header(),
            const SizedBox(height: 10),
            _tabs(),
            const SizedBox(height: 10),
            if (_error != null) ...[
              ErrorBanner(message: _error!),
              const SizedBox(height: 10),
            ],
            if (_loading && _pressure.isEmpty && _temperature.isEmpty &&
                _status.isEmpty)
              const SkeletonBlock(height: 260)
            else
              ..._content(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: AppColors.blue, size: 26),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'History',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Last 15 days, average of every 6 hours',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.label),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loading ? null : refresh,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.blue,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: AppColors.label),
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    const labels = ['Pressure', 'Temperature', 'Online / Offline'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _tab = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _tab == i ? AppColors.blue : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _tab == i ? Colors.white : AppColors.label,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _content() {
    switch (_tab) {
      case 0:
        return _readingsSection(
          series: _pressure.isEmpty ? null : _pressure.first,
          color: AppColors.blue,
          unit: 'kPa',
          title: 'Pressure',
        );
      case 1:
        HistorySeries? selected;
        for (final s in _temperature) {
          if (s.sensorId == _tempSensor) selected = s;
        }
        return [
          if (_temperature.isNotEmpty) ...[
            _sensorPicker(),
            const SizedBox(height: 10),
          ],
          ..._readingsSection(
            series: selected,
            color: AppColors.orange,
            unit: '°C',
            title: 'Temperature',
          ),
        ];
      default:
        return _statusSection();
    }
  }

  Widget _sensorPicker() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final s in _temperature)
          ChoiceChip(
            label: Text(s.sensorId.split('_').last),
            selected: s.sensorId == _tempSensor,
            onSelected: (_) => setState(() => _tempSensor = s.sensorId),
          ),
      ],
    );
  }

  List<Widget> _readingsSection({
    required HistorySeries? series,
    required Color color,
    required String unit,
    required String title,
  }) {
    if (series == null || series.points.isEmpty) {
      return const [
        AppCard(
          child: Text(
            'No history yet. Every 6 hours the average of the readings is '
            'saved here, so data appears once the sensor has been sending.',
            style: TextStyle(fontSize: 13, color: AppColors.label),
          ),
        ),
      ];
    }

    final points = series.points;
    var lo = points.first.min;
    var hi = points.first.max;
    var sum = 0.0;
    for (final p in points) {
      if (p.min < lo) lo = p.min;
      if (p.max > hi) hi = p.max;
      sum += p.avg;
    }
    final avg = sum / points.length;

    return [
      SummaryTiles(
        tiles: [
          SummaryTileData('AVERAGE', '${avg.toStringAsFixed(1)} $unit', color),
          SummaryTileData(
              'LOWEST', '${lo.toStringAsFixed(1)} $unit', AppColors.label),
          SummaryTileData(
              'HIGHEST', '${hi.toStringAsFixed(1)} $unit', AppColors.label),
        ],
      ),
      const SizedBox(height: 10),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title - ${historySensorLabel(series.sensorId)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            HistoryLineChart(points: points, color: color, unit: unit),
            const SizedBox(height: 4),
            const Text(
              'Touch or drag on the graph to see each 6-hour average.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      _table(points, unit),
    ];
  }

  Widget _table(List<HistoryPoint> points, String unit) {
    final sorted = [...points]..sort((a, b) => b.start.compareTo(a.start));
    final days = <String, List<HistoryPoint>>{};
    for (final p in sorted) {
      final key = DateFormat('yyyy-MM-dd').format(p.start.toLocal());
      (days[key] ??= <HistoryPoint>[]).add(p);
    }

    final children = <Widget>[];
    days.forEach((key, list) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(
          DateFormat('EEE, dd MMM yyyy').format(list.first.start.toLocal()),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.label,
          ),
        ),
      ));
      for (final p in list) {
        final window =
            '${DateFormat('HH:mm').format(p.start.toLocal())} - ${DateFormat('HH:mm').format(p.end.toLocal())}';
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(window,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white)),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '${p.avg.toStringAsFixed(1)} $unit',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  '${p.min.toStringAsFixed(1)} - ${p.max.toStringAsFixed(1)}',
                  textAlign: TextAlign.right,
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ));
      }
    });

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text('6-HOUR WINDOW',
                    style: TextStyle(fontSize: 10, color: AppColors.muted)),
              ),
              Expanded(
                flex: 2,
                child: Text('AVERAGE',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 10, color: AppColors.muted)),
              ),
              Expanded(
                flex: 3,
                child: Text('LOW - HIGH',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 10, color: AppColors.muted)),
              ),
            ],
          ),
          ...children,
        ],
      ),
    );
  }

  List<Widget> _statusSection() {
    if (_status.isEmpty) {
      return const [
        AppCard(
          child: Text(
            'No online / offline history yet. It starts as soon as a sensor '
            'sends its first reading.',
            style: TextStyle(fontSize: 13, color: AppColors.label),
          ),
        ),
      ];
    }
    final online = _status.where((s) => s.isOnline).length;
    return [
      SummaryTiles(
        tiles: [
          SummaryTileData('SENSORS', '${_status.length}', Colors.white),
          SummaryTileData('ONLINE', '$online', AppColors.green),
          SummaryTileData(
              'OFFLINE', '${_status.length - online}', AppColors.red),
        ],
      ),
      for (final s in _status) ...[
        const SizedBox(height: 10),
        _statusCard(s),
      ],
    ];
  }

  Widget _statusCard(SensorStatus s) {
    final color = s.isOnline ? AppColors.green : AppColors.red;
    final since = s.since == null
        ? ''
        : '${s.isOnline ? 'Online' : 'Offline'} since ${DateFormat('dd MMM, HH:mm').format(s.since!.toLocal())}';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  historySensorLabel(s.sensorId),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  s.isOnline ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (since.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(since,
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: s.onlineRatio,
              minHeight: 6,
              color: AppColors.green,
              backgroundColor: AppColors.red.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _stat('Online', formatDuration(s.onlineSeconds), AppColors.green),
              _stat(
                  'Offline', formatDuration(s.offlineSeconds), AppColors.red),
              _stat('Went offline', '${s.offlineCount}x', AppColors.label),
            ],
          ),
          if (s.periods.isNotEmpty)
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text(
                  'Recent changes',
                  style: TextStyle(fontSize: 12, color: AppColors.label),
                ),
                children: [for (final p in s.periods) _periodRow(p)],
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label  ',
            style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        Text(value,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  Widget _periodRow(StatusPeriod p) {
    final color = p.online ? AppColors.green : AppColors.red;
    final fmt = DateFormat('dd MMM HH:mm');
    final end = p.end == null ? 'now' : fmt.format(p.end!.toLocal());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Text(
              p.online ? 'Online' : 'Offline',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color),
            ),
          ),
          Expanded(
            child: Text(
              '${fmt.format(p.start.toLocal())}  to  $end',
              style: const TextStyle(fontSize: 11, color: AppColors.label),
            ),
          ),
          Text(
            formatDuration(p.seconds),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
