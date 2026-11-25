import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';

class UpdateService {
  /// Checks for application updates on Android and Windows clients.
  /// Web clients auto-update on page refresh and are skipped.
  static Future<void> checkForUpdate(BuildContext context) async {
    if (kIsWeb) return;

    try {
      final url = Uri.parse('${ApiService.baseUrl}/app-version');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;
      final currentVersion = packageInfo.version;

      Map<String, dynamic>? platformConfig;
      if (defaultTargetPlatform == TargetPlatform.android) {
        platformConfig = data['android'];
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        platformConfig = data['windows'];
      }

      if (platformConfig == null) return;

      final latestBuildNumber = platformConfig['buildNumber'] as int? ?? 1;
      final latestVersion = platformConfig['version'] as String? ?? '1.0.0';
      final downloadUrl = platformConfig['downloadUrl'] as String? ?? '';
      final forceUpdate = platformConfig['forceUpdate'] as bool? ?? false;
      final releaseNotes = platformConfig['releaseNotes'] as String? ?? 
          'New features, bug fixes, and performance improvements.';

      // Trigger update popup if remote build is strictly newer
      if (latestBuildNumber > currentBuildNumber && context.mounted) {
        _showUpdateDialog(
          context,
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          releaseNotes: releaseNotes,
          downloadUrl: downloadUrl,
          forceUpdate: forceUpdate,
        );
      }
    } catch (e) {
      // Non-blocking: If network fails or server is spinning up, app proceeds normally
      debugPrint('Update check skipped: $e');
    }
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required String currentVersion,
    required String latestVersion,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.system_update_rounded, color: Color(0xFF2563EB), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update Available',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'v$currentVersion ➔ v$latestVersion',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
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
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
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
                  style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13, height: 1.4),
                ),
              ),
              if (forceUpdate) ...[
                const SizedBox(height: 12),
                Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'This update is required to keep syncing with the main office.',
                        style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600),
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
                child: const Text('Later', style: TextStyle(color: Color(0xFF64748B))),
              ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download & Update', style: TextStyle(fontWeight: FontWeight.w600)),
              onPressed: () async {
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

