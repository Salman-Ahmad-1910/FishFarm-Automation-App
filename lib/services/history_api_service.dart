import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/history.dart';

class HistoryApiService {
  static const Duration _timeout = Duration(seconds: 15);

  Future<Map<String, dynamic>> _get(Uri uri) async {
    try {
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['success'] != true) {
        throw Exception('Unexpected response from the server');
      }
      return decoded;
    } on SocketException {
      throw Exception('Unable to reach the server');
    } on FormatException {
      throw Exception('Invalid JSON received from the server');
    }
  }

  /// 6-hour averages for "pressure" or "temperature".
  Future<List<HistorySeries>> fetchReadings(String kind) async {
    final body = await _get(ApiConfig.historyReadingsUri(kind));
    final data = body['data'] as List<dynamic>? ?? <dynamic>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(HistorySeries.fromJson)
        .toList();
  }

  /// Online / offline time of every sensor.
  Future<List<SensorStatus>> fetchStatus() async {
    final body = await _get(ApiConfig.historyStatusUri());
    final data = body['data'] as List<dynamic>? ?? <dynamic>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(SensorStatus.fromJson)
        .toList();
  }
}
