// core/router/router_notifier.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import 'package:go_router/go_router.dart';

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this.ref) {
    ref.listen<AuthState>(authControllerProvider, (_, __) {
      notifyListeners();
    });
  }

  final Ref ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = ref.read(authControllerProvider);
    final isAuth = authState is Authenticated;
    final isAuthPage =
        state.fullPath == '/login' || state.fullPath == '/signup';

    if (!isAuth && !isAuthPage) return '/login';
    if (isAuth && isAuthPage) return '/';

    return null;
  }
}
