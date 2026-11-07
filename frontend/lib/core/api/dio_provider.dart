import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/session_provider.dart';
import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

BaseOptions _baseOptions(String baseUrl) => BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: const {'Accept': 'application/json'},
      contentType: 'application/json',
    );

/// URL base de la API (sobrescribible en pruebas).
final apiBaseUrlProvider = Provider<String>((ref) => AppConfig.apiUrl);

/// Dio con baseUrl, timeouts y [AuthInterceptor]. Los widgets nunca lo usan directamente:
/// lo consumen los repositorios de cada feature.
final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final dio = Dio(_baseOptions(baseUrl));
  final refreshDio = Dio(_baseOptions(baseUrl));
  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      refreshDio: refreshDio,
      storage: ref.read(tokenStorageProvider),
      onSessionExpired: () => ref.read(sessionProvider.notifier).expire(),
    ),
  );
  ref.onDispose(() {
    dio.close();
    refreshDio.close();
  });
  return dio;
});
