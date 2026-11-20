import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../config/api_config.dart';
import '../models/pressure_reading.dart';

class PressureApiService {
  static const Duration _timeout = Duration(seconds: 10);

  http.Client _client() {
    final ioClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return IOClient(ioClient);
  }

  Future<CurrentPressureResponse> fetchCurrent() async {
    final client = _client();
    try {
      final response = await client
          .get(ApiConfig.currentPressureUri())
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid response format');
      }

      final parsed = CurrentPressureResponse.fromJson(decoded);
      if (!parsed.success) {
        throw Exception('Backend reported an unsuccessful response');
      }
      return parsed;
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

  Future<ActiveAlarmsResponse> fetchAlarms() async {
    final client = _client();
    try {
      final response = await client.get(ApiConfig.alarmsUri()).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid response format');
      }

      final parsed = ActiveAlarmsResponse.fromJson(decoded);
      if (!parsed.success) {
        throw Exception('Backend reported an unsuccessful response');
      }
      return parsed;
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
}
