import 'dart:io' show Platform;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateInfo {
  final bool needsUpdate;
  final bool force;
  final String? latestVersion;
  final String? minSupportedVersion;
  final String? message;
  final String? appStoreUrl;

  const AppUpdateInfo({
    required this.needsUpdate,
    required this.force,
    this.latestVersion,
    this.minSupportedVersion,
    this.message,
    this.appStoreUrl,
  });

  static const none = AppUpdateInfo(needsUpdate: false, force: false);
}

class VersionCheckService {
  final FirebaseRemoteConfig _rc;

  VersionCheckService(this._rc);

  Future<void> init({bool debug = false}) async {
    await _rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: debug ? Duration.zero : const Duration(hours: 1),
      ),
    );

    await _rc.setDefaults(<String, dynamic>{
      'ios_latest_version': '1.0.0',
      'ios_min_supported_version': '1.0.0',
      'ios_force_update': false,
      'ios_update_message': 'A newer version is available.',
      'ios_app_store_url': '',
    });

    await _rc.fetchAndActivate();
  }

  Future<AppUpdateInfo> check() async {
    if (!Platform.isIOS) return AppUpdateInfo.none;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version; // e.g. 1.1.3
    final currentBuild = packageInfo.buildNumber; // e.g. 47

    final latestVersion = _rc.getString('ios_latest_version').trim();
    final minSupportedVersion = _rc
        .getString('ios_min_supported_version')
        .trim();
    final forceUpdate = _rc.getBool('ios_force_update');
    final message = _rc.getString('ios_update_message').trim();
    final appStoreUrl = _rc.getString('ios_app_store_url').trim();

    // Force update if current < min supported
    final mustForce = _compareVersions(currentVersion, minSupportedVersion) < 0;

    // Soft update if current < latest
    final hasNewer = _compareVersions(currentVersion, latestVersion) < 0;

    return AppUpdateInfo(
      needsUpdate: mustForce || hasNewer,
      force: mustForce || forceUpdate,
      latestVersion: latestVersion,
      minSupportedVersion: minSupportedVersion,
      message: message.isEmpty ? null : message,
      appStoreUrl: appStoreUrl.isEmpty ? null : appStoreUrl,
    );
  }

  /// Returns:
  /// -1 if a < b
  ///  0 if a == b
  ///  1 if a > b
  int _compareVersions(String a, String b) {
    final aParts = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final bParts = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = aParts.length > bParts.length
        ? aParts.length
        : bParts.length;
    while (aParts.length < maxLen) aParts.add(0);
    while (bParts.length < maxLen) bParts.add(0);

    for (var i = 0; i < maxLen; i++) {
      if (aParts[i] < bParts[i]) return -1;
      if (aParts[i] > bParts[i]) return 1;
    }
    return 0;
  }
}

Future<void> showUpdateDialog(
  BuildContext context,
  AppUpdateInfo info, {
  String appIconAsset = 'assets/images/app_icon.png', // <- change to your path
}) async {
  if (!info.needsUpdate) return;

  final appStoreUrl = info.appStoreUrl;
  if (appStoreUrl == null || appStoreUrl.isEmpty) return;

  Future<void> openStore() async {
    final uri = Uri.parse(appStoreUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      debugPrint('Could not launch App Store URL: $appStoreUrl');
    }
  }

  final title = info.force ? 'Update required' : 'Update available';
  final description =
      info.message ??
      (info.force
          ? 'Please update to continue using the app.'
          : 'A newer version is available.');

  await showDialog<void>(
    context: context,
    barrierDismissible: !info.force,
    barrierColor: const Color.fromARGB(255, 189, 189, 189),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final colorScheme = theme.colorScheme;

      return PopScope(
        canPop: !info.force,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                color: colorScheme.outlineVariant.withOpacity(0.45),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App icon + subtle glow badge
                  Container(
                    width: 76,
                    height: 76,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primary.withOpacity(0.10),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.18),
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        appIconAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: colorScheme.primaryContainer,
                          child: Icon(
                            Icons.system_update_rounded,
                            size: 38,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if ((info.latestVersion ?? '').isNotEmpty)
                        _VersionPill(
                          label: 'Latest ${info.latestVersion}',
                          icon: Icons.new_releases_outlined,
                        ),
                      if (info.force &&
                          (info.minSupportedVersion ?? '').isNotEmpty)
                        _VersionPill(
                          label: 'Min ${info.minSupportedVersion}',
                          icon: Icons.lock_outline_rounded,
                        ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      if (!info.force) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Later'),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            await openStore();
                            if (!info.force && ctx.mounted) {
                              Navigator.of(ctx).pop();
                            }
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: Text(info.force ? 'Update now' : 'Update'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _VersionPill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _VersionPill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
