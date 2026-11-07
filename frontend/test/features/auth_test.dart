import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:good_pizza/core/storage/token_storage.dart';
import 'package:good_pizza/features/auth/presentation/session_provider.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  group('S-02 registro', () {
    testWidgets('WT-05 contrasena de 7 caracteres: "La contraseña debe tener al menos 8 caracteres."', (tester) async {
      final backend = FakeBackend();
      await pumpGoodPizza(tester, backend, loggedIn: false, location: '/register');
      await tester.enterText(field('Nombre completo'), 'Ana Pérez');
      await tester.enterText(field('Email'), 'ana@ejemplo.com');
      await tester.enterText(field('Contraseña'), '1234567');
      await tester.enterText(field('Repetir contraseña'), '1234567');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('La contraseña debe tener al menos 8 caracteres.'), findsOneWidget);
      expect(backend.auth.registerCalls, isEmpty, reason: 'no se envia con validacion local fallida');
    });

    testWidgets('validaciones locales: nombre, email y repetir contrasena', (tester) async {
      final backend = FakeBackend();
      await pumpGoodPizza(tester, backend, loggedIn: false, location: '/register');
      await tester.enterText(field('Nombre completo'), 'A');
      await tester.enterText(field('Email'), 'no-es-email');
      await tester.enterText(field('Contraseña'), 'abcdefgh');
      await tester.enterText(field('Repetir contraseña'), 'otra-cosa');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresa tu nombre completo (mínimo 2 caracteres).'), findsOneWidget);
      expect(find.text('Ingresa un email válido.'), findsOneWidget);
      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      expect(find.text('Mínimo 8 caracteres'), findsOneWidget, reason: 'ayuda permanente');
    });

    testWidgets('WT-05 EMAIL_ALREADY_EXISTS muestra el error en el campo email con enlace a iniciar sesion',
        (tester) async {
      final backend = FakeBackend();
      backend.auth.registerError = apiError('EMAIL_ALREADY_EXISTS', status: 409);
      await pumpGoodPizza(tester, backend, loggedIn: false, location: '/register');
      await tester.enterText(field('Nombre completo'), 'Ana Pérez');
      await tester.enterText(field('Email'), 'ana@ejemplo.com');
      await tester.enterText(field('Contraseña'), '12345678');
      await tester.enterText(field('Repetir contraseña'), '12345678');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('Este email ya está registrado.'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Iniciar sesión'), findsWidgets);
    });

    testWidgets('registro correcto: sesion iniciada automaticamente y bienvenida', (tester) async {
      final backend = FakeBackend();
      final storage = InMemoryTokenStorage();
      await pumpGoodPizza(tester, backend, loggedIn: false, location: '/register', storage: storage);
      await tester.enterText(field('Nombre completo'), 'Luis Mora');
      await tester.enterText(field('Email'), 'luis@ejemplo.com');
      await tester.enterText(field('Contraseña'), '12345678');
      await tester.enterText(field('Repetir contraseña'), '12345678');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      expect(backend.auth.registerCalls.single.fullName, 'Luis Mora');
      expect((await storage.read())?.accessToken, 'access-2', reason: 'tokens en almacenamiento seguro');
      expect(find.text('Pizzas predefinidas'), findsWidgets);
      expect(find.text('¡Bienvenido, Luis Mora!'), findsOneWidget);
    });

    testWidgets('VALIDATION_ERROR del servidor se muestra en su campo', (tester) async {
      final backend = FakeBackend();
      backend.auth.registerError = apiError('VALIDATION_ERROR', details: [
        {'path': 'email', 'message': 'Email no válido para el servidor.'},
      ]);
      await pumpGoodPizza(tester, backend, loggedIn: false, location: '/register');
      await tester.enterText(field('Nombre completo'), 'Ana Pérez');
      await tester.enterText(field('Email'), 'ana@ejemplo.com');
      await tester.enterText(field('Contraseña'), '12345678');
      await tester.enterText(field('Repetir contraseña'), '12345678');
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();
      expect(find.text('Email no válido para el servidor.'), findsOneWidget);
    });
  });

  group('S-01 login', () {
    testWidgets('WT-06 INVALID_CREDENTIALS muestra un banner unico "Email o contraseña incorrectos."', (tester) async {
      final backend = FakeBackend();
      backend.auth.loginError = apiError('INVALID_CREDENTIALS', status: 401);
      await pumpGoodPizza(tester, backend, loggedIn: false);
      await tester.enterText(field('Email'), 'ana@ejemplo.com');
      await tester.enterText(field('Contraseña'), 'incorrecta1');
      await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Email o contraseña incorrectos.'), findsOneWidget, reason: 'un solo mensaje, sin distinguir campo');
      // La contrasena se limpia
      final password = tester.widget<TextFormField>(field('Contraseña'));
      expect(password.controller?.text, isEmpty);
    });

    testWidgets('validacion local: email invalido y contrasena vacia no se envian', (tester) async {
      final backend = FakeBackend();
      await pumpGoodPizza(tester, backend, loggedIn: false);
      await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresa un email válido.'), findsOneWidget);
      expect(find.text('Ingresa tu contraseña.'), findsOneWidget);
      expect(backend.auth.loginCalls, isEmpty);
    });

    testWidgets('login CLIENT va a /presets y guarda los tokens', (tester) async {
      final backend = FakeBackend();
      final storage = InMemoryTokenStorage();
      await pumpGoodPizza(tester, backend, loggedIn: false, storage: storage);
      await tester.enterText(field('Email'), 'ana@ejemplo.com');
      await tester.enterText(field('Contraseña'), 'secreto123');
      await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Margarita'), findsOneWidget);
      expect((await storage.read())?.refreshToken, 'refresh-1');
    });

    testWidgets('login ADMIN va a /admin/ingredients', (tester) async {
      final backend = FakeBackend(user: FakeAuthRepository.adminUser);
      await pumpGoodPizza(tester, backend, loggedIn: false);
      await tester.enterText(field('Email'), 'admin@goodpizza.local');
      await tester.enterText(field('Contraseña'), 'secreto123');
      await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo ingrediente'), findsOneWidget);
    });

    testWidgets('FORBIDDEN (usuario desactivado), RATE_LIMITED y red tienen su mensaje', (tester) async {
      final backend = FakeBackend();
      await pumpGoodPizza(tester, backend, loggedIn: false);
      Future<void> attempt() async {
        await tester.enterText(field('Email'), 'ana@ejemplo.com');
        await tester.enterText(field('Contraseña'), 'secreto123');
        await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
        await tester.pumpAndSettle();
      }

      backend.auth.loginError = apiError('FORBIDDEN', status: 403);
      await attempt();
      expect(find.text('Tu cuenta está desactivada. Consulta con el local.'), findsOneWidget);

      backend.auth.loginError = apiError('RATE_LIMITED', status: 429);
      await attempt();
      expect(find.text('Demasiados intentos. Espera unos minutos e inténtalo de nuevo.'), findsOneWidget);

      backend.auth.loginError = apiError('NETWORK_ERROR');
      await attempt();
      expect(find.textContaining('No se pudo conectar con el servidor.'), findsOneWidget);
    });

    testWidgets('el boton mostrar/ocultar contraseña alterna la visibilidad', (tester) async {
      await pumpGoodPizza(tester, FakeBackend(), loggedIn: false);
      EditableText editable() => tester.widget<EditableText>(
          find.descendant(of: field('Contraseña'), matching: find.byType(EditableText)));
      expect(editable().obscureText, isTrue);
      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.pump();
      expect(editable().obscureText, isFalse);
      expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);
    });
  });

  group('sesion', () {
    testWidgets('tokens invalidos al arrancar: se limpian y se pide login', (tester) async {
      final backend = FakeBackend();
      backend.auth.meError = apiError('UNAUTHENTICATED', status: 401);
      final storage = InMemoryTokenStorage(const Tokens(accessToken: 'x', refreshToken: 'y'));
      await pumpGoodPizza(tester, backend, storage: storage);
      expect(find.text('Crear cuenta'), findsOneWidget);
      expect(await storage.read(), isNull);
    });

    testWidgets('sesion expirada (refresh rechazado): dialogo y vuelta a /login', (tester) async {
      final backend = FakeBackend();
      final container = await pumpGoodPizza(tester, backend);
      expect(find.text('Margarita'), findsOneWidget);
      await container.read(sessionProvider.notifier).expire();
      await tester.pumpAndSettle();
      expect(find.text('Tu sesión expiró. Inicia sesión de nuevo.'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Crear cuenta'), findsOneWidget);
    });
  });
}
