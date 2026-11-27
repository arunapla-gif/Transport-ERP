import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'web_reload_stub.dart' if (dart.library.html) 'web_reload_web.dart';

class UpdateService {
  // Compiled into the app bundle so open Web tabs know their exact running build.
  static const String appVersion = '1.0.11';
  static const int appBuildNumber = 12;
  static String get buildLabel => 'v$appVersion (b$appBuildNumber)';

  /// Checks for application updates on Web, Android, and Windows clients.
  static Future<void> checkForUpdate(BuildContext context,
      {bool manual = false}) async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/app-version');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        if (manual && context.mounted) {
          _showStatusSnackBar(context, 'Could not check for updates right now.',
              isError: true);
        }
        return;
      }

      final data = jsonDecode(response.body);
      int currentBuildNumber = appBuildNumber;
      String currentVersion = appVersion;

      if (!kIsWeb) {
        final packageInfo = await PackageInfo.fromPlatform();
        currentBuildNumber =
            int.tryParse(packageInfo.buildNumber) ?? appBuildNumber;
        currentVersion = packageInfo.version;
      }

      Map<String, dynamic>? platformConfig;
      if (kIsWeb) {
        platformConfig = data['web'] as Map<String, dynamic>?;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        platformConfig = data['android'] as Map<String, dynamic>?;
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        platformConfig = data['windows'] as Map<String, dynamic>?;
      }

      if (platformConfig == null) {
        if (manual && context.mounted) {
          _showStatusSnackBar(
              context, 'You are on the latest version ($buildLabel).');
        }
        return;
      }

      final latestBuildNumber = platformConfig['buildNumber'] as int? ?? 1;
      final latestVersion = platformConfig['version'] as String? ?? '1.0.0';
      final downloadUrl = platformConfig['downloadUrl'] as String? ?? '';
      final forceUpdate = platformConfig['forceUpdate'] as bool? ?? false;
      final releaseNotes = platformConfig['releaseNotes'] as String? ??
          'New features, bug fixes, and performance improvements.';

      if (latestBuildNumber > currentBuildNumber && context.mounted) {
        _showUpdateDialog(
          context,
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          latestBuildNumber: latestBuildNumber,
          releaseNotes: releaseNotes,
          downloadUrl: downloadUrl,
          forceUpdate: forceUpdate,
        );
      } else if (manual && context.mounted) {
        _showStatusSnackBar(
          context,
          'You are on the latest version (v$currentVersion • b$currentBuildNumber).',
        );
      }
    } catch (e) {
      debugPrint('Update check skipped: $e');
      if (manual && context.mounted) {
        _showStatusSnackBar(context, 'Update check failed: $e', isError: true);
      }
    }
  }

  static void _showStatusSnackBar(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          backgroundColor:
              isError ? const Color(0xFFE11D48) : const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          width: 420,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required String currentVersion,
    required String latestVersion,
    required int latestBuildNumber,
    required String releaseNotes,
    required String downloadUrl,
    required bool forceUpdate,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) => PopScope(
        canPop: !forceUpdate,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.system_update_rounded,
                    color: Color(0xFF2563EB), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update Available',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'v$currentVersion ➔ v$latestVersion (b$latestBuildNumber)',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Release Highlights:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569)),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  releaseNotes,
                  style: const TextStyle(
                      color: Color(0xFF1E293B), fontSize: 13, height: 1.4),
                ),
              ),
              if (forceUpdate) ...[
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.red, size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'This update is required to keep syncing with the main office.',
                        style: TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Later',
                    style: TextStyle(color: Color(0xFF64748B))),
              ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              icon: kIsWeb
                  ? const Icon(Icons.refresh_rounded, size: 18)
                  : const Icon(Icons.download_rounded, size: 18),
              label: kIsWeb
                  ? const Text('Reload Now',
                      style: TextStyle(fontWeight: FontWeight.w600))
                  : const Text('Download & Update',
                      style: TextStyle(fontWeight: FontWeight.w600)),
              onPressed: () async {
                if (kIsWeb) {
                  reloadWebApp();
                  return;
                }
                if (downloadUrl.isNotEmpty) {
                  final uri = Uri.parse(downloadUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
