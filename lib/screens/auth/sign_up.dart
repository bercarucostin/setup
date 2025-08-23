import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:setup/features/auth/controllers/auth_controller.dart';
import 'package:setup/features/auth/models/auth_state.dart';
import 'package:setup/features/auth/providers/providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:setup/features/auth/controllers/auth_controller.dart';
import 'package:setup/features/auth/models/auth_state.dart';
import 'package:setup/features/auth/providers/providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:setup/features/auth/controllers/auth_controller.dart';
import 'package:setup/features/auth/models/auth_state.dart';
import 'package:setup/features/auth/providers/providers.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  bool showEmailFields = false;
  String? errorMessage;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailController.addListener(clearError);
    _passwordController.addListener(clearError);
    _confirmPasswordController.addListener(clearError);
  }

  void clearError() {
    if (errorMessage != null) {
      setState(() => errorMessage = null);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is IncompleteProfile) {
        context.go('/complete-profile');
      } else if (next is Authenticated) {
        context.go('/');
      } else if (next is AuthError) {
        setState(() => errorMessage = next.message);
      }
    });

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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 24),
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
                          mainAxisAlignment:
                              isKeyboardOpen
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
                              ),
                              child: const Text(
                                'Create an account',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                            ),
                            showEmailFields
                                ? _buildEmailFields(context, isKeyboardOpen)
                                : _buildSignupOptions(context, authState),
                            GestureDetector(
                              onTap: () {
                                ref.read(authControllerProvider.notifier);
                                context.go('/login');
                              },
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
      ),
    );
  }

  Widget _buildEmailFields(BuildContext context, bool isKeyboardOpen) {
    return Column(
      children: [
        _buildTextField(_emailController, 'Email', isKeyboardOpen),
        _buildTextField(
          _passwordController,
          'Password',
          isKeyboardOpen,
          obscure: true,
        ),

        _buildTextField(
          _confirmPasswordController,
          'Confirm Password',
          isKeyboardOpen,
          obscure: true,
        ),
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              errorMessage!,
              style: const TextStyle(
                color: Colors.red,
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
              onPressed: () async {
                if (_passwordController.text !=
                    _confirmPasswordController.text) {
                  setState(() => errorMessage = 'Passwords do not match');
                  return;
                }
                await ref
                    .read(authControllerProvider.notifier)
                    .signUp(
                      _emailController.text.trim(),
                      _passwordController.text,
                    );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF354975),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Register', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
        SizedBox(height: isKeyboardOpen ? 0 : 10),
      ],
    );
  }

  Widget _buildSignupOptions(BuildContext context, AuthState authState) {
    return Column(
      children: [
        SizedBox(
          width: 300,
          child: ElevatedButton.icon(
            onPressed:
                authState is AuthLoading
                    ? null
                    : () {
                      ref
                          .read(authControllerProvider.notifier)
                          .signInWithGoogle();
                    },
            icon: const FaIcon(FontAwesomeIcons.google),
            label: const Text(
              'Sign up with Google',
              style: TextStyle(fontSize: 13),
            ),
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
            onPressed: () {
              // TODO: Handle Instagram sign up
            },
            icon: const FaIcon(FontAwesomeIcons.instagram),
            label: const Text(
              'Sign up with Instagram',
              style: TextStyle(fontSize: 13),
            ),
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
            onPressed: () {
              setState(() => showEmailFields = true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF354975),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Sign up with Email',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    bool isKeyboardOpen, {
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
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          filled: false,
        ),
      ),
    );
  }
}
