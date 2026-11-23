import 'package:flutter/material.dart';

import '../services/alarm_settings.dart';
import '../services/update_service.dart';
import 'common_ui.dart';

/// Small on/off switch for ONE sensor's alarm.
class AlarmSwitch extends StatelessWidget {
  final String sensorId;
  const AlarmSwitch({super.key, required this.sensorId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AlarmSettings.instance,
      builder: (context, _) {
        final s = AlarmSettings.instance;
        final on = s.sensorSwitch(sensorId);
        return Tooltip(
          message: on ? 'Alarm ON for this sensor' : 'Alarm OFF for this sensor',
          child: Opacity(
            opacity: s.master ? 1 : 0.45,
            child: SizedBox(
              width: 42,
              height: 28,
              child: FittedBox(
                child: Switch(
                  value: on,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  activeThumbColor: AppColors.green,
                  onChanged: (v) => s.setSensor(sensorId, v),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One switch for every sensor on a page (all Pressure / all Temperature).
class PageAlarmToggle extends StatelessWidget {
  final String label; // 'Pressure' or 'Temperature'
  final List<String> sensorIds;

  const PageAlarmToggle({
    super.key,
    required this.label,
    required this.sensorIds,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AlarmSettings.instance,
      builder: (context, _) {
        final s = AlarmSettings.instance;
        final onCount = sensorIds.where(s.sensorSwitch).length;
        final allOn = onCount == sensorIds.length;
        final subtitle = !s.master
            ? 'All alarms are switched off at the top'
            : (allOn
                ? 'Alarm ON for all ${sensorIds.length} sensor${sensorIds.length == 1 ? '' : 's'}'
                : '$onCount of ${sensorIds.length} sensors have alarm ON');
        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          borderColor: onCount > 0 && s.master
              ? AppColors.green.withValues(alpha: 0.4)
              : AppColors.border,
          child: Row(
            children: [
              Icon(
                onCount > 0 && s.master
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_rounded,
                color: onCount > 0 && s.master
                    ? AppColors.green
                    : AppColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$label alarms',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.label),
                    ),
                  ],
                ),
              ),
              Switch(
                value: allOn,
                activeThumbColor: AppColors.green,
                onChanged: (v) => s.setMany(sensorIds, v),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Switch at the very top of the app: all alarms of all sensors.
class MasterAlarmBar extends StatelessWidget {
  const MasterAlarmBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AlarmSettings.instance,
      builder: (context, _) {
        final s = AlarmSettings.instance;
        final on = s.master;
        final color = on ? AppColors.green : AppColors.red;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Icon(
                    on
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_rounded,
                    color: color,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ALL ALARMS',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.6,
                          ),
                        ),
                        Text(
                          on
                              ? 'ON - sensors with alarm ON will ring'
                              : 'OFF - no sensor will ring',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Check for app update',
                    onPressed: () => UpdateService.check(context),
                    icon: const Icon(Icons.system_update_alt_rounded,
                        color: AppColors.label),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  Switch(
                    value: on,
                    activeThumbColor: AppColors.green,
                    onChanged: (v) => s.setMaster(v),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
