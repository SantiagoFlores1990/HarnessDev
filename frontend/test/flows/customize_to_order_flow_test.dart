import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:good_pizza/features/orders/domain/order_models.dart';

import '../helpers/fakes.dart';
import '../helpers/finders.dart';
import '../helpers/pump_app.dart';

/// WT-29: flujo completo "personalizar pizza hasta generar la orden" (criterio de aceptacion 1),
/// con repositorios falsos y un doble del motor del servidor.
///
/// Datos (tamano Mediana): masa 2.00/300 (15 %), salsa 1.00/60 (0 %), queso mozzarella x3
/// 4.50/330 (15 %), jamon 1.20/90 (15 %), champinones 0.90/25 (15 %).
///   precio de la pizza = 9.60; calorias = 805
///   subtotal 15 % = 8.60; subtotal 0 % = 1.00; IVA 15 % = 1.29; TOTAL = 10.89
void main() {
  testWidgets('WT-29 triple queso: personalizar -> agregar -> resumen con IVA -> confirmar -> comprobante',
      (tester) async {
    final backend = FakeBackend();
    await pumpGoodPizza(tester, backend);

    // 1. Menu lateral -> Personalizar pizza
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Personalizar pizza')));
    await settleQuote(tester);
    expect(find.text('1. Tamaño'), findsOneWidget);

    // 2. Tamano (Mediana por defecto), masa, salsa y triple queso + jamon + champinones
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
    await settleQuote(tester);

    // 3. Calorias y precio en vivo (del servidor)
    expect(tester.widget<Text>(find.byKey(const Key('builder-price'))).data, '\$ 9.60');
    expect(tester.widget<Text>(find.byKey(const Key('builder-calories'))).data, '805 kcal');
    expect(find.text('· Queso mozzarella  x3'), findsOneWidget);
    expect(tester.widget<FilledButton>(addToOrderButton()).onPressed, isNotNull);

    // 4. Agregar al pedido
    await tester.tap(addToOrderButton());
    await tester.pumpAndSettle();
    expect(find.text('Pizza agregada'), findsOneWidget);
    // el armado se reinicia
    expect(isChecked(tester, 'Masa tradicional'), isFalse);

    // 5. Ver pedido: resumen con IVA desglosado
    await tester.tap(find.text('Ver pedido'));
    await settleQuote(tester);
    expect(find.text('Resumen del pedido'), findsOneWidget);
    expect(find.textContaining('Pizza 1 · Personalizada · Mediana'), findsOneWidget);
    expect(find.text('805 kcal'), findsOneWidget);
    expect(find.text('Subtotal 15 %'), findsOneWidget);
    expect(find.text('\$ 8.60'), findsOneWidget);
    expect(find.text('Subtotal 0 %'), findsOneWidget);
    expect(find.text('\$ 1.00'), findsWidgets);
    expect(find.text('IVA 15 %'), findsOneWidget);
    expect(find.text('\$ 1.29'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('cart-total'))).data, '\$ 10.89');

    // 6. Confirmar (dialogo)
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar pedido'));
    await tester.pumpAndSettle();
    expect(find.textContaining('¿Confirmar el pedido por \$ 10.89?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();

    // Payload enviado al API
    final call = backend.orders.createCalls.single;
    expect(call.expectedTotal, '10.89');
    final json = call.items.single.toJson();
    expect(json['type'], PizzaTypes.custom);
    expect(json['sizeCode'], 'MEDIUM');
    expect(json['doughId'], 'd1');
    expect(json['sauceId'], 's1');
    expect(json['quantity'], 1);
    expect(
      (json['toppings'] as List).map((t) => '${(t as Map)['ingredientId']}:${t['portions']}').toSet(),
      {'c1:3', 'm1:1', 'v1:1'},
    );

    // 7. Comprobante: orden, cliente, pizza con calorias y precio, resumen con IVA, estado
    expect(find.textContaining('confirmado. Lo estamos preparando'), findsOneWidget);
    expect(find.text('GP-20261106-0001'), findsWidgets);
    expect(find.text('Ana Pérez'), findsWidgets);
    expect(find.text('PIZZA 1 · Personalizada'), findsOneWidget);
    expect(find.text('Queso mozzarella'), findsOneWidget);
    expect(find.text('330 kcal'), findsOneWidget);
    expect(find.text('\$ 4.50'), findsOneWidget);
    expect(find.text('Calorías totales'), findsOneWidget);
    expect(find.text('805 kcal'), findsWidgets);
    expect(find.text('Subtotal 15 %'), findsOneWidget);
    expect(find.text('Subtotal 0 %'), findsOneWidget);
    expect(find.text('IVA 15 %'), findsOneWidget);
    expect(find.text('\$ 1.29'), findsOneWidget);
    expect(find.text('TOTAL (USD)'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('receipt-total'))).data, '\$ 10.89');
    expect(find.text('Pendiente'), findsWidgets);
  });

  testWidgets('WT-29b predefinida con extras: personalizar Margarita (+1 jamon) -> pedido -> confirmar', (tester) async {
    final backend = FakeBackend();
    await pumpGoodPizza(tester, backend);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Personalizar').first);
    await settleQuote(tester);
    expect(find.textContaining('Personalizando Margarita.'), findsOneWidget);
    await tester.tap(checkboxOf('Jamón'));
    await settleQuote(tester);
    await tester.tap(addToOrderButton());
    await tester.pumpAndSettle();
    // al venir de una predefinida vuelve a /presets
    expect(find.text('Pizzas predefinidas'), findsWidgets);

    await tester.tap(find.text('Ver pedido'));
    await settleQuote(tester);
    expect(find.textContaining('Pizza 1 · Margarita · Mediana'), findsOneWidget);
    expect(find.textContaining('Jamón x1 (extra)'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();
    final json = backend.orders.createCalls.single.items.single.toJson();
    expect(json['type'], PizzaTypes.preset);
    expect(json['presetPizzaId'], 'margherita');
    expect(json.containsKey('doughId'), isFalse, reason: 'en PRESET no se envian masa/salsa/receta');
    expect((json['extras'] as List).single, {'ingredientId': 'm1', 'portions': 1});
    expect(find.text('PIZZA 1 · Margarita (predefinida)'), findsOneWidget);
    expect(find.text('Jamón (extra)'), findsOneWidget);
  });
}
