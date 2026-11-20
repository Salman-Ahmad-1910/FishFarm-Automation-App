class PressureReading {
  final String sensorId;
  final double? pressureKpa;
  final String unit;
  final String alarmStatus;
  final bool isOnline;
  final DateTime? lastSeen;

  const PressureReading({
    required this.sensorId,
    required this.pressureKpa,
    required this.unit,
    required this.alarmStatus,
    required this.isOnline,
    required this.lastSeen,
  });

  factory PressureReading.fromJson(Map<String, dynamic> json) {
    final pressureRaw = json['pressure_kpa'];
    final lastSeenRaw = json['last_seen'];

    DateTime? lastSeen;
    if (lastSeenRaw != null) {
      lastSeen = DateTime.tryParse(lastSeenRaw.toString())?.toUtc();
    }

    return PressureReading(
      sensorId: (json['sensor_id'] ?? '').toString(),
      pressureKpa: pressureRaw == null ? null : (pressureRaw as num).toDouble(),
      unit: (json['unit'] ?? 'kPa').toString(),
      alarmStatus: (json['alarm_status'] ?? 'SENSOR_OFFLINE').toString(),
      isOnline: json['is_online'] == true,
      lastSeen: lastSeen,
    );
  }

  factory PressureReading.unavailable(String sensorId) {
    return PressureReading(
      sensorId: sensorId,
      pressureKpa: null,
      unit: 'kPa',
      alarmStatus: 'SENSOR_OFFLINE',
      isOnline: false,
      lastSeen: null,
    );
  }

  String get displayName {
    if (sensorId == 'pressure_sensor_01') return 'Pressure Sensor 01';
    if (sensorId == 'pressure_sensor_02') return 'Pressure Sensor 02';
    return sensorId;
  }
}

class CurrentPressureResponse {
  final bool success;
  final List<PressureReading> data;

  const CurrentPressureResponse({required this.success, required this.data});

  factory CurrentPressureResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(PressureReading.fromJson)
        .toList();
    return CurrentPressureResponse(
      success: json['success'] == true,
      data: list,
    );
  }
}

class ActiveAlarmsResponse {
  final bool success;
  final List<PressureReading> data;
  final int count;

  const ActiveAlarmsResponse({
    required this.success,
    required this.data,
    required this.count,
  });

  factory ActiveAlarmsResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(PressureReading.fromJson)
        .toList();
    return ActiveAlarmsResponse(
      success: json['success'] == true,
      data: list,
      count: (json['count'] as num?)?.toInt() ??
          (json['active_alarm_count'] as num?)?.toInt() ??
          list.length,
    );
  }
}
