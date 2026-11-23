import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'alarm_notifier.dart';

/// Runs in a background isolate when a push arrives and the app is closed.
@pragma('vm:entry-point')
Future<void> fishfarmBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await AlarmNotifier.init();
  await AlarmNotifier.handlePush(message.data);
}

class PushService {
  PushService._();

  /// Sets up Firebase push. Safe to call once before runApp; it never throws.
  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(fishfarmBackgroundHandler);
      await AlarmNotifier.init();
      await AlarmNotifier.requestPermission();

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, sound: true);

      // While the app is open the screens ring the alarm themselves; only
      // react here to a "clear" so the notification goes away at once.
      FirebaseMessaging.onMessage.listen((message) {
        if (message.data['type'] == 'clear') {
          AlarmNotifier.cancel((message.data['kind'] ?? 'pressure').toString());
        }
      });

      messaging.onTokenRefresh.listen(_register);
      final token = await messaging.getToken();
      if (token != null) {
        _register(token); // not awaited: the app must start even if offline
      }
    } catch (_) {
      // Push is optional; the in-app alarm still works.
    }
  }

  static Future<void> _register(String token) async {
    try {
      await http
          .post(
            ApiConfig.devicesUri(),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Retried on the next app start.
    }
  }
}
