import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:good_pizza/features/orders/domain/order_models.dart';

import '../helpers/fakes.dart';
import '../helpers/finders.dart';
import '../helpers/pump_app.dart';

Future<FakeBackend> openBuilder(WidgetTester tester, {String location = '/builder', FakeBackend? backend}) async {
  final b = backend ?? FakeBackend();
  await pumpGoodPizza(tester, b, location: location);
  await settleQuote(tester);
  return b;
}

void main() {
  testWidgets('WT-08 masa/salsa exclusivas y mensajes "Elige una masa." / "Elige una salsa base."', (tester) async {
    await openBuilder(tester);

    // Sin masa ni salsa: el servidor informa las violaciones y la UI las muestra.
    expect(find.text('Elige una masa.'), findsWidgets);
    expect(find.text('Elige una salsa base.'), findsWidgets);

    await tester.tap(checkboxOf('Masa tradicional'));
    await tester.pump();
    expect(isChecked(tester, 'Masa tradicional'), isTrue);

    await tester.tap(checkboxOf('Masa delgada'));
    await tester.pump();
    expect(isChecked(tester, 'Masa delgada'), isTrue);
    expect(isChecked(tester, 'Masa tradicional'), isFalse, reason: 'marcar otra masa desmarca la anterior');

    await tester.tap(checkboxOf('Salsa de tomate'));
    await tester.tap(checkboxOf('Salsa BBQ'));
    await tester.pump();
    expect(isChecked(tester, 'Salsa BBQ'), isTrue);
    expect(isChecked(tester, 'Salsa de tomate'), isFalse);

    // Se puede desmarcar la seleccionada: vuelve el mensaje.
    await tester.tap(checkboxOf('Masa delgada'));
    await settleQuote(tester);
    expect(isChecked(tester, 'Masa delgada'), isFalse);
    expect(find.text('Elige una masa.'), findsWidgets);
  });

  testWidgets('masa y salsa no aparecen como ingredientes adicionales (seccion 4)', (tester) async {
    await openBuilder(tester);
    // Cada masa/salsa aparece una sola vez (secciones 2 y 3), nunca en la seccion 4.
    expect(find.text('Masa tradicional'), findsOneWidget);
    expect(find.text('Salsa BBQ'), findsOneWidget);
    expect(find.text('Queso mozzarella'), findsOneWidget);
  });

  testWidgets('WT-09 el stepper no pasa de 3 porciones y muestra el mensaje de maximo', (tester) async {
    await openBuilder(tester);
    await tester.tap(checkboxOf('Queso mozzarella'));
    await tester.pump();

    await tester.tap(plusOf('Queso mozzarella'));
    await tester.pump();
    await tester.tap(plusOf('Queso mozzarella'));
    await tester.pump();

    expect(find.descendant(of: rowOf('Queso mozzarella'), matching: find.text('3')), findsOneWidget);
    expect(isEnabled(tester, plusOf('Queso mozzarella')), isFalse, reason: 'tope de 3 porciones');
    expect(find.text('Máximo 3 porciones por ingrediente'), findsOneWidget);
  });

  testWidgets('WT-10 stock 2: maximo 2 y "Stock disponible: 2"; stock 0 deshabilitado con "Agotado"', (tester) async {
    await openBuilder(tester);

    await tester.tap(checkboxOf('Champiñones'));
    await tester.pump();
    await tester.tap(plusOf('Champiñones'));
    await tester.pump();
    expect(find.descendant(of: rowOf('Champiñones'), matching: find.text('2')), findsOneWidget);
    expect(isEnabled(tester, plusOf('Champiñones')), isFalse);
    expect(find.text('Stock disponible: 2'), findsOneWidget);

    // Piña (stock 0): casilla deshabilitada y chip "Agotado" con texto.
    expect(tester.widget<Checkbox>(checkboxOf('Piña')).onChanged, isNull);
    expect(find.descendant(of: rowOf('Piña'), matching: find.text('Agotado')), findsOneWidget);
    // Tambien la masa integral agotada.
    expect(tester.widget<Checkbox>(checkboxOf('Masa integral')).onChanged, isNull);
  });

  testWidgets('WT-11 cotiza con debounce y muestra unitPrice/unitCalories del servidor (7.50 / 690 kcal)', (tester) async {
    final backend = await openBuilder(tester);
    final baseline = backend.orders.quoteCalls.length;

    // Cambios rapidos (sin avanzar el reloj): el debounce los agrupa en UNA cotizacion.
    await tester.tap(checkboxOf('Masa tradicional'));
    await tester.tap(checkboxOf('Salsa de tomate'));
    await tester.tap(checkboxOf('Queso mozzarella'));
    await tester.pump();
    await tester.tap(plusOf('Queso mozzarella'));
    await tester.pump();
    await tester.tap(plusOf('Queso mozzarella'));
    await tester.pump();
    expect(backend.orders.quoteCalls.length, baseline, reason: 'aun no vence el debounce de 150 ms');
    expect(find.text('Calculando…'), findsOneWidget);

    await settleQuote(tester);
    expect(backend.orders.quoteCalls.length, baseline + 1);
    final item = backend.orders.quoteCalls.last.single;
    expect(item.type, 'CUSTOM');
    expect(item.sizeCode, 'MEDIUM');
    expect(item.doughId, 'd1');
    expect(item.sauceId, 's1');
    expect(item.toppings.single.portions, 3);

    // masa 2.00 + salsa 1.00 + queso 1.50 x3 = 7.50; 300 + 60 + 330 = 690
    expect(tester.widget<Text>(find.byKey(const Key('builder-price'))).data, '\$ 7.50');
    expect(tester.widget<Text>(find.byKey(const Key('builder-calories'))).data, '690 kcal');
    expect(find.text('Calculando…'), findsNothing);
  });

  testWidgets('cambiar el tamano recalcula y muestra precios por porcion del tamano elegido', (tester) async {
    final backend = await openBuilder(tester);
    await tester.tap(checkboxOf('Masa tradicional'));
    await tester.tap(checkboxOf('Salsa de tomate'));
    await settleQuote(tester);
    expect(find.text('+\$ 1.50 · 110 kcal'), findsOneWidget, reason: 'mozzarella mediana');

    await tester.tap(find.text('Familiar'));
    await settleQuote(tester);
    expect(find.text('+\$ 2.25 · 165 kcal'), findsOneWidget, reason: 'mozzarella familiar');
    expect(backend.orders.quoteCalls.last.single.sizeCode, 'FAMILY');
  });

  testWidgets('la peticion anterior se cancela cuando llega un cambio nuevo', (tester) async {
    final backend = FakeBackend();
    backend.orders.quoteDelay = const Duration(milliseconds: 400);
    await pumpGoodPizza(tester, backend, location: '/builder');
    // Cada peticion tarda 400 ms. Se hace un cambio, vence el debounce (peticion en vuelo) y se
    // hace otro cambio antes de que responda: la primera debe cancelarse.
    await tester.tap(checkboxOf('Masa tradicional'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final inFlight = backend.orders.quoteCalls.length;
    await tester.tap(checkboxOf('Salsa de tomate'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(backend.orders.quoteCalls.length, greaterThan(inFlight));
    expect(backend.orders.cancelledQuotes, greaterThanOrEqualTo(1));
    expect(find.text('Calculando…'), findsNothing);
  });

  testWidgets('WT-12 con MIN_TOPPINGS_NOT_MET "Agregar al pedido" esta deshabilitado y se explica', (tester) async {
    await openBuilder(tester);
    await tester.tap(checkboxOf('Masa tradicional'));
    await tester.tap(checkboxOf('Salsa de tomate'));
    await tester.tap(checkboxOf('Queso mozzarella'));
    await settleQuote(tester);

    expect(find.text('Elige al menos 3 ingredientes distintos.'), findsWidgets);
    expect(tester.widget<FilledButton>(addToOrderButton()).onPressed, isNull);
    expect(find.text('Ingredientes: 1 de 3 mínimos'), findsOneWidget);

    // Con 3 ingredientes distintos el boton se habilita.
    await tester.tap(checkboxOf('Jamón'));
    await tester.tap(checkboxOf('Pepperoni'));
    await settleQuote(tester);
    expect(find.text('Elige al menos 3 ingredientes distintos.'), findsNothing);
    expect(tester.widget<FilledButton>(addToOrderButton()).onPressed, isNotNull);
  });

  testWidgets('WT-13 personalizar Margarita: receta bloqueada, minimo = receta, extras = porciones - receta',
      (tester) async {
    final backend = await openBuilder(tester, location: '/builder?presetId=margherita&size=MEDIUM');

    expect(find.textContaining('Personalizando Margarita.'), findsOneWidget);
    // masa y salsa de la receta: marcadas y bloqueadas
    expect(isChecked(tester, 'Masa tradicional'), isTrue);
    expect(tester.widget<Checkbox>(checkboxOf('Masa tradicional')).onChanged, isNull);
    expect(isChecked(tester, 'Salsa de tomate'), isTrue);
    expect(find.text('Parte de la receta'), findsNWidgets(2));
    // sin aviso de minimo de 3 ingredientes
    expect(find.text('Elige al menos 3 ingredientes distintos.'), findsNothing);
    expect(find.textContaining('de 3 mínimos'), findsNothing);

    // mozzarella: receta 2 -> casilla marcada/bloqueada, minimo 2
    expect(isChecked(tester, 'Queso mozzarella'), isTrue);
    expect(tester.widget<Checkbox>(checkboxOf('Queso mozzarella')).onChanged, isNull);
    expect(isEnabled(tester, minusOf('Queso mozzarella')), isFalse, reason: 'no se puede bajar de la receta');
    expect(backend.orders.quoteCalls.last.single.extras, isEmpty, reason: 'sin extras todavia');

    // +1 porcion (3 en total) -> extra de 1
    await tester.tap(plusOf('Queso mozzarella'));
    await settleQuote(tester);
    var last = backend.orders.quoteCalls.last.single;
    expect(last.type, PizzaTypes.preset);
    expect(last.presetPizzaId, 'margherita');
    expect(last.extras.single.ingredientId, 'c1');
    expect(last.extras.single.portions, 1);
    expect(isEnabled(tester, plusOf('Queso mozzarella')), isFalse, reason: 'receta 2 + 1 extra = 3');

    // agregar un ingrediente nuevo como extra
    await tester.tap(checkboxOf('Jamón'));
    await settleQuote(tester);
    last = backend.orders.quoteCalls.last.single;
    expect(last.extras.map((e) => '${e.ingredientId}:${e.portions}').toSet(), {'c1:1', 'm1:1'});
    expect(tester.widget<FilledButton>(addToOrderButton()).onPressed, isNotNull);
  });

  testWidgets('error de cotizacion: aviso con "Reintentar" y "Agregar" deshabilitado', (tester) async {
    final backend = FakeBackend();
    backend.orders.quoteError = apiError('INTERNAL_ERROR', status: 500);
    await pumpGoodPizza(tester, backend, location: '/builder');
    await settleQuote(tester);
    expect(find.text('No se pudo calcular el precio.'), findsOneWidget);
    expect(tester.widget<FilledButton>(addToOrderButton()).onPressed, isNull);

    backend.orders.quoteError = null;
    await tester.tap(find.text('Reintentar'));
    await settleQuote(tester);
    expect(find.text('No se pudo calcular el precio.'), findsNothing);
  });

  testWidgets('catalogo: estados de error con Reintentar y vacio', (tester) async {
    final backend = FakeBackend();
    backend.catalog.ingredientsError = apiError('INTERNAL_ERROR', status: 500);
    await pumpGoodPizza(tester, backend, location: '/builder');
    expect(find.text('No se pudo cargar el catálogo de ingredientes.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    backend.catalog.ingredientsError = null;
    backend.server.ingredients = [];
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('No hay ingredientes disponibles por ahora.'), findsOneWidget);
  });
}
