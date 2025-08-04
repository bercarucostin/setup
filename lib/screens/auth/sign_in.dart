import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:setup/features/auth/providers/providers.dart';

import '../../features/auth/controllers/auth_controller.dart';
import '../../features/auth/models/auth_state.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_clearErrorOnInput);
    _passwordController.addListener(_clearErrorOnInput);
  }

  void _clearErrorOnInput() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    ref
        .read(authControllerProvider.notifier)
        .signIn(_usernameController.text.trim(), _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthError) {
        setState(() => _errorMessage = next.message);
      } else if (next is Authenticated) {
        context.go('/');
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
                              'SETUP',
                              style: TextStyle(fontFamily: 'Montserrat'),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildTextField(_usernameController, 'Email'),
                          _buildTextField(
                            _passwordController,
                            'Password',
                            obscure: true,
                          ),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 20,
                                bottom: 40,
                                left: 40,
                                right: 20,
                              ),
                              child: Text(
                                _errorMessage!,
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
                                onPressed:
                                    authState is AuthLoading
                                        ? null
                                        : _handleLogin,
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
                                child:
                                    authState is AuthLoading
                                        ? const SizedBox(
                                          height: 12,
                                          width: 12,
                                          child: CircularProgressIndicator(
                                            color: Colors.black,
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Text(
                                          "Sign In",
                                          style: TextStyle(fontSize: 14),
                                        ),
                              ),
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child:
                                isKeyboardOpen
                                    ? const SizedBox.shrink()
                                    : Column(
                                      children: [
                                        const SizedBox(height: 16),
                                        _buildDivider(),
                                        const SizedBox(height: 24),
                                        _buildThirdPartyButtons(),
                                        const SizedBox(height: 24),
                                        _buildSignUpText(context),
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
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool obscure = false,
  }) {
    return Container(
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

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(
          child: Divider(
            color: Colors.white,
            thickness: 1,
            endIndent: 10,
            indent: 40,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: const Text(
            "OR",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const Expanded(
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

  Widget _buildThirdPartyButtons() {
    return Column(
      children: [
        SizedBox(
          width: 240,
          child: ElevatedButton.icon(
            onPressed: () {
              ref.read(authControllerProvider.notifier).signInWithGoogle();
            },
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
            onPressed: () {
              // TODO: Handle Instagram sign-in
            },
            icon: const FaIcon(FontAwesomeIcons.instagram),
            label: const Text('Continue with Instagram'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 114, 14, 47),
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

  Widget _buildSignUpText(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ref.read(authControllerProvider.notifier).reset();
        context.go('/signup');
      },
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
            "Sign up",
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
