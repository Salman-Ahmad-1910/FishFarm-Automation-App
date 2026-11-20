class TemperatureReading {
  final String sensorId;
  final double? temperatureC;
  final String unit;
  final String alarmStatus;
  final bool isOnline;
  final DateTime? lastSeen;

  const TemperatureReading({
    required this.sensorId,
    required this.temperatureC,
    required this.unit,
    required this.alarmStatus,
    required this.isOnline,
    required this.lastSeen,
  });

  factory TemperatureReading.fromJson(Map<String, dynamic> json) {
    final tempRaw = json['temperature_c'];
    final lastSeenRaw = json['last_seen'];

    DateTime? lastSeen;
    if (lastSeenRaw != null) {
      lastSeen = DateTime.tryParse(lastSeenRaw.toString())?.toUtc();
    }

    return TemperatureReading(
      sensorId: (json['sensor_id'] ?? '').toString(),
      temperatureC: tempRaw == null ? null : (tempRaw as num).toDouble(),
      unit: (json['unit'] ?? 'C').toString(),
      alarmStatus: (json['alarm_status'] ?? 'SENSOR_OFFLINE').toString(),
      isOnline: json['is_online'] == true,
      lastSeen: lastSeen,
    );
  }

  factory TemperatureReading.unavailable(String sensorId) {
    return TemperatureReading(
      sensorId: sensorId,
      temperatureC: null,
      unit: 'C',
      alarmStatus: 'SENSOR_OFFLINE',
      isOnline: false,
      lastSeen: null,
    );
  }

  /// "temperature_sensor_07" -> "Temperature 07"
  String get displayName {
    final match = RegExp(r'(\d+)$').firstMatch(sensorId);
    if (match == null) return sensorId;
    return 'Temperature ${match.group(1)}';
  }
}

class CurrentTemperatureResponse {
  final bool success;
  final List<TemperatureReading> data;

  const CurrentTemperatureResponse({required this.success, required this.data});

  factory CurrentTemperatureResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(TemperatureReading.fromJson)
        .toList();
    return CurrentTemperatureResponse(
      success: json['success'] == true,
      data: list,
    );
  }
}

class ActiveTemperatureAlarmsResponse {
  final bool success;
  final List<TemperatureReading> data;
  final int count;

  const ActiveTemperatureAlarmsResponse({
    required this.success,
    required this.data,
    required this.count,
  });

  factory ActiveTemperatureAlarmsResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(TemperatureReading.fromJson)
        .toList();
    return ActiveTemperatureAlarmsResponse(
      success: json['success'] == true,
      data: list,
      count: (json['count'] as num?)?.toInt() ??
          (json['active_alarm_count'] as num?)?.toInt() ??
          list.length,
    );
  }
}
