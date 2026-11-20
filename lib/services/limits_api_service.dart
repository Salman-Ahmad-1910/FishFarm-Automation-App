import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../config/api_config.dart';
import '../models/sensor_limit.dart';

class LimitsApiService {
  static const Duration _timeout = Duration(seconds: 10);

  http.Client _client() {
    final ioClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return IOClient(ioClient);
  }

  Never _fail(http.Response r) {
    var message = 'Server returned ${r.statusCode}';
    try {
      final decoded = jsonDecode(r.body);
      if (decoded is Map<String, dynamic> && decoded['message'] != null) {
        message = decoded['message'].toString();
      }
    } catch (_) {}
    throw Exception(message);
  }

  Future<T> _guard<T>(Future<T> Function(http.Client client) action) async {
    final client = _client();
    try {
      return await action(client);
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

  SensorLimit _parseOne(http.Response r) {
    if (r.statusCode != 200) _fail(r);
    final decoded = jsonDecode(r.body);
    if (decoded is! Map<String, dynamic> || decoded['data'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid response format');
    }
    return SensorLimit.fromJson(decoded['data'] as Map<String, dynamic>);
  }

  Future<List<SensorLimit>> fetchLimits() {
    return _guard((client) async {
      final r = await client.get(ApiConfig.limitsUri()).timeout(_timeout);
      if (r.statusCode != 200) _fail(r);
      final decoded = jsonDecode(r.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid response format');
      }
      return (decoded['data'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(SensorLimit.fromJson)
          .toList();
    });
  }

  Future<SensorLimit> saveLimit({
    required String sensorId,
    required double min,
    required double max,
  }) {
    return _guard((client) async {
      final r = await client
          .put(
            ApiConfig.limitUri(sensorId),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'min': min, 'max': max}),
          )
          .timeout(_timeout);
      return _parseOne(r);
    });
  }

  Future<SensorLimit> resetLimit({required String sensorId}) {
    return _guard((client) async {
      final r = await client
          .delete(ApiConfig.limitUri(sensorId))
          .timeout(_timeout);
      return _parseOne(r);
    });
  }
}
