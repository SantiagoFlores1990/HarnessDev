import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/auth_interceptor.dart';
import '../../../core/api/dio_provider.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/auth_models.dart';

/// Resultado de login/registro: usuario y tokens.
class AuthResult {
  const AuthResult({required this.user, required this.tokens});
  final AppUser user;
  final Tokens tokens;
}

abstract class AuthRepository {
  Future<AuthResult> login({required String email, required String password});
  Future<AuthResult> register({
    required String fullName,
    required String email,
    required String password,
  });
  Future<AppUser> me();
  Future<void> logout(String refreshToken);
}

class DioAuthRepository implements AuthRepository {
  DioAuthRepository(this._dio);
  final Dio _dio;

  static final _noAuth = Options(extra: {skipAuthKey: true});

  AuthResult _parse(Response<dynamic> response) {
    final data = (response.data as Map)['data'] as Map<String, dynamic>;
    return AuthResult(
      user: AppUser.fromJson(Map<String, dynamic>.from(data['user'] as Map)),
      tokens: Tokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      ),
    );
  }

  @override
  Future<AuthResult> login({required String email, required String password}) =>
      apiCall(() async => _parse(await _dio.post<dynamic>(
            '/auth/login',
            data: {'email': email, 'password': password},
            options: _noAuth,
          )));

  @override
  Future<AuthResult> register({
    required String fullName,
    required String email,
    required String password,
  }) =>
      apiCall(() async => _parse(await _dio.post<dynamic>(
            '/auth/register',
            data: {'fullName': fullName, 'email': email, 'password': password},
            options: _noAuth,
          )));

  @override
  Future<AppUser> me() => apiCall(() async {
        final response = await _dio.get<dynamic>('/auth/me');
        return AppUser.fromJson(Map<String, dynamic>.from((response.data as Map)['data'] as Map));
      });

  @override
  Future<void> logout(String refreshToken) => apiCall(() async {
        await _dio.post<dynamic>(
          '/auth/logout',
          data: {'refreshToken': refreshToken},
          options: _noAuth,
        );
      });
}

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => DioAuthRepository(ref.watch(dioProvider)));
