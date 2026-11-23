class ApiConfig {
  static const String baseUrl = 'http://103.172.26.29:8081';

  static const String currentPressureEndpoint = '/api/pressure/current';
  static const String alarmsEndpoint = '/api/pressure/alarms';

  static const String currentTemperatureEndpoint = '/api/temperature/current';
  static const String temperatureAlarmsEndpoint = '/api/temperature/alarms';

  static Uri currentPressureUri() =>
      Uri.parse('$baseUrl$currentPressureEndpoint');

  static Uri alarmsUri() => Uri.parse('$baseUrl$alarmsEndpoint');

  static Uri currentTemperatureUri() =>
      Uri.parse('$baseUrl$currentTemperatureEndpoint');

  static Uri temperatureAlarmsUri() =>
      Uri.parse('$baseUrl$temperatureAlarmsEndpoint');

  static Uri devicesUri() => Uri.parse('$baseUrl/api/devices');

  static const String limitsEndpoint = '/api/limits';

  static Uri limitsUri() => Uri.parse('$baseUrl$limitsEndpoint');

  static Uri limitUri(String sensorId) =>
      Uri.parse('$baseUrl$limitsEndpoint/$sensorId');
}
