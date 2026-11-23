import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'alarm_settings.dart';

/// Rings the alarm using a real Android alarm notification.
///
/// The notification uses the phone's alarm ringtone on the ALARM audio
/// stream with the INSISTENT flag, so the sound keeps repeating until the
/// notification is dismissed (tap SILENCE, swipe it away, or the alarm
/// clears). It works in the foreground and in the background.
///
/// Whether a sensor may ring is decided by [AlarmSettings] (master switch,
/// page switch and per-sensor switch).
class AlarmNotifier {
  AlarmNotifier._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const String _channelId = 'fishfarm_alarm_v1';
  static const String _channelName = 'Fish farm alarms';
  static const String _alarmUri = 'content://settings/system/alarm_alert';
  static const Map<String, int> _ids = {'pressure': 1001, 'temperature': 1002};
  static const Map<String, String> _titles = {
    'pressure': 'Pressure alarm',
    'temperature': 'Temperature alarm',
  };

  static final Map<String, int> _lastCount = {};

  static Future<void> init() async {
    if (_ready) return;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Sensor alarms',
        importance: Importance.max,
        playSound: true,
        sound: UriAndroidNotificationSound(_alarmUri),
        enableVibration: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
    );
    _ready = true;
  }

  /// Asks for the Android 13+ notification permission.
  static Future<void> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  static int _id(String kind) => _ids[kind] ?? 1000;

  static Future<bool> isShowing(String kind) async {
    await init();
    final active = await _plugin.getActiveNotifications();
    return active.any((n) => n.id == _id(kind));
  }

  /// Shows (or re-shows) the alarm notification; the sound repeats until it
  /// is dismissed.
  static Future<void> show(String kind, String title, String body) async {
    await init();
    final details = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Sensor alarms',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      sound: const UriAndroidNotificationSound(_alarmUri),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      autoCancel: true,
      ongoing: false,
      // 4 = FLAG_INSISTENT: repeat the sound until the notification is gone.
      additionalFlags: Int32List.fromList(<int>[4]),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'silence',
          'SILENCE',
          cancelNotification: true,
        ),
      ],
    );
    await _plugin.show(
      _id(kind),
      title,
      body,
      NotificationDetails(android: details),
    );
  }

  static Future<void> cancel(String kind) async {
    await init();
    _lastCount[kind] = 0;
    await _plugin.cancel(_id(kind));
  }

  /// Called by the screens after every refresh and after every switch change.
  /// [alarming] holds the display names of the sensors that are in alarm AND
  /// allowed to ring. It rings when the first one appears or when more are
  /// added, and stops when the list becomes empty.
  static Future<void> sync(String kind, List<String> alarming) async {
    try {
      final before = _lastCount[kind] ?? 0;
      _lastCount[kind] = alarming.length;
      if (alarming.isEmpty) {
        if (before > 0) await _plugin.cancel(_id(kind));
        return;
      }
      if (before == 0 && await isShowing(kind)) return; // already ringing
      if (alarming.length > before) {
        await show(kind, '${_titles[kind]} (${alarming.length})',
            _summary(alarming));
      }
    } catch (_) {
      // Never let a notification problem break the screen.
    }
  }

  static String _summary(List<String> names) {
    if (names.length <= 3) return names.join(', ');
    return '${names.take(3).join(', ')} +${names.length - 3} more';
  }

  /// Handles an alarm push while the app is closed or in the background.
  /// The server sends the sensor ids in "sensors" and one matching text per
  /// sensor in "items" (separated by "|"). Sensors that are switched off
  /// here are dropped; if none are left, nothing rings.
  static Future<void> handlePush(Map<String, dynamic> data) async {
    final kind = (data['kind'] ?? 'pressure').toString();
    if (data['type'] == 'clear') {
      await cancel(kind);
      return;
    }
    final ids = (data['sensors'] ?? '')
        .toString()
        .split(',')
        .where((s) => s.isNotEmpty)
        .toList();
    final items = (data['items'] ?? '').toString().split('|');
    final mayRing = await AlarmSettings.readActiveCheck();

    final shown = <String>[];
    if (ids.isEmpty) {
      // Older server message without sensor details.
      if (mayRing('*master*')) {
        shown.add((data['body'] ?? '').toString());
      }
    } else {
      for (var i = 0; i < ids.length; i++) {
        if (mayRing(ids[i])) {
          shown.add(i < items.length && items[i].isNotEmpty ? items[i] : ids[i]);
        }
      }
    }

    if (shown.isEmpty) {
      await cancel(kind);
      return;
    }
    await show(kind, '${_titles[kind]} (${shown.length})', _summary(shown));
  }
}
