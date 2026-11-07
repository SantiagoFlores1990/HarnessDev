import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Par de tokens de sesion.
class Tokens {
  const Tokens({required this.accessToken, required this.refreshToken});
  final String accessToken;
  final String refreshToken;
}

/// Almacenamiento de tokens. Nunca se usa shared_preferences para secretos.
abstract class TokenStorage {
  Future<Tokens?> read();
  Future<void> save(Tokens tokens);
  Future<void> clear();
}

/// Implementacion real: Credential Manager en Windows via flutter_secure_storage.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _accessKey = 'gp_access_token';
  static const _refreshKey = 'gp_refresh_token';

  @override
  Future<Tokens?> read() async {
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    if (access == null || refresh == null) return null;
    return Tokens(accessToken: access, refreshToken: refresh);
  }

  @override
  Future<void> save(Tokens tokens) async {
    await _storage.write(key: _accessKey, value: tokens.accessToken);
    await _storage.write(key: _refreshKey, value: tokens.refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

/// Implementacion en memoria para pruebas.
class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage([this._tokens]);
  Tokens? _tokens;

  @override
  Future<Tokens?> read() async => _tokens;
  @override
  Future<void> save(Tokens tokens) async => _tokens = tokens;
  @override
  Future<void> clear() async => _tokens = null;
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage());
