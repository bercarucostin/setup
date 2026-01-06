import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../features/auth/models/auth_state.dart';
import '../../features/auth/providers/auth_controller_provider.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  bool showEmailFields = false;

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
      // Local validation error → use controller for consistency
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

    print("Building sign up screen!");

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
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
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: isKeyboardOpen
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.spaceAround,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            height: isKeyboardOpen ? 70 : 80,
                            child: SvgPicture.asset('assets/icons/logo.svg'),
                          ),

                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 250),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isKeyboardOpen ? 14 : 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Montserrat',
                            ),
                            child: const Text('Create an account'),
                          ),

                          showEmailFields
                              ? _buildEmailFields(
                                  isKeyboardOpen,
                                  isLoading,
                                  errorMessage,
                                )
                              : _buildSignupOptions(isLoading),

                          GestureDetector(
                            onTap: () => context.go('/login'),
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

  Widget _buildEmailFields(
    bool isKeyboardOpen,
    bool isLoading,
    String? errorMessage,
  ) {
    return Column(
      children: [
        _buildTextField(_emailController, 'Email'),
        _buildTextField(_passwordController, 'Password', obscure: true),
        _buildTextField(
          _confirmPasswordController,
          'Confirm Password',
          obscure: true,
        ),
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              errorMessage,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        AnimatedPadding(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: EdgeInsets.only(
            top: isKeyboardOpen ? 30 : 74,
            bottom: isKeyboardOpen ? 20 : 34,
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

  Widget _buildSignupOptions(bool isLoading) {
    return Column(
      children: [
        SizedBox(
          width: 300,
          child: ElevatedButton.icon(
            onPressed: isLoading
                ? null
                : () {
                    ref
                        .read(authControllerProvider.notifier)
                        .signInWithGoogle();
                  },
            icon: const FaIcon(FontAwesomeIcons.google),
            label: const Text('Sign up with Google'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 300,
          child: ElevatedButton.icon(
            onPressed: null,
            icon: const FaIcon(FontAwesomeIcons.instagram),
            label: const Text('Sign up with Instagram'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 300,
          child: ElevatedButton(
            onPressed: () => setState(() => showEmailFields = true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF354975),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Sign up with Email'),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool obscure = false,
  }) {
    return SizedBox(
      width: 280,
      child: TextField(
        controller: controller,
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
