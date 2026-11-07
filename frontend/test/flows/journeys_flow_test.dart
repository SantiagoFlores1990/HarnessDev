import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:good_pizza/features/orders/domain/order_models.dart';

import '../helpers/fakes.dart';
import '../helpers/finders.dart';
import '../helpers/fixtures.dart' as fx;
import '../helpers/pump_app.dart';
import '../features/orders_test.dart' show sampleOrder;

/// QA-F01 / QA-F02: recorridos completos de punta a punta por la UI con repositorios falsos.
/// Complementan WT-29 (que arranca con la sesion ya iniciada).
Finder field(String label) => find.widgetWithText(TextFormField, label);

Finder tableRow(String name) => find.ancestor(of: find.text(name), matching: find.byType(InkWell)).first;

void main() {
  testWidgets(
      'QA-F01 criterio 1 (UI): registro -> personalizar triple queso -> pedido -> confirmar -> comprobante -> Mis pedidos',
      (tester) async {
    final backend = FakeBackend();
    await pumpGoodPizza(tester, backend, loggedIn: false, location: '/register');

    // US-01: registro desde la UI
    await tester.enterText(field('Nombre completo'), 'Luis Mora');
    await tester.enterText(field('Email'), 'luis@ejemplo.com');
    await tester.enterText(field('Contraseña'), '12345678');
    await tester.enterText(field('Repetir contraseña'), '12345678');
    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pumpAndSettle();
    expect(backend.auth.registerCalls.single.email, 'luis@ejemplo.com');
    expect(find.text('¡Bienvenido, Luis Mora!'), findsOneWidget);

    // US-04/US-05: personalizar; el stepper no pasa de 3
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Personalizar pizza')));
    await settleQuote(tester);
    await tester.tap(checkboxOf('Masa tradicional'));
    await tester.tap(checkboxOf('Salsa de tomate'));
    await tester.tap(checkboxOf('Queso mozzarella'));
    await tester.pump();
    await tester.tap(plusOf('Queso mozzarella'));
    await tester.pump();
    await tester.tap(plusOf('Queso mozzarella'));
    await tester.pump();
    expect(isEnabled(tester, plusOf('Queso mozzarella')), isFalse, reason: 'tope de 3 porciones');
    await tester.tap(checkboxOf('Jamón'));
    await tester.tap(checkboxOf('Champiñones'));
    await settleQuote(tester);
    await tester.tap(addToOrderButton());
    await tester.pumpAndSettle();

    // US-09/US-10: pedido con IVA desglosado y confirmacion
    await tester.tap(find.text('Ver pedido'));
    await settleQuote(tester);
    expect(find.text('IVA 15 %'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('cart-total'))).data, '\$ 10.89');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();

    // US-12: comprobante
    expect(backend.orders.createCalls, hasLength(1));
    expect(find.text('TOTAL (USD)'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('receipt-total'))).data, '\$ 10.89');
    expect(find.text('805 kcal'), findsWidgets);

    // US-13: Mis pedidos muestra el pedido con estado Pendiente
    backend.orders.summaries = backend.orders.orders.values.map((o) => o.summary).toList();
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Mis pedidos')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Actualizar')); // refresco manual (el fake no agrega solo el pedido a la lista)
    await tester.pumpAndSettle();
    expect(find.text('GP-20261106-0001'), findsOneWidget);
    expect(find.text('Pendiente'), findsWidgets);
    expect(find.text('\$ 10.89'), findsWidgets);
  });

  testWidgets(
      'QA-F02 criterio 2 (UI): admin inicia sesion -> edita precio -> ajusta stock -> avanza el pedido hasta Entregado',
      (tester) async {
    final backend = FakeBackend(user: FakeAuthRepository.adminUser);
    final order = sampleOrder(backend);
    backend.orders.orders[order.id] = order;
    backend.orders.summaries = [order.summary];
    await pumpGoodPizza(tester, backend, loggedIn: false);

    // US-02/US-22: login de administrador -> pantalla de ingredientes
    await tester.enterText(field('Email'), 'admin@goodpizza.local');
    await tester.enterText(field('Contraseña'), 'secreto123');
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo ingrediente'), findsOneWidget);
    expect(find.text('Personalizar pizza'), findsNothing, reason: 'el admin no ve el menu de cliente');

    // US-17: cambiar el precio (Mediana) y guardar
    await tester.tap(find.descendant(of: tableRow('Queso mozzarella'), matching: find.byIcon(Icons.edit_outlined)));
    await tester.pumpAndSettle();
    await tester.enterText(field('Precio (USD) Mediana'), '1.75');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar ingrediente'));
    await tester.pumpAndSettle();
    final draft = backend.catalog.updated.single;
    expect(draft.id, fx.mozzarella.id);
    final medium = (draft.draft.toUpdateJson()['sizeValues'] as List).firstWhere((s) => (s as Map)['sizeCode'] == 'MEDIUM');
    expect(medium, {'sizeCode': 'MEDIUM', 'price': '1.75', 'calories': 110});

    // US-17: cambiar el stock
    await tester.tap(find.descendant(of: tableRow('Queso mozzarella'), matching: find.byType(TextButton)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '200');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    expect(backend.catalog.stockCalls.single, (id: 'c1', operation: 'SET', value: 200));

    // US-20: Pedidos -> abrir -> En preparacion -> Entregado
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Pedidos')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(order.orderNumber));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Pasar a En preparación'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();
    expect(find.text('Estado actualizado: En preparación'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Marcar como Entregado'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();
    expect(backend.orders.statusCalls.map((c) => c.status), [OrderStatus.inPreparation, OrderStatus.delivered]);
    expect(find.text('Este pedido ya fue entregado. No admite más cambios.'), findsOneWidget);
    expect(backend.orders.orders[order.id]!.status, OrderStatus.delivered);
  });

  testWidgets('QA-F03 US-02: sin sesion, pedir exige iniciar sesion (guard del router)', (tester) async {
    final backend = FakeBackend();
    await pumpGoodPizza(tester, backend, loggedIn: false, location: '/cart');
    expect(find.widgetWithText(FilledButton, 'Iniciar sesión'), findsOneWidget);
    await goTo(tester, '/builder');
    expect(find.widgetWithText(FilledButton, 'Iniciar sesión'), findsOneWidget);
    expect(backend.orders.createCalls, isEmpty);
  });

  testWidgets('QA-F04 US-13: el cliente refresca y ve el estado nuevo que el admin le puso', (tester) async {
    final backend = FakeBackend();
    final order = sampleOrder(backend);
    backend.orders.orders[order.id] = order;
    backend.orders.summaries = [order.summary];
    await pumpGoodPizza(tester, backend, location: '/orders');
    expect(find.text('Pendiente'), findsWidgets);
    // el admin avanza el pedido en el servidor
    final updated = await backend.orders.updateStatus(order.id, OrderStatus.inPreparation);
    backend.orders.summaries = [updated.summary];
    await tester.tap(find.text('Actualizar'));
    await tester.pumpAndSettle();
    expect(find.text('En preparación'), findsWidgets);
  });
}
