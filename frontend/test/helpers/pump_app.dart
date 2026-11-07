import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:good_pizza/app.dart';
import 'package:good_pizza/core/router/app_router.dart';
import 'package:good_pizza/core/storage/token_storage.dart';
import 'package:good_pizza/features/auth/data/auth_repository.dart';
import 'package:good_pizza/features/catalog/data/catalog_repository.dart';
import 'package:good_pizza/features/orders/data/orders_repository.dart';
import 'package:good_pizza/features/pizza_builder/presentation/builder_controller.dart';
import 'package:good_pizza/features/preset_pizzas/data/preset_repository.dart';

import 'fakes.dart';

/// Arranca la app completa (router, tema, guards) con repositorios falsos.
///
/// * [loggedIn]: guarda tokens falsos para iniciar con sesion (rol segun `backend.auth.user`).
/// * [size]: tamano de ventana logico (por defecto 1400x1300: alto generoso para que las listas perezosas construyan todas las filas).
/// * Las pruebas usan la fuente Ahem (cada glifo es un cuadrado), mucho mas ancha que Segoe UI;
///   por eso se reduce la escala de texto al 60 % para que el diseno de 1024+ px no desborde.
Future<ProviderContainer> pumpGoodPizza(
  WidgetTester tester,
  FakeBackend backend, {
  bool loggedIn = true,
  Size size = const Size(1400, 1300),
  String? location,
  double textScale = 0.6,
  List<Override> overrides = const [],
  InMemoryTokenStorage? storage,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });

  final tokenStorage = storage ??
      InMemoryTokenStorage(loggedIn ? const Tokens(accessToken: 'access-0', refreshToken: 'refresh-0') : null);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        tokenStorageProvider.overrideWithValue(tokenStorage),
        authRepositoryProvider.overrideWithValue(backend.auth),
        catalogRepositoryProvider.overrideWithValue(backend.catalog),
        presetRepositoryProvider.overrideWithValue(backend.presets),
        ordersRepositoryProvider.overrideWithValue(backend.orders),
        quoteDebounceProvider.overrideWithValue(const Duration(milliseconds: 150)),
        ...overrides,
      ],
      child: const GoodPizzaApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(tester.element(find.byType(GoodPizzaApp)));
  if (location != null) {
    container.read(routerProvider).go(location);
    await tester.pumpAndSettle();
  }
  return container;
}

/// Navega por ruta con el router de la app.
Future<void> goTo(WidgetTester tester, String location) async {
  final container = ProviderScope.containerOf(tester.element(find.byType(GoodPizzaApp)));
  container.read(routerProvider).go(location);
  await tester.pumpAndSettle();
}

/// Espera el debounce de la cotizacion (150 ms) y el procesamiento de la respuesta.
Future<void> settleQuote(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}

/// Texto visible (incluye texto de widgets Text y SelectableText).
Finder textOf(String text) => find.text(text);
