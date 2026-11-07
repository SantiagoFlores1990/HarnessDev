import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:good_pizza/core/router/app_router.dart';
import 'package:good_pizza/features/auth/domain/auth_models.dart';
import 'package:good_pizza/features/auth/presentation/session_provider.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

void main() {
  group('WT-04 redirecciones (funcion pura)', () {
    test('sin sesion: cualquier ruta protegida va a /login; login y registro son publicos', () {
      expect(appRedirect('/presets', loading: false), '/login');
      expect(appRedirect('/admin/orders', loading: false), '/login');
      expect(appRedirect('/cart', loading: false), '/login');
      expect(appRedirect('/login', loading: false), isNull);
      expect(appRedirect('/register', loading: false), isNull);
    });

    test('CLIENT en /admin/* va a /presets', () {
      for (final path in ['/admin/ingredients', '/admin/presets/new', '/admin/orders/abc', '/admin']) {
        expect(appRedirect(path, loading: false, role: UserRole.client), '/presets', reason: path);
      }
      expect(appRedirect('/cart', loading: false, role: UserRole.client), isNull);
      expect(appRedirect('/orders/xyz', loading: false, role: UserRole.client), isNull);
    });

    test('ADMIN en rutas de cliente va a /admin/ingredients', () {
      for (final path in ['/presets', '/builder', '/cart', '/orders', '/orders/1']) {
        expect(appRedirect(path, loading: false, role: UserRole.admin), '/admin/ingredients', reason: path);
      }
      expect(appRedirect('/admin/orders', loading: false, role: UserRole.admin), isNull);
    });

    test('con sesion en /login, /register, / o /splash va al inicio del rol', () {
      for (final path in ['/login', '/register', '/', '/splash']) {
        expect(appRedirect(path, loading: false, role: UserRole.client), '/presets');
        expect(appRedirect(path, loading: false, role: UserRole.admin), '/admin/ingredients');
      }
    });

    test('mientras carga la sesion se muestra /splash', () {
      expect(appRedirect('/presets', loading: true), '/splash');
      expect(appRedirect('/splash', loading: true), isNull);
    });
  });

  group('WT-04 redirecciones en la app', () {
    testWidgets('sin sesion se abre /login', (tester) async {
      await pumpGoodPizza(tester, FakeBackend(), loggedIn: false);
      expect(find.text('Iniciar sesión'), findsWidgets);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('sin sesion, ir a /admin/ingredients redirige a /login', (tester) async {
      await pumpGoodPizza(tester, FakeBackend(), loggedIn: false, location: '/admin/ingredients');
      expect(find.text('Crear cuenta'), findsOneWidget);
    });

    testWidgets('CLIENT que abre /admin/* termina en /presets', (tester) async {
      await pumpGoodPizza(tester, FakeBackend(), location: '/admin/orders');
      expect(find.text('Pizzas predefinidas'), findsWidgets);
      expect(find.text('Margarita'), findsOneWidget);
    });

    testWidgets('ADMIN que abre una ruta de cliente termina en /admin/ingredients', (tester) async {
      await pumpGoodPizza(tester, FakeBackend(user: FakeAuthRepository.adminUser), location: '/cart');
      expect(find.text('Nuevo ingrediente'), findsOneWidget);
    });

    testWidgets('al cerrar sesion se vuelve a /login y se borran los tokens', (tester) async {
      final backend = FakeBackend();
      final container = await pumpGoodPizza(tester, backend);
      await container.read(sessionProvider.notifier).logout();
      await tester.pumpAndSettle();
      expect(find.text('Crear cuenta'), findsOneWidget);
      expect(backend.auth.logoutCalls, 1);
    });
  });

  testWidgets('el tamano de ventana menor al minimo hace scroll en vez de recortar', (tester) async {
    await pumpGoodPizza(tester, FakeBackend(), size: const Size(900, 600), textScale: 0.5);
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });
}
