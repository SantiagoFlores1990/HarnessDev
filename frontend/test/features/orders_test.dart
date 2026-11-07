import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:good_pizza/core/utils/money_format.dart';
import 'package:good_pizza/features/orders/domain/order_models.dart';
import 'package:good_pizza/features/orders/presentation/receipt_view.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

/// Pedido de ejemplo: personalizada (x2) + Margarita con extras.
OrderDetail sampleOrder(FakeBackend backend, {String status = 'PENDING'}) {
  final json = backend.server.orderJson(
    const [
      PizzaItemInput(
        type: PizzaTypes.custom,
        sizeCode: 'MEDIUM',
        doughId: 'd1',
        sauceId: 's1',
        toppings: [
          PortionInput(ingredientId: 'c1', portions: 3),
          PortionInput(ingredientId: 'm1', portions: 1),
          PortionInput(ingredientId: 'v1', portions: 1),
        ],
        quantity: 2,
      ),
      PizzaItemInput(
        type: PizzaTypes.preset,
        presetPizzaId: 'margherita',
        sizeCode: 'MEDIUM',
        extras: [PortionInput(ingredientId: 'c1', portions: 1), PortionInput(ingredientId: 'm1', portions: 1)],
      ),
    ],
    status: status,
  );
  return OrderDetail.fromJson(json);
}

OrderSummary summary(String id, String number, OrderStatus status, String total, {int pizzas = 1, String name = 'Ana Pérez'}) =>
    OrderSummary(
      id: id,
      orderNumber: number,
      createdAt: DateTime.utc(2026, 11, 6, 15, 4),
      status: status,
      customer: CustomerInfo(id: 'u-1', fullName: name, email: 'ana@ejemplo.com'),
      pizzaCount: pizzas,
      totalCalories: 800,
      total: total,
    );

void main() {
  group('S-13 comprobante', () {
    testWidgets('WT-17 muestra todos los bloques del comprobante y no ofrece imprimir/PDF', (tester) async {
      final backend = FakeBackend();
      final order = sampleOrder(backend);
      backend.orders.orders[order.id] = order;
      await pumpGoodPizza(tester, backend, location: '/orders/${order.id}');

      // Encabezado: logo + "Good Pizza", numero y fecha local
      expect(find.byType(SvgPicture), findsWidgets);
      expect(find.text('Good Pizza'), findsWidgets);
      expect(find.text('GP-20261106-0001'), findsWidgets);
      expect(find.text(formatDateTime(DateTime.parse('2026-11-06T15:04:05.123Z'))), findsWidgets);
      // Cliente
      expect(find.text('CLIENTE'), findsOneWidget);
      expect(find.text('Ana Pérez'), findsWidgets);
      expect(find.text('ana@ejemplo.com'), findsOneWidget);
      // Pizza 1 (personalizada x2)
      expect(find.text('PIZZA 1 · Personalizada'), findsOneWidget);
      expect(find.text('Cantidad x2'), findsOneWidget);
      expect(find.text('Tamaño: Mediana'), findsNWidgets(2));
      expect(find.text('Masa: Masa tradicional'), findsNWidgets(2));
      expect(find.text('Salsa: Salsa de tomate'), findsNWidgets(2));
      expect(find.text('Ingrediente'), findsNWidgets(2));
      expect(find.text('Cant.'), findsNWidgets(2));
      expect(find.text('Calorías'), findsNWidgets(2));
      expect(find.text('Precio (sin IVA)'), findsNWidgets(2));
      // masa 2.00/300, salsa 1.00/60, queso x3 4.50/330, jamon 1.20/90, champinones 0.90/25
      expect(find.text('\$ 4.50'), findsNWidgets(2), reason: 'queso x3 en la personalizada y 2+1 en Margarita');
      expect(find.text('330 kcal'), findsNWidgets(2));
      expect(find.text('Por pizza'), findsNWidgets(2));
      expect(find.text('805 kcal'), findsOneWidget);
      expect(find.text('\$ 9.60'), findsOneWidget);
      expect(find.text('Línea (x2)'), findsOneWidget);
      expect(find.text('1610 kcal'), findsOneWidget);
      expect(find.text('\$ 19.20'), findsOneWidget);
      // Pizza 2 (predefinida con extras marcados)
      expect(find.text('PIZZA 2 · Margarita (predefinida)'), findsOneWidget);
      expect(find.text('Queso mozzarella (2 receta + 1 extra)'), findsOneWidget);
      expect(find.text('Jamón (extra)'), findsOneWidget);
      // Resumen con totales del API
      expect(find.text('RESUMEN'), findsOneWidget);
      expect(find.text('Calorías totales'), findsOneWidget);
      expect(find.text('Subtotal 15 %'), findsOneWidget);
      expect(find.text('Subtotal 0 %'), findsOneWidget);
      expect(find.text('IVA 15 %'), findsOneWidget);
      expect(find.text('TOTAL (USD)'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('receipt-total'))).data, formatMoney(order.totals.total));
      expect(find.text(formatKcal(order.totals.totalCalories)), findsOneWidget);
      // Estado actual
      expect(find.text('ESTADO ACTUAL'), findsOneWidget);
      expect(find.text('Pendiente'), findsWidgets);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(find.textContaining('Actualizado: '), findsOneWidget);
      // Pie
      expect(find.text(receiptFooterText), findsOneWidget);
      expect(receiptFooterText, 'Documento informativo del pedido. No es una factura electrónica.');

      // Ausencias: sin imprimir, PDF, exportar ni compartir
      expect(find.textContaining(RegExp('imprimir|PDF|exportar|compartir', caseSensitive: false)), findsNothing);
      for (final icon in [Icons.print, Icons.picture_as_pdf, Icons.share, Icons.download]) {
        expect(find.byIcon(icon), findsNothing);
      }
    });

    testWidgets('el orden de los bloques es el del diseno', (tester) async {
      final backend = FakeBackend();
      final order = sampleOrder(backend);
      backend.orders.orders[order.id] = order;
      await pumpGoodPizza(tester, backend, location: '/orders/${order.id}');
      double y(String text) => tester.getTopLeft(find.text(text).first).dy;
      expect(y('CLIENTE'), lessThan(y('PIZZA 1 · Personalizada')));
      expect(y('PIZZA 1 · Personalizada'), lessThan(y('PIZZA 2 · Margarita (predefinida)')));
      expect(y('PIZZA 2 · Margarita (predefinida)'), lessThan(y('RESUMEN')));
      expect(y('RESUMEN'), lessThan(y('ESTADO ACTUAL')));
      expect(y('ESTADO ACTUAL'), lessThan(y(receiptFooterText)));
    });

    testWidgets('estados del pedido: En preparacion y Entregado', (tester) async {
      final backend = FakeBackend();
      final order = sampleOrder(backend, status: 'IN_PREPARATION');
      backend.orders.orders[order.id] = order;
      await pumpGoodPizza(tester, backend, location: '/orders/${order.id}');
      expect(find.byIcon(Icons.soup_kitchen), findsOneWidget);
      expect(find.text('En preparación'), findsWidgets);
    });

    testWidgets('pedido ajeno o inexistente (404): "No encontramos este pedido."', (tester) async {
      await pumpGoodPizza(tester, FakeBackend(), location: '/orders/no-existe');
      expect(find.text('No encontramos este pedido.'), findsOneWidget);
      expect(find.text('Puede que no exista o que no sea tuyo.'), findsOneWidget);
      await tester.tap(find.text('Volver a Mis pedidos'));
      await tester.pumpAndSettle();
      expect(find.text('Mis pedidos'), findsWidgets);
    });

    testWidgets('error de carga con Reintentar', (tester) async {
      final backend = FakeBackend();
      final order = sampleOrder(backend);
      backend.orders.orders[order.id] = order;
      backend.orders.getError = apiError('INTERNAL_ERROR', status: 500);
      await pumpGoodPizza(tester, backend, location: '/orders/${order.id}');
      expect(find.text('No se pudo cargar el pedido.'), findsOneWidget);
      backend.orders.getError = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('RESUMEN'), findsOneWidget);
    });

    test('spokenMoney para lectores de pantalla', () {
      expect(spokenMoney('4.50'), '4 dólares con 50 centavos');
    });
  });

  group('S-06 mis pedidos', () {
    testWidgets('WT-18 lista solo lo que devuelve el repositorio con chip de estado (color + icono + texto)',
        (tester) async {
      final backend = FakeBackend();
      backend.orders.summaries = [
        summary('1', 'GP-20261106-0003', OrderStatus.pending, '25.44', pizzas: 3),
        summary('2', 'GP-20261106-0001', OrderStatus.inPreparation, '21.31', pizzas: 2),
        summary('3', 'GP-20261105-0007', OrderStatus.delivered, '9.80'),
      ];
      await pumpGoodPizza(tester, backend, location: '/orders');

      expect(find.text('GP-20261106-0003'), findsOneWidget);
      expect(find.text('GP-20261106-0001'), findsOneWidget);
      expect(find.text('GP-20261105-0007'), findsOneWidget);
      expect(find.text('\$ 25.44'), findsOneWidget);
      expect(find.text('\$ 9.80'), findsOneWidget);
      // texto + icono de cada estado
      for (final (label, icon) in [
        ('Pendiente', Icons.schedule),
        ('En preparación', Icons.soup_kitchen),
        ('Entregado', Icons.check_circle),
      ]) {
        final chip = find.ancestor(of: find.text(label).last, matching: find.byType(Container)).first;
        expect(find.descendant(of: chip, matching: find.byIcon(icon)), findsOneWidget, reason: label);
      }
      expect(find.text('Los pedidos no se pueden cancelar desde la aplicación.'), findsOneWidget);
      expect(find.textContaining(RegExp('cancelar pedido', caseSensitive: false)), findsNothing);
      expect(backend.orders.listCalls.first.status, isNull);
    });

    testWidgets('WT-18 estado vacio: "Aún no tienes pedidos."', (tester) async {
      await pumpGoodPizza(tester, FakeBackend(), location: '/orders');
      expect(find.text('Aún no tienes pedidos.'), findsOneWidget);
      expect(find.text('Cuando confirmes uno, aparecerá aquí con su estado.'), findsOneWidget);
      expect(find.text('Ver pizzas predefinidas'), findsOneWidget);
    });

    testWidgets('filtrar por estado envia status al API; sin resultados ofrece "Quitar filtro"', (tester) async {
      final backend = FakeBackend();
      backend.orders.summaries = [summary('1', 'GP-20261106-0003', OrderStatus.pending, '25.44')];
      await pumpGoodPizza(tester, backend, location: '/orders');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Entregado'));
      await tester.pumpAndSettle();
      expect(backend.orders.listCalls.last.status, OrderStatus.delivered);
      expect(find.text('No hay pedidos con ese estado.'), findsOneWidget);
      await tester.tap(find.text('Quitar filtro'));
      await tester.pumpAndSettle();
      expect(find.text('GP-20261106-0003'), findsOneWidget);
    });

    testWidgets('error con Reintentar; el refresco es manual (boton y F5), sin refresco automatico', (tester) async {
      final backend = FakeBackend();
      backend.orders.listError = apiError('INTERNAL_ERROR', status: 500);
      await pumpGoodPizza(tester, backend, location: '/orders');
      expect(find.text('No se pudieron cargar tus pedidos.'), findsOneWidget);
      backend.orders.listError = null;
      backend.orders.summaries = [summary('1', 'GP-20261106-0003', OrderStatus.pending, '25.44')];
      final calls = backend.orders.listCalls.length;
      await tester.pump(const Duration(minutes: 5));
      expect(backend.orders.listCalls.length, calls, reason: 'no hay refresco automatico');

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('GP-20261106-0003'), findsOneWidget);

      backend.orders.summaries = [
        summary('1', 'GP-20261106-0003', OrderStatus.inPreparation, '25.44'),
      ];
      await tester.tap(find.text('Actualizar'));
      await tester.pumpAndSettle();
      expect(find.text('En preparación'), findsWidgets);
    });

    testWidgets('abrir un pedido con clic navega al comprobante', (tester) async {
      final backend = FakeBackend();
      final order = sampleOrder(backend);
      backend.orders.orders[order.id] = order;
      backend.orders.summaries = [summary(order.id, order.orderNumber, OrderStatus.pending, order.totals.total)];
      await pumpGoodPizza(tester, backend, location: '/orders');
      await tester.tap(find.text(order.orderNumber));
      await tester.pumpAndSettle();
      expect(find.text('RESUMEN'), findsOneWidget);
    });
  });
}
