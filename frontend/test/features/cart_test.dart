import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:good_pizza/features/cart/presentation/cart_provider.dart';
import 'package:good_pizza/features/orders/domain/order_models.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

PizzaItemInput margherita({int quantity = 1, String size = 'MEDIUM'}) => PizzaItemInput(
      type: PizzaTypes.preset,
      presetPizzaId: 'margherita',
      sizeCode: size,
      quantity: quantity,
    );

PizzaItemInput customCheese({int quantity = 1}) => PizzaItemInput(
      type: PizzaTypes.custom,
      sizeCode: 'MEDIUM',
      doughId: 'd1',
      sauceId: 's1',
      toppings: const [
        PortionInput(ingredientId: 'c1', portions: 3),
        PortionInput(ingredientId: 'm1', portions: 1),
        PortionInput(ingredientId: 'v1', portions: 1),
      ],
      quantity: quantity,
    );

Future<ProviderContainer> openCart(WidgetTester tester, FakeBackend backend, List<PizzaItemInput> items) async {
  final container = await pumpGoodPizza(tester, backend);
  for (final i in items) {
    container.read(cartProvider.notifier).add(i, presetName: i.isPreset ? 'Margarita' : null);
  }
  await goTo(tester, '/cart');
  await settleQuote(tester);
  return container;
}

Finder confirmButton() => find.widgetWithText(FilledButton, 'Confirmar pedido');

void main() {
  group('cartProvider (reglas de fusion)', () {
    test('predefinidas iguales sin extras se fusionan sumando cantidad hasta 20; las personalizadas no', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final cart = container.read(cartProvider.notifier);

      cart.add(margherita(), presetName: 'Margarita');
      cart.add(margherita(), presetName: 'Margarita');
      expect(container.read(cartProvider).lines.length, 1);
      expect(container.read(cartProvider).lines.single.input.quantity, 2);

      cart.add(margherita(size: 'FAMILY'));
      expect(container.read(cartProvider).lines.length, 2, reason: 'otro tamano = otra linea');

      cart.add(customCheese());
      cart.add(customCheese());
      expect(container.read(cartProvider).lines.length, 4, reason: 'las personalizadas no se fusionan');

      cart.add(const PizzaItemInput(
        type: PizzaTypes.preset,
        presetPizzaId: 'margherita',
        sizeCode: 'MEDIUM',
        extras: [PortionInput(ingredientId: 'c1', portions: 1)],
      ));
      expect(container.read(cartProvider).lines.length, 5, reason: 'predefinida con extras no se fusiona');

      cart.add(margherita(quantity: 19));
      expect(container.read(cartProvider).lines.first.input.quantity, 20, reason: 'tope 20');
      expect(container.read(cartProvider).pizzaCount, 20 + 1 + 1 + 1 + 1);
    });

    test('setQuantity respeta 1..20; remove/restore conservan la posicion', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final cart = container.read(cartProvider.notifier);
      cart.add(margherita());
      cart.add(customCheese());
      final id = container.read(cartProvider).lines.first.id;
      cart.setQuantity(id, 99);
      expect(container.read(cartProvider).lines.first.input.quantity, 20);
      cart.setQuantity(id, 0);
      expect(container.read(cartProvider).lines.first.input.quantity, 1);

      final removed = cart.remove(id)!;
      expect(container.read(cartProvider).lines.length, 1);
      cart.restore(removed.$1, removed.$2);
      expect(container.read(cartProvider).lines.first.id, id);
    });
  });

  group('S-05 resumen del pedido', () {
    testWidgets('WT-14 cambiar cantidad, quitar con "Deshacer" y tope de 20', (tester) async {
      final backend = FakeBackend();
      final container = await openCart(tester, backend, [margherita()]);

      // cantidad 1 -> 2 con el stepper
      await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
      await settleQuote(tester);
      expect(container.read(cartProvider).lines.single.input.quantity, 2);
      expect(backend.orders.quoteCalls.last.single.quantity, 2, reason: 'recotiza al cambiar la cantidad');

      // tope de 20
      container.read(cartProvider.notifier).setQuantity(container.read(cartProvider).lines.single.id, 20);
      await settleQuote(tester);
      expect(find.text('Máximo 20 pizzas por línea'), findsOneWidget);
      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add)).onPressed, isNull);

      // quitar y deshacer
      await tester.tap(find.byTooltip('Quitar del pedido'));
      await tester.pumpAndSettle();
      expect(find.text('Tu pedido está vacío.'), findsOneWidget);
      expect(find.text('Pizza quitada'), findsOneWidget);
      await tester.tap(find.text('Deshacer'));
      await settleQuote(tester);
      expect(container.read(cartProvider).lines.length, 1);
      expect(find.text('Tu pedido está vacío.'), findsNothing);
    });

    testWidgets('estado vacio con acciones', (tester) async {
      await pumpGoodPizza(tester, FakeBackend(), location: '/cart');
      expect(find.text('Tu pedido está vacío.'), findsOneWidget);
      expect(find.text('Agrega una pizza predefinida o arma la tuya.'), findsOneWidget);
      expect(find.text('Ver pizzas predefinidas'), findsOneWidget);
      expect(find.text('Personalizar pizza'), findsWidgets);
    });

    testWidgets('WT-15 muestra Subtotal 15 %, Subtotal 0 %, IVA 15 % y TOTAL exactamente como los devuelve el API',
        (tester) async {
      final backend = FakeBackend();
      // El API devuelve estos totales; la UI no debe recalcularlos (ej. del contrato §4).
      backend.orders.quoteTransform = (json) => {
            ...json,
            'totals': {
              'subtotalVat15': '15.40',
              'subtotalVat0': '3.60',
              'vat15': '2.31',
              'total': '21.31',
              'totalCalories': 1640,
            },
          };
      await openCart(tester, backend, [margherita(quantity: 2)]);

      expect(find.text('Calorías totales'), findsOneWidget);
      expect(find.text('1640 kcal'), findsOneWidget);
      expect(find.text('Subtotal 15 %'), findsOneWidget);
      expect(find.text('\$ 15.40'), findsOneWidget);
      expect(find.text('Subtotal 0 %'), findsOneWidget);
      expect(find.text('\$ 3.60'), findsOneWidget);
      expect(find.text('IVA 15 %'), findsOneWidget);
      expect(find.text('\$ 2.31'), findsOneWidget);
      expect(find.text('TOTAL (USD)'), findsOneWidget);
      expect(find.text('\$ 21.31'), findsOneWidget);
    });

    testWidgets('detalle de la linea: componentes, c/u y linea', (tester) async {
      await openCart(tester, FakeBackend(), [customCheese(quantity: 2)]);
      expect(find.textContaining('Pizza 1 · Personalizada · Mediana'), findsOneWidget);
      expect(find.textContaining('Queso mozzarella x3'), findsOneWidget);
      expect(find.textContaining('c/u'), findsOneWidget);
      expect(find.textContaining('Línea: '), findsOneWidget);
    });

    testWidgets('con violaciones (stock agregado) el banner explica y Confirmar queda deshabilitado', (tester) async {
      final backend = FakeBackend();
      // mozzarella tiene 120; pedimos 3 x 41 = 123 > 120
      await openCart(tester, backend, [
        PizzaItemInput(
          type: PizzaTypes.custom,
          sizeCode: 'MEDIUM',
          doughId: 'd1',
          sauceId: 's1',
          toppings: const [
            PortionInput(ingredientId: 'c1', portions: 3),
            PortionInput(ingredientId: 'm1', portions: 1),
            PortionInput(ingredientId: 'v1', portions: 1),
          ],
          quantity: 20,
        ),
        customCheese(quantity: 20),
        customCheese(quantity: 20),
        customCheese(quantity: 20),
        customCheese(quantity: 20),
        customCheese(quantity: 20),
        customCheese(quantity: 20),
      ]);
      expect(find.textContaining('No hay stock suficiente de Queso mozzarella'), findsWidgets);
      expect(tester.widget<FilledButton>(confirmButton()).onPressed, isNull);
    });

    testWidgets('error de cotizacion: banner con Reintentar y Confirmar deshabilitado', (tester) async {
      final backend = FakeBackend();
      backend.orders.quoteError = apiError('INTERNAL_ERROR', status: 500);
      await openCart(tester, backend, [margherita()]);
      expect(find.text('No se pudo calcular el pedido.'), findsOneWidget);
      expect(tester.widget<FilledButton>(confirmButton()).onPressed, isNull);
      backend.orders.quoteError = null;
      await tester.tap(find.text('Reintentar'));
      await settleQuote(tester);
      expect(find.text('No se pudo calcular el pedido.'), findsNothing);
      expect(tester.widget<FilledButton>(confirmButton()).onPressed, isNotNull);
    });

    testWidgets('confirmar: dialogo con el total, expectedTotal enviado, carrito vaciado y comprobante con banner',
        (tester) async {
      final backend = FakeBackend();
      final container = await openCart(tester, backend, [margherita(quantity: 2)]);
      // Margarita mediana x2: subtotal15 = (2.00+3.00)x2 = 10.00; subtotal0 = 2.00; IVA 1.50; total 13.50
      expect(find.text('\$ 13.50'), findsOneWidget);

      await tester.tap(confirmButton());
      await tester.pumpAndSettle();
      expect(find.textContaining('¿Confirmar el pedido por \$ 13.50?'), findsOneWidget);
      expect(find.textContaining('no se puede cancelar'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
      await tester.pumpAndSettle();

      expect(backend.orders.createCalls.single.expectedTotal, '13.50');
      expect(container.read(cartProvider).isEmpty, isTrue);
      expect(find.textContaining('confirmado. Lo estamos preparando'), findsOneWidget);
      expect(find.text('GP-20261106-0001'), findsWidgets);
    });

    testWidgets('WT-16 INSUFFICIENT_STOCK: dialogo con ingrediente, solicitado y disponible', (tester) async {
      final backend = FakeBackend();
      backend.orders.createErrors.add(apiError('INSUFFICIENT_STOCK', status: 409, details: [
        {'ingredientId': 'c1', 'code': 'C1', 'name': 'Queso mozzarella', 'requested': 6, 'available': 4},
      ]));
      final container = await openCart(tester, backend, [margherita(quantity: 3)]);
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
      await tester.pumpAndSettle();

      expect(find.text('Stock insuficiente'), findsOneWidget);
      expect(find.text('No hay stock suficiente de Queso mozzarella: solicitado 6, disponible 4.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Ajustar pedido'));
      await tester.pumpAndSettle();
      expect(container.read(cartProvider).isEmpty, isFalse, reason: 'el carrito se conserva');
    });

    testWidgets('WT-16 PRICE_CHANGED: muestra el nuevo total y permite aceptar y confirmar', (tester) async {
      final backend = FakeBackend();
      backend.orders.enforceExpectedTotal = false;
      backend.orders.createErrors.add(apiError('PRICE_CHANGED', status: 409, details: [
        {
          'quote': {
            'items': [],
            'totals': {'subtotalVat15': '12.00', 'subtotalVat0': '2.00', 'vat15': '1.80', 'total': '15.80', 'totalCalories': 1},
          },
        },
      ]));
      await openCart(tester, backend, [margherita(quantity: 2)]);
      await tester.tap(confirmButton());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
      await tester.pumpAndSettle();

      expect(find.text('El precio cambió'), findsOneWidget);
      expect(find.text('El total ahora es \$ 15.80 (antes \$ 13.50).'), findsOneWidget);
      await tester.tap(find.text('Aceptar y confirmar'));
      await tester.pumpAndSettle();
      expect(backend.orders.createCalls.length, 2);
      expect(backend.orders.createCalls.last.expectedTotal, '15.80', reason: 'reenvia con el nuevo expectedTotal');
      expect(find.textContaining('confirmado'), findsWidgets);
    });

    testWidgets('PIZZA_RULES_VIOLATED, FORBIDDEN y errores de red al confirmar', (tester) async {
      final backend = FakeBackend();
      final container = await openCart(tester, backend, [margherita()]);

      Future<void> confirm() async {
        await tester.tap(confirmButton());
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
        await tester.pumpAndSettle();
      }

      backend.orders.createErrors.add(apiError('PIZZA_RULES_VIOLATED', status: 422, details: [
        {'code': 'MAX_PORTIONS_EXCEEDED', 'message': 'Máximo 3 porciones por ingrediente (Queso mozzarella: 4).', 'itemIndex': 0},
      ]));
      await confirm();
      expect(find.textContaining('Pizza 1: Máximo 3 porciones por ingrediente (Queso mozzarella: 4).'), findsOneWidget);

      backend.orders.createErrors.add(apiError('FORBIDDEN', status: 403));
      await confirm();
      expect(find.text('Tu cuenta no puede crear pedidos.'), findsOneWidget);

      backend.orders.createErrors.add(apiError('INTERNAL_ERROR', status: 500));
      await confirm();
      expect(find.text('No se pudo confirmar el pedido. Inténtalo de nuevo.'), findsOneWidget);
      expect(container.read(cartProvider).isEmpty, isFalse, reason: 'el carrito se conserva');
      // Reintentar desde el banner
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('confirmado'), findsWidgets);
    });
  });
}
