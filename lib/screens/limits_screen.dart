import 'package:flutter/material.dart';

import '../models/sensor_limit.dart';
import '../services/limits_api_service.dart';

const Color _cardBg = Color(0xFF172633);
const Color _cardBorder = Color(0xFF2A3F52);
const Color _muted = Color(0xFF808B96);
const Color _label = Color(0xFFAAB8C4);
const Color _green = Color(0xFF8BC34A);
const Color _red = Color(0xFFF44336);
const Color _orange = Color(0xFFFF9800);
const Color _blue = Color(0xFF536FC0);

class LimitsScreen extends StatefulWidget {
  const LimitsScreen({super.key});

  @override
  State<LimitsScreen> createState() => _LimitsScreenState();
}

class _LimitsScreenState extends State<LimitsScreen> {
  final LimitsApiService _service = LimitsApiService();

  List<SensorLimit>? _limits;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = _limits == null);
    try {
      final limits = await _service.fetchLimits();
      if (!mounted) return;
      setState(() {
        _limits = limits;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _edit(SensorLimit limit) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => _LimitDialog(service: _service, limit: limit),
    );
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final limits = _limits;
    final pressure = limits?.where((l) => l.isPressure).toList() ?? <SensorLimit>[];
    final temperature = limits?.where((l) => !l.isPressure).toList() ?? <SensorLimit>[];

    return Scaffold(
      backgroundColor: const Color(0xFF263746),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: _blue,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const _HeaderCard(),
              const SizedBox(height: 14),
              if (_error != null) ...[
                _ErrorBanner(message: _error!),
                const SizedBox(height: 14),
              ],
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator(color: _blue)),
                )
              else ...[
                if (pressure.isNotEmpty) ...[
                  const _SectionTitle('PRESSURE SENSORS'),
                  for (final l in pressure) _LimitTile(limit: l, onTap: () => _edit(l)),
                  const SizedBox(height: 12),
                ],
                if (temperature.isNotEmpty) ...[
                  const _SectionTitle('TEMPERATURE SENSORS'),
                  for (final l in temperature) _LimitTile(limit: l, onTap: () => _edit(l)),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: const Row(
        children: [
          Icon(Icons.tune_rounded, color: _blue, size: 26),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alarm Limits',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'The alarm starts when a reading goes above the upper limit '
                  'or below the lower limit. Tap a sensor to change its limits. '
                  'Changes apply to the backend and dashboard immediately.',
                  style: TextStyle(fontSize: 12, color: _label),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _label,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _LimitTile extends StatelessWidget {
  final SensorLimit limit;
  final VoidCallback onTap;

  const _LimitTile({required this.limit, required this.onTap});

  String _fmt(double? v) => v == null ? '--' : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final hasLimits = limit.min != null && limit.max != null;
    final sourceColor = limit.source == 'custom'
        ? _green
        : (limit.source == 'default' ? _blue : _orange);
    final sourceText = limit.source == 'custom'
        ? 'CUSTOM'
        : (limit.source == 'default' ? 'DEFAULT' : 'NOT SET');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cardBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      limit.displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasLimits
                          ? 'Lower ${_fmt(limit.min)}   Upper ${_fmt(limit.max)} ${limit.unitLabel}'
                          : 'No limits set - alarm disabled',
                      style: TextStyle(
                        fontSize: 12,
                        color: hasLimits ? _label : _orange,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: sourceColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: sourceColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  sourceText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: sourceColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.edit_rounded, size: 18, color: _muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _red.withValues(alpha: 0.4)),
      ),
      child: Text(
        'Could not load limits: $message',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _red,
        ),
      ),
    );
  }
}

class _LimitDialog extends StatefulWidget {
  final LimitsApiService service;
  final SensorLimit limit;

  const _LimitDialog({required this.service, required this.limit});

  @override
  State<_LimitDialog> createState() => _LimitDialogState();
}

class _LimitDialogState extends State<_LimitDialog> {
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final l = widget.limit;
    _minCtrl = TextEditingController(text: l.min?.toString() ?? '');
    _maxCtrl = TextEditingController(text: l.max?.toString() ?? '');
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  double? _parse(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    final l = widget.limit;
    final min = _parse(_minCtrl.text);
    final max = _parse(_maxCtrl.text);

    String? problem;
    if (min == null || max == null) {
      problem = 'Enter both limits as numbers.';
    } else if (min >= max) {
      problem = 'The lower limit must be less than the upper limit.';
    } else if (min < l.rangeMin || max > l.rangeMax) {
      problem =
          'Limits must be between ${l.rangeMin.toStringAsFixed(0)} and ${l.rangeMax.toStringAsFixed(0)} ${l.unitLabel}.';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    await _run(
      () => widget.service.saveLimit(
        sensorId: l.sensorId,
        min: min!,
        max: max!,
      ),
      'Limits saved for ${l.displayName}',
    );
  }

  Future<void> _reset() async {
    final l = widget.limit;
    await _run(
      () => widget.service.resetLimit(sensorId: l.sensorId),
      'Limits for ${l.displayName} reset to default',
    );
  }

  Future<void> _run(
    Future<SensorLimit> Function() action,
    String successMessage,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      Navigator.of(context).pop(successMessage);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  InputDecoration _decoration(String label, {String? suffix}) {
    return InputDecoration(
      labelText: label,
      suffixText: suffix,
      border: const OutlineInputBorder(),
      isDense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.limit;
    const numberKeyboard = TextInputType.numberWithOptions(decimal: true, signed: true);

    return AlertDialog(
      backgroundColor: _cardBg,
      title: Text(l.displayName),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Allowed range: ${l.rangeMin.toStringAsFixed(0)} to ${l.rangeMax.toStringAsFixed(0)} ${l.unitLabel}',
              style: const TextStyle(fontSize: 12, color: _label),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _minCtrl,
              keyboardType: numberKeyboard,
              enabled: !_busy,
              decoration: _decoration('Lower limit', suffix: l.unitLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _maxCtrl,
              keyboardType: numberKeyboard,
              enabled: !_busy,
              decoration: _decoration('Upper limit', suffix: l.unitLabel),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _red,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (l.source == 'custom')
          TextButton(
            onPressed: _busy ? null : _reset,
            child: const Text('Reset to default'),
          ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
