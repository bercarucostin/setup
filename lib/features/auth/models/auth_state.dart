import 'package:firebase_auth/firebase_auth.dart';

sealed class AuthState {
  const AuthState();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class IncompleteProfile extends AuthState {
  final User user;
  const IncompleteProfile(this.user);
}

class CheckingProfile extends AuthState {
  final User user;
  const CheckingProfile(this.user);
}

class Authenticated extends AuthState {
  final User user;
  const Authenticated(this.user);
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}
