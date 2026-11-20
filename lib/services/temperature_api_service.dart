import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../config/api_config.dart';
import '../models/temperature_reading.dart';

class TemperatureApiService {
  static const Duration _timeout = Duration(seconds: 10);

  http.Client _client() {
    final ioClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return IOClient(ioClient);
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final client = _client();
    try {
      final response = await client.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid response format');
      }
      return decoded;
    } on SocketException {
      throw Exception('Unable to reach the server');
    } on HttpException {
      throw Exception('HTTP error while contacting the server');
    } on FormatException {
      throw Exception('Invalid JSON received from the server');
    } finally {
      client.close();
    }
  }

  Future<CurrentTemperatureResponse> fetchCurrent() async {
    final decoded = await _getJson(ApiConfig.currentTemperatureUri());
    final parsed = CurrentTemperatureResponse.fromJson(decoded);
    if (!parsed.success) {
      throw Exception('Backend reported an unsuccessful response');
    }
    return parsed;
  }

  Future<ActiveTemperatureAlarmsResponse> fetchAlarms() async {
    final decoded = await _getJson(ApiConfig.temperatureAlarmsUri());
    final parsed = ActiveTemperatureAlarmsResponse.fromJson(decoded);
    if (!parsed.success) {
      throw Exception('Backend reported an unsuccessful response');
    }
    return parsed;
  }
}
