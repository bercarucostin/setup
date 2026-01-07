import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../features/auth/models/auth_state.dart';
import '../../features/auth/providers/auth_controller_provider.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleEmailSignup() {
    if (_passwordController.text != _confirmPasswordController.text) {
      ref
          .read(authControllerProvider.notifier)
          .emitError('Passwords do not match');
      return;
    }

    ref
        .read(authControllerProvider.notifier)
        .signUp(_emailController.text.trim(), _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final bool isLoading =
        authState is AuthLoading || authState is CheckingProfile;

    final String? errorMessage = authState is AuthError
        ? authState.message
        : null;

    return GestureDetector(
      onTap: isLoading ? null : () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E1E2C), Color(0xFF2B5876), Color(0xFF4E4376)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: isLoading
                      ? const NeverScrollableScrollPhysics()
                      : const ClampingScrollPhysics(),
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    // Helps avoid a "snap" when keyboard opens/closes
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          // ✅ Keep constant to avoid big layout reflow
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // ✅ Animate spacing instead of switching MainAxisAlignment
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                              height: isKeyboardOpen ? 12 : 78,
                            ),

                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                              height: isKeyboardOpen ? 44 : 80,
                              child: SvgPicture.asset('assets/icons/logo.svg'),
                            ),

                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                              height: isKeyboardOpen ? 14 : 34,
                            ),

                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isKeyboardOpen ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Montserrat',
                              ),
                              child: const Text('Create an account'),
                            ),

                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                              height: isKeyboardOpen ? 40 : 42,
                            ),

                            _buildEmailFields(
                              isKeyboardOpen: isKeyboardOpen,
                              isLoading: isLoading,
                              errorMessage: errorMessage,
                            ),

                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                              height: isKeyboardOpen ? 6 : 10,
                            ),

                            GestureDetector(
                              onTap: isLoading
                                  ? null
                                  : () => context.go('/login'),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    "Already have an account?",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "Sign in",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Widgets
  // ---------------------------------------------------------------------------

  Widget _buildEmailFields({
    required bool isKeyboardOpen,
    required bool isLoading,
    required String? errorMessage,
  }) {
    return Column(
      children: [
        _buildTextField(_emailController, 'Email', enabled: !isLoading),
        _buildTextField(
          _passwordController,
          'Password',
          obscure: true,
          enabled: !isLoading,
        ),
        _buildTextField(
          _confirmPasswordController,
          'Confirm Password',
          obscure: true,
          enabled: !isLoading,
        ),
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        AnimatedPadding(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: EdgeInsets.only(
            top: isKeyboardOpen ? 28 : 100,
            bottom: isKeyboardOpen ? 14 : 34,
          ),
          child: SizedBox(
            width: 300,
            child: ElevatedButton(
              onPressed: isLoading ? null : _handleEmailSignup,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF354975),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Register', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    bool enabled = true,
  }) {
    return SizedBox(
      width: 280,
      child: TextField(
        controller: controller,
        enabled: enabled,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: 'Montserrat',
          ),
          floatingLabelStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          border: InputBorder.none,
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white, width: 1.2),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white, width: 1.5),
          ),
        ),
      ),
    );
  }
}
