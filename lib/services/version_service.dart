import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VersionService {
  final _supabase = Supabase.instance.client;

  Future<VersionCheckResult> checkVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version; // pubspec.yaml se — e.g. "1.0.0"

      final data = await _supabase
          .from('app_settings')
          .select(
              'min_app_version, latest_app_version, update_message, apk_download_url')
          .limit(1)
          .maybeSingle();

      if (data == null) return VersionCheckResult.upToDate(currentVersion);

      final minVersion = data['min_app_version'] as String? ?? '1.0.0';
      final latestVersion = data['latest_app_version'] as String? ?? '1.0.0';
      final message = data['update_message'] as String? ??
          'A new version is available! Update now for a better experience.';
      final apkUrl = data['apk_download_url'] as String? ?? '';

      final isForceUpdate = _isOlderThan(currentVersion, minVersion);
      final isSoftUpdate =
          _isOlderThan(currentVersion, latestVersion) && !isForceUpdate;

      return VersionCheckResult(
        currentVersion: currentVersion,
        minVersion: minVersion,
        latestVersion: latestVersion,
        message: message,
        apkUrl: apkUrl,
        isForceUpdate: isForceUpdate,
        isSoftUpdate: isSoftUpdate,
      );
    } catch (e) {
      // If version check fails, let app run normally
      return VersionCheckResult.upToDate('0.0.0');
    }
  }

  // Compare "1.0.0" vs "1.0.1" — is current version older?
  bool _isOlderThan(String current, String minimum) {
    try {
      final c = current.split('.').map(int.parse).toList();
      final m = minimum.split('.').map(int.parse).toList();
      for (int i = 0; i < 3; i++) {
        final cv = i < c.length ? c[i] : 0;
        final mv = i < m.length ? m[i] : 0;
        if (cv < mv) return true;
        if (cv > mv) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

class VersionCheckResult {
  final String currentVersion;
  final String minVersion;
  final String latestVersion;
  final String message;
  final String apkUrl;
  final bool isForceUpdate;
  final bool isSoftUpdate;

  VersionCheckResult({
    required this.currentVersion,
    required this.minVersion,
    required this.latestVersion,
    required this.message,
    required this.apkUrl,
    required this.isForceUpdate,
    required this.isSoftUpdate,
  });

  factory VersionCheckResult.upToDate(String version) => VersionCheckResult(
        currentVersion: version,
        minVersion: version,
        latestVersion: version,
        message: '',
        apkUrl: '',
        isForceUpdate: false,
        isSoftUpdate: false,
      );
}
