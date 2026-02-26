import 'package:Watt/features/router/models/router.dart';
import 'package:Watt/version_checker/app_updater.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Watt/features/router/models/router.dart'; // where rootNavigatorKey lives

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        return _VersionUpdateGate(child: child ?? const SizedBox.shrink());
      },
    );
  }
}

class _VersionUpdateGate extends StatefulWidget {
  final Widget child;
  const _VersionUpdateGate({required this.child});

  @override
  State<_VersionUpdateGate> createState() => _VersionUpdateGateState();
}

class _VersionUpdateGateState extends State<_VersionUpdateGate>
    with WidgetsBindingObserver {
  late final VersionCheckService _versionService;

  bool _initialized = false;
  bool _checking = false;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _versionService = VersionCheckService(FirebaseRemoteConfig.instance);

    // Run once after UI is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runVersionCheck();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Check again when the app returns to foreground
    if (state == AppLifecycleState.resumed) {
      _runVersionCheck();
    }
  }

  Future<void> _runVersionCheck() async {
    if (!mounted || _checking || _dialogOpen) return;
    _checking = true;

    try {
      if (!_initialized) {
        await _versionService.init(debug: kDebugMode);
        _initialized = true;
      } else {
        await FirebaseRemoteConfig.instance.fetchAndActivate();
      }

      final info = await _versionService.check();
      if (!mounted || !info.needsUpdate) return;

      // ✅ Get a context that is actually under the Navigator
      final navContext = rootNavigatorKey.currentContext;
      if (navContext == null) {
        debugPrint('Version check skipped: navigator context not ready yet.');
        return;
      }

      _dialogOpen = true;
      await showUpdateDialog(navContext, info); // ✅ use navContext
    } catch (e) {
      debugPrint('Version check failed: $e');
    } finally {
      _checking = false;
      _dialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
