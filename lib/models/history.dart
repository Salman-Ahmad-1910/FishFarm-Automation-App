/// One 6-hour average of a sensor.
class HistoryPoint {
  final DateTime start;
  final double avg;
  final double min;
  final double max;
  final int samples;

  const HistoryPoint({
    required this.start,
    required this.avg,
    required this.min,
    required this.max,
    required this.samples,
  });

  DateTime get end => start.add(const Duration(hours: 6));

  factory HistoryPoint.fromJson(Map<String, dynamic> json) {
    return HistoryPoint(
      start: DateTime.parse(json['start'].toString()).toUtc(),
      avg: (json['avg'] as num).toDouble(),
      min: (json['min'] as num).toDouble(),
      max: (json['max'] as num).toDouble(),
      samples: (json['samples'] as num?)?.toInt() ?? 0,
    );
  }
}

/// All 6-hour averages of one sensor, oldest first.
class HistorySeries {
  final String sensorId;
  final List<HistoryPoint> points;

  const HistorySeries({required this.sensorId, required this.points});

  factory HistorySeries.fromJson(Map<String, dynamic> json) {
    final raw = json['points'] as List<dynamic>? ?? <dynamic>[];
    return HistorySeries(
      sensorId: (json['sensor_id'] ?? '').toString(),
      points: raw
          .whereType<Map<String, dynamic>>()
          .map(HistoryPoint.fromJson)
          .toList(),
    );
  }
}

/// One stretch of time a sensor was online or offline.
class StatusPeriod {
  final bool online;
  final DateTime start;
  final DateTime? end;
  final int seconds;

  const StatusPeriod({
    required this.online,
    required this.start,
    required this.end,
    required this.seconds,
  });

  factory StatusPeriod.fromJson(Map<String, dynamic> json) {
    final endRaw = json['end'];
    return StatusPeriod(
      online: json['online'] == true,
      start: DateTime.parse(json['start'].toString()).toUtc(),
      end: endRaw == null ? null : DateTime.parse(endRaw.toString()).toUtc(),
      seconds: (json['seconds'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Online / offline totals of one sensor.
class SensorStatus {
  final String sensorId;
  final bool isOnline;
  final DateTime? since;
  final int onlineSeconds;
  final int offlineSeconds;
  final int offlineCount;
  final List<StatusPeriod> periods;

  const SensorStatus({
    required this.sensorId,
    required this.isOnline,
    required this.since,
    required this.onlineSeconds,
    required this.offlineSeconds,
    required this.offlineCount,
    required this.periods,
  });

  double get onlineRatio {
    final total = onlineSeconds + offlineSeconds;
    if (total <= 0) return isOnline ? 1 : 0;
    return onlineSeconds / total;
  }

  factory SensorStatus.fromJson(Map<String, dynamic> json) {
    final raw = json['periods'] as List<dynamic>? ?? <dynamic>[];
    final sinceRaw = json['since'];
    return SensorStatus(
      sensorId: (json['sensor_id'] ?? '').toString(),
      isOnline: json['is_online'] == true,
      since:
          sinceRaw == null ? null : DateTime.tryParse(sinceRaw.toString())?.toUtc(),
      onlineSeconds: (json['online_seconds'] as num?)?.toInt() ?? 0,
      offlineSeconds: (json['offline_seconds'] as num?)?.toInt() ?? 0,
      offlineCount: (json['offline_count'] as num?)?.toInt() ?? 0,
      periods: raw
          .whereType<Map<String, dynamic>>()
          .map(StatusPeriod.fromJson)
          .toList(),
    );
  }
}

/// "pressure_sensor_01" -> "Pressure 01", "temperature_sensor_05" -> "Temperature 05".
String historySensorLabel(String sensorId) {
  final parts = sensorId.split('_');
  if (parts.length < 3) return sensorId;
  final kind = parts.first.isEmpty
      ? parts.first
      : parts.first[0].toUpperCase() + parts.first.substring(1);
  return '$kind ${parts.last}';
}

/// 4350 -> "1h 12m", 90000 -> "1d 1h", 40 -> "40s".
String formatDuration(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  final d = s ~/ 86400;
  final h = (s % 86400) ~/ 3600;
  final m = (s % 3600) ~/ 60;
  if (d > 0) return '${d}d ${h}h';
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m';
  return '${s}s';
}
