import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';
import '../domain/auth_models.dart';

/// Sesion actual: usuario (con rol) o null. Los tokens viven en secure storage.
class SessionNotifier extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() async {
    final storage = ref.read(tokenStorageProvider);
    final tokens = await storage.read();
    if (tokens == null) return null;
    try {
      final user = await ref.read(authRepositoryProvider).me();
      return Session(user: user);
    } on ApiException catch (e) {
      // Solo se descartan los tokens si el servidor los rechaza; un fallo de red los conserva.
      if (!e.isNetwork) await storage.clear();
      return null;
    }
  }

  Future<AppUser> _start(AuthResult result) async {
    await ref.read(tokenStorageProvider).save(result.tokens);
    ref.read(sessionExpiredNoticeProvider.notifier).clear();
    state = AsyncData(Session(user: result.user));
    return result.user;
  }

  /// Inicia sesion. Lanza [ApiException] si falla.
  Future<AppUser> login(String email, String password) async =>
      _start(await ref.read(authRepositoryProvider).login(email: email, password: password));

  /// Registra un cliente; la sesion queda iniciada (PA-UX-04).
  Future<AppUser> register(String fullName, String email, String password) async =>
      _start(await ref
          .read(authRepositoryProvider)
          .register(fullName: fullName, email: email, password: password));

  /// Cierra sesion: revoca el refresh token (si se puede) y limpia el almacenamiento.
  Future<void> logout() async {
    final storage = ref.read(tokenStorageProvider);
    final tokens = await storage.read();
    if (tokens != null) {
      try {
        await ref.read(authRepositoryProvider).logout(tokens.refreshToken);
      } on ApiException {
        // La revocacion es idempotente; si falla la red igual se cierra la sesion local.
      }
    }
    await storage.clear();
    state = const AsyncData(null);
  }

  /// La renovacion de token fallo: limpia la sesion y avisa al usuario.
  Future<void> expire() async {
    await ref.read(tokenStorageProvider).clear();
    if (state.value != null) {
      ref.read(sessionExpiredNoticeProvider.notifier).raise();
    }
    state = const AsyncData(null);
  }
}

final sessionProvider =
    AsyncNotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);

/// Indica que la sesion expiro y debe mostrarse el aviso en la pantalla de login.
class SessionExpiredNotice extends Notifier<bool> {
  @override
  bool build() => false;
  void raise() => state = true;
  void clear() => state = false;
}

final sessionExpiredNoticeProvider =
    NotifierProvider<SessionExpiredNotice, bool>(SessionExpiredNotice.new);
