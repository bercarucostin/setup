// auth/data/auth_repository.dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthRepository {
  final _storage = const FlutterSecureStorage();
  final Dio _dio;

  AuthRepository(this._dio);

  static const _tokenKey = 'auth_token';

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> persistToken(String token) async =>
      _storage.write(key: _tokenKey, value: token);

  Future<void> deleteToken() async =>
      _storage.delete(key: _tokenKey);

  Future<String> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    if (res.statusCode == 200 && res.data['token'] != null) {
      return res.data['token'];
    } else {
      throw Exception('Login failed');
    }
  }

  Future<bool> validateToken(String token) async {
    try {
      final res = await _dio.get(
        '/auth/validate',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
