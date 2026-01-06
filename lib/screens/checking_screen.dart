import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:peak_flow/features/auth/models/auth_state.dart';
import 'package:peak_flow/features/auth/providers/auth_controller_provider.dart';
import 'package:peak_flow/screens/auth/sign_in.dart';
import 'package:peak_flow/screens/home_screen.dart';
import 'package:peak_flow/screens/profile_configuration/onboarding_flow_screen.dart';

class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    debugPrint('RootGate auth=${auth.runtimeType}');

    if (auth is AuthLoading || auth is CheckingProfile) {
      return const CheckingScreen(); // spinner
    }

    if (auth is Unauthenticated) {
      return const SignInScreen();
    }

    if (auth is IncompleteProfile) {
      return const OnboardingFlowScreen();
    }

    if (auth is Authenticated) {
      return const HomeScreen(); // ✅ only here
    }

    // Fallback
    return const CheckingScreen();
  }
}

class CheckingScreen extends StatelessWidget {
  const CheckingScreen({super.key, this.message = 'Setting things up…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1E2C), Color(0xFF2B5876), Color(0xFF4E4376)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Container(
                width: 320,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 22,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset('assets/icons/logo.svg', height: 64),
                    const SizedBox(height: 10),
                    const Text(
                      'SETUP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        backgroundColor: Colors.white.withOpacity(0.18),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'This only takes a moment',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
