import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Marca de peticiones que no llevan token ni se reintentan (login, registro, refresh...).
const String skipAuthKey = 'skipAuth';
const String _retriedKey = 'authRetried';

/// Anade `Authorization: Bearer` y, ante `401 TOKEN_EXPIRED`, hace UN refresh serializado
/// (el refresh token es rotativo: cada uso invalida el anterior) y reintenta la peticion.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.refreshDio,
    required this.storage,
    required this.onSessionExpired,
  });

  /// Cliente principal (para reintentar la peticion original).
  final Dio dio;

  /// Cliente sin interceptores, solo para `/auth/refresh`.
  final Dio refreshDio;
  final TokenStorage storage;
  final void Function() onSessionExpired;

  Future<String?>? _refreshing;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra[skipAuthKey] != true) {
      final tokens = await storage.read();
      if (tokens != null) {
        options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final isExpired = err.response?.statusCode == 401 &&
        ApiException.fromDio(err).code == ErrorCodes.tokenExpired;
    if (!isExpired || options.extra[skipAuthKey] == true || options.extra[_retriedKey] == true) {
      return handler.next(err);
    }
    final newAccess = await (_refreshing ??= _refresh().whenComplete(() => _refreshing = null));
    if (newAccess == null) {
      return handler.next(err);
    }
    try {
      options.extra[_retriedKey] = true;
      options.headers['Authorization'] = 'Bearer $newAccess';
      final response = await dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// Devuelve el nuevo access token o null si no se pudo renovar (sesion terminada).
  Future<String?> _refresh() async {
    final tokens = await storage.read();
    if (tokens == null) {
      onSessionExpired();
      return null;
    }
    try {
      final response = await refreshDio.post<dynamic>(
        '/auth/refresh',
        data: {'refreshToken': tokens.refreshToken},
      );
      final data = (response.data as Map)['data'] as Map;
      final fresh = Tokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      await storage.save(fresh);
      return fresh.accessToken;
    } on DioException catch (e) {
      final code = ApiException.fromDio(e).code;
      // Solo se cierra la sesion si el servidor rechazo el refresh; un fallo de red la conserva.
      if (code == ErrorCodes.invalidRefreshToken ||
          code == ErrorCodes.unauthenticated ||
          code == ErrorCodes.forbidden) {
        onSessionExpired();
      }
      return null;
    }
  }
}
