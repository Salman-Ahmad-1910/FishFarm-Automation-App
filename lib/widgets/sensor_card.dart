import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/pressure_reading.dart';
import '../models/sensor_limit.dart';
import 'pressure_gauge.dart';

class SensorCard extends StatelessWidget {
  final PressureReading reading;
  final SensorLimit? limit;
  final bool stale;

  const SensorCard({
    super.key,
    required this.reading,
    this.limit,
    this.stale = false,
  });

  Color get _statusColor {
    switch (reading.alarmStatus) {
      case 'NORMAL':
        return const Color(0xFF8BC34A);
      case 'HIGH_PRESSURE':
        return const Color(0xFFF44336);
      case 'LOW_PRESSURE':
        return const Color(0xFFFF9800);
      case 'SENSOR_OFFLINE':
        return const Color(0xFF808B96);
      case 'NOT_CONFIGURED':
        return const Color(0xFF536FC0);
      default:
        return const Color(0xFF808B96);
    }
  }

  String get _statusLabel {
    switch (reading.alarmStatus) {
      case 'NORMAL':
        return 'NORMAL';
      case 'HIGH_PRESSURE':
        return 'HIGH PRESSURE';
      case 'LOW_PRESSURE':
        return 'LOW PRESSURE';
      case 'SENSOR_OFFLINE':
        return 'SENSOR OFFLINE';
      case 'NOT_CONFIGURED':
        return 'NOT CONFIGURED';
      default:
        return reading.alarmStatus;
    }
  }

  String _formatTime(DateTime? time) {
    if (time == null) return 'Never';
    return DateFormat('dd MMM yyyy, HH:mm:ss').format(time.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final isAlarm = reading.alarmStatus == 'HIGH_PRESSURE' ||
        reading.alarmStatus == 'LOW_PRESSURE';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF172633),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2A3F52)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                reading.displayName.toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFAAB8C4),
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              _StatusDot(color: reading.isOnline ? const Color(0xFF8BC34A) : const Color(0xFF808B96)),
              const SizedBox(width: 6),
              Text(
                reading.isOnline ? 'ONLINE' : 'OFFLINE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: reading.isOnline
                      ? const Color(0xFF8BC34A)
                      : const Color(0xFF808B96),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            reading.sensorId,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF808B96),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: PressureGauge(
              value: reading.pressureKpa ?? 0,
              color: _statusColor,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              reading.unit,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFAAB8C4),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _statusColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                _statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _statusColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              limit != null && limit!.min != null && limit!.max != null
                  ? 'Alarm limits: ${limit!.min!.toStringAsFixed(1)} – '
                      '${limit!.max!.toStringAsFixed(1)} ${reading.unit}'
                  : 'Alarm limits: not set',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFAAB8C4),
              ),
            ),
          ),
          if (isAlarm) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                reading.alarmStatus == 'HIGH_PRESSURE'
                    ? 'Pressure above the set upper limit.'
                    : 'Pressure below the set lower limit.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _statusColor,
                ),
              ),
            ),
          ],
          if (reading.alarmStatus == 'SENSOR_OFFLINE') ...[
            const SizedBox(height: 10),
            Text(
              'Sensor offline - no data received.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF808B96),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (reading.alarmStatus == 'NOT_CONFIGURED') ...[
            const SizedBox(height: 10),
            const Text(
              'Thresholds not configured.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF536FC0),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Last update: ${_formatTime(reading.lastSeen)}',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF808B96),
            ),
          ),
          if (stale)
            const Text(
              'STALE DATA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFFF44336),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  const _StatusDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
