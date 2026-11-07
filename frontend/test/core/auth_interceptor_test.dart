import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:good_pizza/core/api/auth_interceptor.dart';
import 'package:good_pizza/core/storage/token_storage.dart';

/// Adaptador HTTP falso: responde segun la ruta y registra las peticiones.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final ({int status, Map<String, dynamic> body}) Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final r = handler(options);
    return ResponseBody.fromString(jsonEncode(r.body), r.status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _error(String code) => {
      'error': {'code': code, 'message': 'x', 'details': []},
    };

void main() {
  late InMemoryTokenStorage storage;
  late _FakeAdapter mainAdapter;
  late _FakeAdapter refreshAdapter;
  late Dio dio;
  late int expired;
  late int refreshCalls;

  setUp(() {
    storage = InMemoryTokenStorage(const Tokens(accessToken: 'old-access', refreshToken: 'old-refresh'));
    expired = 0;
    refreshCalls = 0;
    refreshAdapter = _FakeAdapter((o) {
      refreshCalls++;
      return (
        status: 200,
        body: {
          'data': {
            'accessToken': 'new-access',
            'accessTokenExpiresIn': 900,
            'refreshToken': 'new-refresh',
            'refreshTokenExpiresIn': 604800,
          },
        },
      );
    });
    mainAdapter = _FakeAdapter((o) {
      final auth = o.headers['Authorization'];
      if (auth == 'Bearer new-access') return (status: 200, body: {'data': {'ok': true}});
      return (status: 401, body: _error('TOKEN_EXPIRED'));
    });
    dio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = mainAdapter;
    final refreshDio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = refreshAdapter;
    dio.interceptors.add(AuthInterceptor(
      dio: dio,
      refreshDio: refreshDio,
      storage: storage,
      onSessionExpired: () => expired++,
    ));
  });

  test('anade el Bearer del almacenamiento seguro', () async {
    mainAdapter = _FakeAdapter((o) => (status: 200, body: {'data': {}}));
    dio.httpClientAdapter = mainAdapter;
    await dio.get<dynamic>('/orders');
    expect(mainAdapter.requests.single.headers['Authorization'], 'Bearer old-access');
  });

  test('las peticiones skipAuth no llevan token', () async {
    mainAdapter = _FakeAdapter((o) => (status: 200, body: {'data': {}}));
    dio.httpClientAdapter = mainAdapter;
    await dio.post<dynamic>('/auth/login', options: Options(extra: {skipAuthKey: true}));
    expect(mainAdapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('401 TOKEN_EXPIRED: un refresh, guarda los tokens rotados y reintenta con exito', () async {
    final response = await dio.get<dynamic>('/orders');
    expect(response.statusCode, 200);
    expect(refreshCalls, 1);
    final saved = await storage.read();
    expect(saved?.accessToken, 'new-access');
    expect(saved?.refreshToken, 'new-refresh', reason: 'el refresh es rotativo');
    expect(refreshAdapter.requests.single.data, {'refreshToken': 'old-refresh'});
    expect(expired, 0);
  });

  test('peticiones concurrentes comparten UN solo refresh (token rotativo)', () async {
    final results = await Future.wait([
      dio.get<dynamic>('/orders'),
      dio.get<dynamic>('/orders/1'),
      dio.get<dynamic>('/sizes'),
    ]);
    expect(results.every((r) => r.statusCode == 200), isTrue);
    expect(refreshCalls, 1);
  });

  test('refresh rechazado (INVALID_REFRESH_TOKEN): cierra la sesion y propaga el error', () async {
    refreshAdapter = _FakeAdapter((o) {
      refreshCalls++;
      return (status: 401, body: _error('INVALID_REFRESH_TOKEN'));
    });
    final refreshDio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = refreshAdapter;
    dio.interceptors
      ..clear()
      ..add(AuthInterceptor(dio: dio, refreshDio: refreshDio, storage: storage, onSessionExpired: () => expired++));
    await expectLater(dio.get<dynamic>('/orders'), throwsA(isA<DioException>()));
    expect(expired, 1);
    expect(refreshCalls, 1);
  });

  test('un fallo de red al refrescar NO cierra la sesion', () async {
    final failing = _NetworkFailAdapter();
    final refreshDio = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = failing;
    dio.interceptors
      ..clear()
      ..add(AuthInterceptor(dio: dio, refreshDio: refreshDio, storage: storage, onSessionExpired: () => expired++));
    await expectLater(dio.get<dynamic>('/orders'), throwsA(isA<DioException>()));
    expect(expired, 0);
    expect((await storage.read())?.refreshToken, 'old-refresh');
  });

  test('otros 401 (p. ej. UNAUTHENTICATED) no disparan refresh', () async {
    mainAdapter = _FakeAdapter((o) => (status: 401, body: _error('UNAUTHENTICATED')));
    dio.httpClientAdapter = mainAdapter;
    await expectLater(dio.get<dynamic>('/orders'), throwsA(isA<DioException>()));
    expect(refreshCalls, 0);
  });

  test('si el reintento vuelve a dar TOKEN_EXPIRED no entra en bucle', () async {
    mainAdapter = _FakeAdapter((o) => (status: 401, body: _error('TOKEN_EXPIRED')));
    dio.httpClientAdapter = mainAdapter;
    await expectLater(dio.get<dynamic>('/orders'), throwsA(isA<DioException>()));
    expect(refreshCalls, 1);
    expect(mainAdapter.requests.length, 2, reason: 'original + un unico reintento');
  });
}

class _NetworkFailAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
  }

  @override
  void close({bool force = false}) {}
}
