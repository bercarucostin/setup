// core/router/router_notifier.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:setup/features/auth/providers/providers.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/auth/models/auth_state.dart';
import 'package:go_router/go_router.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref ref;

  RouterNotifier(this.ref) {
    ref.listen<AuthState>(authControllerProvider, (_, __) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = ref.read(authControllerProvider);
    final location = state.uri.toString();

    final isLoggingIn = location == '/login' || location == '/signup';
    final isCompletingProfile =
        location.startsWith('/complete-profile') ||
        location.startsWith('/chronotype') ||
        location.startsWith('/sleep-schedule');

    if (authState is Unauthenticated && !isLoggingIn) {
      return '/login';
    }

    if (authState is IncompleteProfile && !isCompletingProfile) {
      return '/complete-profile';
    }

    if (authState is Authenticated && isLoggingIn) {
      return '/';
    }

    return null;
  }
}
