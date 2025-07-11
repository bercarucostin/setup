// auth/application/auth_controller.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/auth_state.dart';
import '../data/firebase_auth_repository.dart';

final firebaseAuthRepositoryProvider = Provider(
  (ref) => FirebaseAuthRepository(),
);

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  () => AuthController(),
);

class AuthController extends Notifier<AuthState> {
  late final FirebaseAuthRepository _authRepository;
  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;

  bool get isSignedIn => _currentUser != null;

  @override
  AuthState build() {
    _authRepository = ref.read(firebaseAuthRepositoryProvider);

    _authRepository.authStateChanges.listen((user) {
      if (user != null) {
        state = Authenticated(user.uid);
      } else {
        state = Unauthenticated();
      }
    });

    return AuthLoading();
  }

  Future<void> signIn(String email, String password) async {
    state = AuthLoading();
    try {
      await _authRepository.signIn(email: email, password: password);
    } catch (e) {
      state = AuthError(_handleFirebaseError(e));
    }
  }

  Future<void> signUp(String email, String password) async {
    state = AuthLoading();
    try {
      await _authRepository.signUp(email: email, password: password);
    } catch (e) {
      state = AuthError(_handleFirebaseError(e));
    }
  }

  Future<void> signOut() async {
    _currentUser = null;
    await _authRepository.signOut();
  }

  Stream<AuthState> get stream => _authRepository.authStateChanges.map(
    (user) => user != null ? Authenticated(user.uid) : Unauthenticated(),
  );

  String _handleFirebaseError(Object error) {
    return error is FirebaseAuthException
        ? error.message ?? 'Unknown Firebase error'
        : error.toString();
  }

  Future<void> signInWithGoogle() async {
    state = AuthLoading();
    try {
      final userCredential = await _authRepository.signInWithGoogle();
      final user = userCredential?.user;

      if (user == null) {
        state = AuthError('Google sign-in was cancelled or failed.');
      } else {
        state = Authenticated(user.uid);
      }
    } catch (e) {
      state = AuthError(e.toString());
    }
  }
}
