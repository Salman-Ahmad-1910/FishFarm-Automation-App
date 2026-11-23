import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/pressure_reading.dart';
import '../models/sensor_limit.dart';
import 'alarm_controls.dart';
import 'common_ui.dart';
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
        return AppColors.green;
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

  String get _statusLabel {
    switch (reading.alarmStatus) {
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
    final isLimitAlarm = reading.alarmStatus == 'HIGH_PRESSURE' ||
        reading.alarmStatus == 'LOW_PRESSURE';
    final online = reading.isOnline;
    final onlineColor = online ? AppColors.green : AppColors.muted;
    final hasLimits = limit != null && limit!.min != null && limit!.max != null;

    return AppCard(
      radius: 18,
      padding: const EdgeInsets.all(16),
      borderColor:
          isLimitAlarm ? _statusColor.withValues(alpha: 0.7) : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  reading.displayName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: onlineColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                online ? 'ONLINE' : 'OFFLINE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: onlineColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  reading.sensorId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
              const Text(
                'Alarm',
                style: TextStyle(fontSize: 11, color: AppColors.label),
              ),
              const SizedBox(width: 6),
              AlarmSwitch(sensorId: reading.sensorId),
            ],
          ),
          const SizedBox(height: 10),
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
                color: AppColors.label,
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
              hasLimits
                  ? 'Alarm limits: ${limit!.min!.toStringAsFixed(1)} - '
                      '${limit!.max!.toStringAsFixed(1)} ${reading.unit}'
                  : 'Alarm limits: not set',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.label),
            ),
          ),
          if (isLimitAlarm) ...[
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
            const Text(
              'Sensor offline - no data received.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.muted,
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
                color: AppColors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Last update: ${_formatTime(reading.lastSeen)}',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          if (stale)
            const Text(
              'STALE DATA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.red,
              ),
            ),
        ],
      ),
    );
  }
}
