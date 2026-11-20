class SensorLimit {
  final String sensorId;
  final String sensorType; // 'pressure' or 'temperature'
  final String unit; // 'kPa' or 'C'
  final double? min;
  final double? max;
  final String source; // 'custom', 'default' or 'none'
  final double rangeMin;
  final double rangeMax;

  const SensorLimit({
    required this.sensorId,
    required this.sensorType,
    required this.unit,
    required this.min,
    required this.max,
    required this.source,
    required this.rangeMin,
    required this.rangeMax,
  });

  factory SensorLimit.fromJson(Map<String, dynamic> json) {
    double? num0(dynamic v) => v == null ? null : (v as num).toDouble();

    return SensorLimit(
      sensorId: (json['sensor_id'] ?? '').toString(),
      sensorType: (json['sensor_type'] ?? '').toString(),
      unit: (json['unit'] ?? '').toString(),
      min: num0(json['min']),
      max: num0(json['max']),
      source: (json['source'] ?? 'none').toString(),
      rangeMin: num0(json['range_min']) ?? 0,
      rangeMax: num0(json['range_max']) ?? 0,
    );
  }

  bool get isPressure => sensorType == 'pressure';

  String get unitLabel => unit == 'C' ? '°C' : unit;

  /// "temperature_sensor_07" -> "Temperature 07"
  String get displayName {
    final match = RegExp(r'(\d+)$').firstMatch(sensorId);
    final number = match?.group(1);
    final base = isPressure ? 'Pressure' : 'Temperature';
    return number == null ? sensorId : '$base $number';
  }
}
