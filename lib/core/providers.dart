// core/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../auth/data/auth_repository.dart';

final dioProvider = Provider((ref) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  return dio;
});

final authRepositoryProvider = Provider((ref) {
  return AuthRepository(ref.watch(dioProvider));
});
