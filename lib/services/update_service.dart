import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Checks the latest GitHub release and offers to download the new APK.
class UpdateService {
  UpdateService._();

  static const String _owner = 'Salman-Ahmad-1910';
  static const String _repo = 'FishFarm-Automation-App';

  /// [silent] = true is used at app start: it only speaks up when a new
  /// version exists. The Update button uses silent = false and always answers.
  static Future<void> check(BuildContext context, {bool silent = false}) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    void say(String text) {
      if (!silent) {
        messenger?.showSnackBar(SnackBar(content: Text(text)));
      }
    }

    try {
      final info = await PackageInfo.fromPlatform();
      final response = await http
          .get(
            Uri.parse(
                'https://api.github.com/repos/$_owner/$_repo/releases/latest'),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 404) {
        say('No update has been published yet.');
        return;
      }
      if (response.statusCode != 200) {
        say('Could not check for updates (error ${response.statusCode}).');
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (data['tag_name'] ?? '').toString();
      final assets = (data['assets'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList();
      String? apkUrl;
      for (final a in assets) {
        final name = (a['name'] ?? '').toString();
        if (name.endsWith('.apk')) {
          apkUrl = (a['browser_download_url'] ?? '').toString();
          break;
        }
      }

      if (apkUrl == null || apkUrl.isEmpty) {
        say('The latest release has no APK file yet.');
        return;
      }
      if (!_isNewer(tag, info.version)) {
        say('You already have the latest version (${info.version}).');
        return;
      }
      if (!context.mounted) return;

      final go = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Update available'),
          content: Text(
            'New version $tag is ready. You have ${info.version}.\n\n'
            'Tap Update to download it, then open the downloaded file and '
            'tap Install.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Update'),
            ),
          ],
        ),
      );

      if (go == true) {
        final ok = await launchUrl(
          Uri.parse(apkUrl),
          mode: LaunchMode.externalApplication,
        );
        if (!ok) say('Could not open the download link.');
      }
    } catch (_) {
      say('Could not check for updates. Check your internet connection.');
    }
  }

  /// True when [tag] ("v1.0.2") is a higher version than [current] ("1.0.1").
  static bool _isNewer(String tag, String current) {
    List<int> parse(String v) => v
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('+')
        .first
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();

    final a = parse(tag);
    final b = parse(current);
    final length = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < length; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}
