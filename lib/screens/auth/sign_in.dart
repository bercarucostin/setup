import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/models/auth_state.dart';
import '../../features/auth/providers/auth_controller_provider.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    ref
        .read(authControllerProvider.notifier)
        .signIn(_emailController.text.trim(), _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    final bool isBusy =
        authState is AuthLoading || authState is CheckingProfile;

    final String? errorMessage = authState is AuthError
        ? authState.message
        : null;

    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return GestureDetector(
      onTap: isBusy ? null : () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // ------------------ main UI ------------------
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1E1E2C),
                    Color(0xFF2B5876),
                    Color(0xFF4E4376),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: isBusy
                          ? const NeverScrollableScrollPhysics()
                          : const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: IntrinsicHeight(
                          child: Column(
                            mainAxisAlignment: isKeyboardOpen
                                ? MainAxisAlignment.center
                                : MainAxisAlignment.spaceAround,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(height: isKeyboardOpen ? 0 : 40),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                height: isKeyboardOpen ? 70 : 80,
                                child: SvgPicture.asset(
                                  'assets/icons/logo.svg',
                                ),
                              ),
                              SizedBox(height: isKeyboardOpen ? 24 : 0),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 250),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isKeyboardOpen ? 14 : 20,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Montserrat',
                                ),
                                child: const Text('Watt'),
                              ),
                              const SizedBox(height: 24),

                              _buildTextField(
                                controller: _emailController,
                                label: 'Email',
                                enabled: !isBusy,
                              ),
                              _buildTextField(
                                controller: _passwordController,
                                label: 'Password',
                                obscure: true,
                                enabled: !isBusy,
                              ),

                              if (errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 20,
                                    bottom: 40,
                                    left: 40,
                                    right: 20,
                                  ),
                                  child: Text(
                                    errorMessage,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),

                              AnimatedPadding(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                padding: EdgeInsets.only(
                                  top: isKeyboardOpen ? 40 : 24,
                                  bottom: isKeyboardOpen ? 0 : 24,
                                ),
                                child: SizedBox(
                                  width: 240,
                                  child: ElevatedButton(
                                    onPressed: isBusy ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                    ),
                                    child: (authState is AuthLoading)
                                        ? const SizedBox(
                                            height: 12,
                                            width: 12,
                                            child: CircularProgressIndicator(
                                              color: Colors.black,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Sign In',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                  ),
                                ),
                              ),

                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: isKeyboardOpen
                                    ? const SizedBox.shrink()
                                    : Column(
                                        children: [
                                          const SizedBox(height: 16),
                                          _buildDivider(),
                                          const SizedBox(height: 24),
                                          _buildThirdPartyButtons(
                                            ref,
                                            enabled: !isBusy,
                                          ),
                                          const SizedBox(height: 24),
                                          _buildSignUpText(
                                            context,
                                            enabled: !isBusy,
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ------------------ blocking overlay ------------------
            if (isBusy) ...[
              const ModalBarrier(dismissible: false, color: Colors.black54),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        authState is CheckingProfile
                            ? 'Setting things up…'
                            : 'Signing you in…',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Widgets
  // ---------------------------------------------------------------------------

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
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

  Widget _buildDivider() {
    return Row(
      children: const [
        Expanded(
          child: Divider(
            color: Colors.white,
            thickness: 1,
            endIndent: 10,
            indent: 40,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'OR',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Divider(
            color: Colors.white,
            thickness: 1,
            indent: 10,
            endIndent: 40,
          ),
        ),
      ],
    );
  }

  Widget _buildThirdPartyButtons(WidgetRef ref, {bool enabled = true}) {
    return Column(
      children: [
        SizedBox(
          width: 240,
          child: ElevatedButton.icon(
            onPressed: enabled
                ? () => ref
                      .read(authControllerProvider.notifier)
                      .signInWithGoogle()
                : null,
            icon: const FaIcon(FontAwesomeIcons.google),
            label: const Text('Continue with Google'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 240,
          child: ElevatedButton.icon(
            onPressed: enabled
                ? () => ref
                      .read(authControllerProvider.notifier)
                      .signInWithApple()
                : null,
            icon: const FaIcon(FontAwesomeIcons.apple),
            label: const Text('Continue with Apple'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpText(BuildContext context, {bool enabled = true}) {
    return GestureDetector(
      onTap: enabled ? () => context.go('/signup') : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text(
            "Don't have an account?",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'Montserrat',
            ),
          ),
          SizedBox(width: 4),
          Text(
            'Sign up',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontFamily: 'Montserrat',
            ),
          ),
        ],
      ),
    );
  }
}
