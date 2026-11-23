import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which alarms are switched on. Saved on the phone, so push alarms that
/// arrive while the app is closed obey the same switches.
///
///  * one MASTER switch (all alarms of all sensors)
///  * one switch per page (all Pressure sensors / all Temperature sensors)
///  * one switch per sensor
class AlarmSettings extends ChangeNotifier {
  AlarmSettings._();
  static final AlarmSettings instance = AlarmSettings._();

  static const String _masterKey = 'alarm_master_on';
  static String _sensorKey(String id) => 'alarm_sensor_on_$id';

  bool _master = true;
  final Map<String, bool> _sensors = {};
  bool _loaded = false;

  bool get loaded => _loaded;
  bool get master => _master;

  /// True when this sensor's own switch is on (ignores the master switch).
  bool sensorSwitch(String id) => _sensors[id] ?? true;

  /// True when this sensor may ring (master AND its own switch are on).
  bool sensorActive(String id) => _master && sensorSwitch(id);

  /// True when every sensor in the list has its own switch on.
  bool allOn(Iterable<String> ids) => ids.every(sensorSwitch);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    _master = prefs.getBool(_masterKey) ?? true;
    _sensors.clear();
    for (final key in prefs.getKeys()) {
      if (key.startsWith('alarm_sensor_on_')) {
        _sensors[key.substring('alarm_sensor_on_'.length)] =
            prefs.getBool(key) ?? true;
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMaster(bool on) async {
    _master = on;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_masterKey, on);
  }

  Future<void> setSensor(String id, bool on) async {
    _sensors[id] = on;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sensorKey(id), on);
  }

  Future<void> setMany(Iterable<String> ids, bool on) async {
    final list = ids.toList();
    for (final id in list) {
      _sensors[id] = on;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    for (final id in list) {
      await prefs.setBool(_sensorKey(id), on);
    }
  }

  /// For the background isolate: reads the switches straight from disk and
  /// answers "may this sensor ring?".
  static Future<bool Function(String id)> readActiveCheck() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final master = prefs.getBool(_masterKey) ?? true;
    return (String id) => master && (prefs.getBool(_sensorKey(id)) ?? true);
  }
}
