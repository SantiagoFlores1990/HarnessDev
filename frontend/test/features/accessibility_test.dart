import 'package:flutter_test/flutter_test.dart';
import 'package:good_pizza/features/cart/presentation/cart_provider.dart';
import 'package:good_pizza/features/orders/domain/order_models.dart';

import '../helpers/fakes.dart';
import '../helpers/finders.dart';
import '../helpers/pump_app.dart';
import 'orders_test.dart' show sampleOrder;

/// WT-25: guias de accesibilidad de flutter_test en S-01, S-04, S-05 y S-13.
///
/// Nota: en pruebas se usa la fuente Ahem y la escala de texto de [pumpGoodPizza]; las guias
/// evaluan el arbol de Semantics y los colores renderizados, no la fuente real (Segoe UI).
Future<void> expectAccessible(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  handle.dispose();
}

void main() {
  testWidgets('WT-25 S-01 Iniciar sesion', (tester) async {
    await pumpGoodPizza(tester, FakeBackend(), loggedIn: false);
    await expectAccessible(tester);
  });

  testWidgets('WT-25 S-02 Registro', (tester) async {
    await pumpGoodPizza(tester, FakeBackend(), loggedIn: false, location: '/register');
    await expectAccessible(tester);
  });

  testWidgets('WT-25 S-03 Pizzas predefinidas', (tester) async {
    await pumpGoodPizza(tester, FakeBackend());
    await expectAccessible(tester);
  });

  testWidgets('WT-25 S-04 Personalizar pizza (con violaciones y con seleccion)', (tester) async {
    await pumpGoodPizza(tester, FakeBackend(), location: '/builder');
    await settleQuote(tester);
    await expectAccessible(tester);
    await tester.tap(checkboxOf('Queso mozzarella'));
    await tester.pump();
    await tester.tap(plusOf('Queso mozzarella'));
    await settleQuote(tester);
    await expectAccessible(tester);
  });

  testWidgets('WT-25 S-05 Resumen del pedido', (tester) async {
    final container = await pumpGoodPizza(tester, FakeBackend());
    container.read(cartProvider.notifier)
        .add(const PizzaItemInput(type: 'PRESET', presetPizzaId: 'margherita', sizeCode: 'MEDIUM', quantity: 2));
    await goTo(tester, '/cart');
    await settleQuote(tester);
    await expectAccessible(tester);
  });

  testWidgets('WT-25 S-13 Comprobante', (tester) async {
    final backend = FakeBackend();
    final order = sampleOrder(backend);
    backend.orders.orders[order.id] = order;
    await pumpGoodPizza(tester, backend, location: '/orders/${order.id}');
    await expectAccessible(tester);
  });

  testWidgets('WT-25 S-06 Mis pedidos y paneles de administracion', (tester) async {
    final backend = FakeBackend(user: FakeAuthRepository.adminUser);
    await pumpGoodPizza(tester, backend);
    await expectAccessible(tester);
    await goTo(tester, '/admin/presets');
    await expectAccessible(tester);
    await goTo(tester, '/admin/orders');
    await expectAccessible(tester);
  });

  testWidgets('el comprobante expone etiqueta semantica y filas legibles para lector de pantalla', (tester) async {
    final backend = FakeBackend();
    final order = sampleOrder(backend);
    backend.orders.orders[order.id] = order;
    final handle = tester.ensureSemantics();
    await pumpGoodPizza(tester, backend, location: '/orders/${order.id}');
    expect(find.bySemanticsLabel('Comprobante del pedido GP-20261106-0001'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Queso mozzarella, cantidad 3, 330 calorías, 4 dólares con 50 centavos')),
        findsWidgets);
    expect(find.bySemanticsLabel('Paso 1 de 3: Pendiente'), findsOneWidget);
    handle.dispose();
  });
}
