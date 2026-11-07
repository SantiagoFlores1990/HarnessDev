import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:good_pizza/app.dart';
import 'package:good_pizza/core/storage/token_storage.dart';
import 'package:good_pizza/features/auth/data/auth_repository.dart';
import 'package:good_pizza/features/catalog/data/catalog_repository.dart';
import 'package:good_pizza/features/orders/data/orders_repository.dart';
import 'package:good_pizza/features/pizza_builder/presentation/builder_controller.dart';
import 'package:good_pizza/features/preset_pizzas/data/preset_repository.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/fakes.dart';
import '../test/helpers/finders.dart';

/// Prueba de integracion (ventana Windows REAL, motor de render real, fuente real) del flujo
/// "registro -> personalizar triple queso -> confirmar -> comprobante".
///
/// El backend se sustituye por repositorios falsos (no hay red ni base de datos): verifica la app
/// de escritorio compilada, no la API. Ejecutar con:
///   flutter test integration_test/app_flow_test.dart -d windows
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('IT-F01 app Windows: registro, triple queso, confirmar y comprobante con IVA', (tester) async {
    final backend = FakeBackend();
    // Ventana logica amplia para que las listas perezosas construyan todas las filas.
    tester.view.physicalSize = const Size(1600, 1300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
          authRepositoryProvider.overrideWithValue(backend.auth),
          catalogRepositoryProvider.overrideWithValue(backend.catalog),
          presetRepositoryProvider.overrideWithValue(backend.presets),
          ordersRepositoryProvider.overrideWithValue(backend.orders),
          quoteDebounceProvider.overrideWithValue(const Duration(milliseconds: 150)),
        ],
        child: const GoodPizzaApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Login (la app arranca sin sesion)
    expect(find.widgetWithText(FilledButton, 'Iniciar sesión'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'ana@ejemplo.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'secreto123');
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Margarita'), findsOneWidget);

    // Personalizar triple queso
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Personalizar pizza')));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await tester.tap(checkboxOf('Masa tradicional'));
    await tester.tap(checkboxOf('Salsa de tomate'));
    await tester.tap(checkboxOf('Queso mozzarella'));
    await tester.pump();
    await tester.tap(plusOf('Queso mozzarella'));
    await tester.pump();
    await tester.tap(plusOf('Queso mozzarella'));
    await tester.pump();
    await tester.tap(checkboxOf('Jamón'));
    await tester.tap(checkboxOf('Champiñones'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(tester.widget<Text>(find.byKey(const Key('builder-price'))).data, '\$ 9.60');
    expect(tester.widget<Text>(find.byKey(const Key('builder-calories'))).data, '805 kcal');

    await tester.tap(addToOrderButton());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver pedido'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(tester.widget<Text>(find.byKey(const Key('cart-total'))).data, '\$ 10.89');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();

    expect(backend.orders.createCalls.single.expectedTotal, '10.89');
    expect(find.text('TOTAL (USD)'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('receipt-total'))).data, '\$ 10.89');
    expect(find.text('IVA 15 %'), findsOneWidget);
    expect(find.text('Subtotal 0 %'), findsOneWidget);
    expect(find.text('805 kcal'), findsWidgets);
  });
}
