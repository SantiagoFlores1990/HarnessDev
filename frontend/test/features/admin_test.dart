import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:good_pizza/core/widgets/page_widgets.dart';
import 'package:good_pizza/features/orders/domain/order_models.dart';

import '../helpers/fakes.dart';
import '../helpers/finders.dart';
import '../helpers/fixtures.dart' as fx;
import '../helpers/pump_app.dart';
import 'orders_test.dart' show sampleOrder, summary;

FakeBackend adminBackend() {
  final backend = FakeBackend(user: FakeAuthRepository.adminUser);
  backend.server.ingredients = [
    ...fx.catalog,
    fx.ingredient('o2', 'Orégano', 'OTHER', stock: 10, medium: '0.30', mediumKcal: 5, active: false),
  ];
  return backend;
}

/// Fila de tabla (HoverRow) que contiene el texto [name].
Finder tableRow(String name) => find.ancestor(of: find.text(name), matching: find.byType(HoverRow)).first;

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<void> fillIngredientForm(WidgetTester tester, {bool skipFamilyPrice = false, String famPrice = '2.20'}) async {
  await tester.enterText(field('Código'), 'TEST-1');
  await tester.enterText(field('Nombre'), 'Ingrediente de prueba');
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Queso').last);
  await tester.pumpAndSettle();
  await tester.enterText(field('Precio (USD) Individual'), '1.00');
  await tester.enterText(field('Calorías (kcal) Individual'), '80');
  await tester.enterText(field('Precio (USD) Mediana'), '1.5');
  await tester.enterText(field('Calorías (kcal) Mediana'), '110');
  if (!skipFamilyPrice) await tester.enterText(field('Precio (USD) Familiar'), famPrice);
  await tester.enterText(field('Calorías (kcal) Familiar'), '160');
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Guardar ingrediente'));
  await tester.pumpAndSettle();
}

void main() {
  group('S-07 ingredientes (lista)', () {
    testWidgets('el ADMIN envia includeInactive=true y ve los inactivos marcados', (tester) async {
      final backend = adminBackend();
      await pumpGoodPizza(tester, backend);
      expect(find.text('Nuevo ingrediente'), findsOneWidget);
      expect(backend.catalog.includeInactiveCalls, isNotEmpty);
      expect(backend.catalog.includeInactiveCalls.every((v) => v), isTrue,
          reason: 'GET /ingredients y /preset-pizzas solo devuelven activos si no se envia includeInactive=true');
      expect(find.text('Orégano'), findsOneWidget);
      expect(find.text('Inactivo'), findsOneWidget);
      expect(find.text('Masa tradicional'), findsOneWidget);
      expect(find.text('IVA 15 %'), findsWidgets);
      expect(find.text('IVA 0 %'), findsWidgets);
      expect(find.text('Agotado'), findsWidgets, reason: 'stock 0 con chip');
    });

    testWidgets('WT-19 no existe la accion Eliminar; desactivar pide confirmacion', (tester) async {
      final backend = adminBackend();
      await pumpGoodPizza(tester, backend);
      expect(find.textContaining(RegExp('eliminar|borrar', caseSensitive: false)), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);

      final sw = find.descendant(of: tableRow('Masa tradicional'), matching: find.byType(Switch));
      await tester.tap(sw);
      await tester.pumpAndSettle();
      expect(find.textContaining('¿Desactivar Masa tradicional?'), findsOneWidget);
      expect(find.textContaining('Los pedidos anteriores no cambian.'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(backend.catalog.statusCalls, isEmpty, reason: 'cancelar no cambia nada');

      await tester.tap(sw);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
      await tester.pumpAndSettle();
      expect(backend.catalog.statusCalls.single, (id: 'd1', active: false));
      expect(find.text('Ingrediente desactivado'), findsOneWidget);
    });

    testWidgets('activar un ingrediente sin tamanos completos sugiere Editar', (tester) async {
      final backend = adminBackend();
      backend.catalog.statusError = apiError('MISSING_SIZE_VALUES', status: 422);
      await pumpGoodPizza(tester, backend);
      await tester.tap(find.descendant(of: tableRow('Orégano'), matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(backend.catalog.statusCalls.single.active, isTrue, reason: 'activar no pide confirmacion');
      expect(find.text('No se puede activar: faltan precio y calorías de algún tamaño.'), findsOneWidget);
      expect(find.text('Editar'), findsWidgets);
    });

    testWidgets('estados vacio, filtros y error con Reintentar', (tester) async {
      final backend = adminBackend();
      backend.server.ingredients = [];
      await pumpGoodPizza(tester, backend);
      expect(find.text('Aún no hay ingredientes.'), findsOneWidget);
      expect(find.text('Crear ingrediente'), findsOneWidget);

      backend.catalog.ingredientsError = apiError('INTERNAL_ERROR', status: 500);
      await tester.sendKeyEvent(LogicalKeyboardKey.f5); // F5 recarga la pantalla
      await tester.pumpAndSettle();
      expect(find.text('No se pudo cargar el catálogo.'), findsOneWidget);
      backend.catalog.ingredientsError = null;
      backend.server.ingredients = [...fx.catalog];
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Masa tradicional'), findsOneWidget);
    });

    testWidgets('WT-20 StockDialog: STOCK_WOULD_BE_NEGATIVE muestra su mensaje', (tester) async {
      final backend = adminBackend();
      backend.catalog.stockError = apiError('STOCK_WOULD_BE_NEGATIVE', status: 422);
      await pumpGoodPizza(tester, backend);
      await tester.tap(find.descendant(of: tableRow('Masa tradicional'), matching: find.byType(TextButton)));
      await tester.pumpAndSettle();
      expect(find.text('Stock de Masa tradicional'), findsOneWidget);
      expect(find.text('Stock actual: 40'), findsOneWidget);

      await tester.tap(find.text('Sumar o restar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '-999');
      await tester.pump();
      expect(find.text('Nuevo stock: -959'), findsOneWidget, reason: 'vista previa');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(backend.catalog.stockCalls.single, (id: 'd1', operation: 'ADD', value: -999));
      expect(find.text('El ajuste dejaría el stock por debajo de 0.'), findsOneWidget);
    });

    testWidgets('StockDialog: fijar valor correcto guarda y confirma', (tester) async {
      final backend = adminBackend();
      await pumpGoodPizza(tester, backend);
      await tester.tap(find.descendant(of: tableRow('Masa tradicional'), matching: find.byType(TextButton)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '150');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(backend.catalog.stockCalls.single, (id: 'd1', operation: 'SET', value: 150));
      expect(find.text('Stock actualizado'), findsOneWidget);
    });
  });

  group('S-08 ingrediente (formulario)', () {
    testWidgets('WT-19 IVA 15 % por defecto y 3 tamanos con su propio precio y calorias', (tester) async {
      await pumpGoodPizza(tester, adminBackend(), location: '/admin/ingredients/new');
      final vat = tester.widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>));
      expect(vat.selected, {'VAT_15'});
      expect(find.text('15 %'), findsOneWidget);
      expect(find.text('0 %'), findsOneWidget);
      for (final s in ['Individual', 'Mediana', 'Familiar']) {
        expect(field('Precio (USD) $s'), findsOneWidget);
        expect(field('Calorías (kcal) $s'), findsOneWidget);
      }
      expect(find.text('Cada tamaño tiene su propio precio y calorías.'), findsOneWidget);
      expect(find.textContaining(RegExp('eliminar', caseSensitive: false)), findsNothing);
    });

    testWidgets('WT-19 falta el valor de un tamano: error y no se envia', (tester) async {
      final backend = adminBackend();
      await pumpGoodPizza(tester, backend, location: '/admin/ingredients/new');
      await fillIngredientForm(tester, skipFamilyPrice: true);
      await save(tester);
      expect(find.text('Ingresa un precio.'), findsOneWidget);
      expect(backend.catalog.created, isEmpty);
    });

    testWidgets('WT-20 precio negativo rechazado; mas de 2 decimales rechazado', (tester) async {
      final backend = adminBackend();
      await pumpGoodPizza(tester, backend, location: '/admin/ingredients/new');
      await fillIngredientForm(tester, famPrice: '-1');
      await save(tester);
      expect(find.text('El precio no puede ser negativo.'), findsOneWidget);
      await tester.enterText(field('Precio (USD) Familiar'), '1.234');
      await save(tester);
      expect(find.text('Usa como máximo 2 decimales.'), findsOneWidget);
      expect(backend.catalog.created, isEmpty);
    });

    testWidgets('alta correcta: envia precios como string "1.50" y IVA 15 %', (tester) async {
      final backend = adminBackend();
      await pumpGoodPizza(tester, backend, location: '/admin/ingredients/new');
      await fillIngredientForm(tester);
      await save(tester);
      final json = backend.catalog.created.single.toCreateJson();
      expect(json['code'], 'TEST-1');
      expect(json['categoryCode'], 'CHEESE');
      expect(json['vatRateCode'], 'VAT_15');
      expect(json['stock'], 0);
      expect(json['active'], true);
      expect((json['sizeValues'] as List)[1], {'sizeCode': 'MEDIUM', 'price': '1.50', 'calories': 110});
      expect(find.text('Ingrediente guardado'), findsOneWidget);
      expect(find.text('Nuevo ingrediente'), findsOneWidget, reason: 'vuelve a la lista (boton "Nuevo ingrediente")');
    });

    testWidgets('errores del servidor: codigo duplicado, tamanos faltantes y categoria bloqueada', (tester) async {
      final backend = adminBackend();
      await pumpGoodPizza(tester, backend, location: '/admin/ingredients/new');
      await fillIngredientForm(tester);

      backend.catalog.createError = apiError('INGREDIENT_CODE_EXISTS', status: 409);
      await save(tester);
      expect(find.text('Ya existe un ingrediente con ese código.'), findsOneWidget);

      backend.catalog.createError = apiError('MISSING_SIZE_VALUES', status: 422, details: [
        {'missing': ['FAMILY']},
      ]);
      await save(tester);
      expect(find.text('Define precio y calorías para los tres tamaños.'), findsOneWidget);
      expect(find.text('Falta el valor de este tamaño.'), findsOneWidget);

      backend.catalog.createError = apiError('INGREDIENT_CATEGORY_LOCKED', status: 422, details: [
        {'presetPizzas': ['Margarita']},
      ]);
      await save(tester);
      expect(find.textContaining('el ingrediente se usa en las pizzas predefinidas: Margarita.'), findsOneWidget);
    });

    testWidgets('edicion: stock y estado se gestionan con sus propios controles (PUT no admite stock/active)',
        (tester) async {
      final backend = adminBackend();
      await pumpGoodPizza(tester, backend, location: '/admin/ingredients/d1');
      expect(find.text('Stock: 40'), findsOneWidget);
      expect(find.text('Ajustar stock'), findsOneWidget);
      expect(find.text('Estado: '), findsOneWidget);
      expect(find.textContaining('conservan sus valores'), findsOneWidget);
      expect(field('Stock inicial'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar ingrediente'));
      await tester.pumpAndSettle();
      final json = backend.catalog.updated.single.draft.toUpdateJson();
      expect(json.containsKey('stock'), isFalse);
      expect(json.containsKey('active'), isFalse);
    });

    testWidgets('salir con cambios sin guardar pide confirmacion', (tester) async {
      await pumpGoodPizza(tester, adminBackend(), location: '/admin/ingredients/new');
      await tester.enterText(field('Código'), 'ABC');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('¿Descartar los cambios?'), findsOneWidget);
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();
      expect(find.text('Guardar ingrediente'), findsOneWidget);
    });
  });

  group('S-09 / S-10 predefinidas (admin)', () {
    testWidgets('lista con precios calculados, disponibilidad y sin eliminar', (tester) async {
      final backend = adminBackend();
      await pumpGoodPizza(tester, backend, location: '/admin/presets');
      expect(backend.presets.includeInactiveCalls.every((v) => v), isTrue);
      expect(find.text('Margarita'), findsOneWidget);
      expect(find.text('Hawaiana'), findsOneWidget);
      expect(find.text('No disponible'), findsOneWidget);
      expect(find.text('La pizza Hawaiana no está disponible: falta Piña.'), findsOneWidget);
      expect(find.text('\$ 6.00 · 580'), findsOneWidget, reason: 'Margarita mediana: precio y kcal del motor');
      expect(find.textContaining(RegExp('eliminar', caseSensitive: false)), findsNothing);
      expect(find.text('Nueva pizza'), findsOneWidget);

      await tester.tap(find.descendant(of: tableRow('Margarita'), matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(find.textContaining('¿Desactivar Margarita?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
      await tester.pumpAndSettle();
      expect(backend.presets.statusCalls.single, (id: 'margherita', active: false));
    });

    testWidgets('WT-21 receta sin minimo de 3 ingredientes se acepta y no hay campo de precio', (tester) async {
      final backend = adminBackend();
      await pumpGoodPizza(tester, backend, location: '/admin/presets/new');

      // Sin campo de precio fijo
      expect(find.textContaining(RegExp('^Precio', caseSensitive: false)), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Precio'), findsNothing);
      expect(find.text('Las predefinidas pueden tener menos de 3 ingredientes.'), findsOneWidget);
      expect(find.text('Elige masa y salsa para ver la vista previa.'), findsOneWidget);

      await tester.enterText(field('Código'), 'solo_queso');
      await tester.enterText(field('Nombre'), 'Solo queso');
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Masa tradicional').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salsa de tomate').last);
      await tester.pumpAndSettle();
      await tester.tap(checkboxOf('Queso mozzarella'));
      await tester.pump();
      await tester.tap(plusOf('Queso mozzarella'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Vista previa calculada por el servidor (3 tamanos en UNA cotizacion con items CUSTOM)
      expect(backend.orders.quoteCalls.last.length, 3);
      expect(backend.orders.quoteCalls.last.every((i) => i.type == 'CUSTOM'), isTrue);
      expect(find.textContaining('Mediana \$ 6.00'), findsOneWidget, reason: '2.00 + 1.00 + 1.50 x2 = 6.00');
      expect(find.text('Elige al menos 3 ingredientes distintos.'), findsNothing, reason: 'MIN_TOPPINGS se ignora en la vista previa');

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar pizza'));
      await tester.pumpAndSettle();
      final json = backend.presets.created.single.toCreateJson();
      expect(json['code'], 'SOLO_QUESO');
      expect((json['recipe'] as List).length, 3, reason: 'masa + salsa + 1 ingrediente (sin minimo)');
      expect((json['recipe'] as List).last, {'ingredientId': 'c1', 'portions': 2});
      expect(json.containsKey('price'), isFalse);
      expect(find.text('Pizza guardada'), findsOneWidget);
    });

    testWidgets('receta sin masa o salsa se rechaza en la UI; errores del servidor por campo', (tester) async {
      final backend = adminBackend();
      await pumpGoodPizza(tester, backend, location: '/admin/presets/new');
      await tester.enterText(field('Código'), 'ABC');
      await tester.enterText(field('Nombre'), 'Prueba');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar pizza'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Elige una masa.'), findsOneWidget);
      expect(backend.presets.created, isEmpty);
    });

    testWidgets('edicion carga la receta y PRESET_NAME_EXISTS se muestra en Nombre', (tester) async {
      final backend = adminBackend();
      backend.presets.createError = apiError('PRESET_NAME_EXISTS', status: 409);
      await pumpGoodPizza(tester, backend, location: '/admin/presets/margherita');
      expect(isChecked(tester, 'Queso mozzarella'), isTrue);
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar pizza'));
      await tester.pumpAndSettle();
      expect(find.text('Ya existe una pizza con ese nombre.'), findsOneWidget);
    });

    testWidgets('INVALID_RECIPE lista las violaciones junto a la receta', (tester) async {
      final backend = adminBackend();
      backend.presets.createError = apiError('INVALID_RECIPE', status: 422, details: [
        {'code': 'MAX_PORTIONS_EXCEEDED', 'message': 'Máximo 3 porciones por ingrediente (Queso mozzarella: 4).'},
      ]);
      await pumpGoodPizza(tester, backend, location: '/admin/presets/margherita');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar pizza'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Máximo 3 porciones por ingrediente (Queso mozzarella: 4).'), findsOneWidget);
    });
  });

  group('S-11 / S-12 pedidos (admin)', () {
    testWidgets('lista de todos los pedidos con cliente y filtros', (tester) async {
      final backend = adminBackend();
      backend.orders.summaries = [
        summary('1', 'GP-20261106-0003', OrderStatus.pending, '25.44', pizzas: 3),
        summary('2', 'GP-20261106-0001', OrderStatus.inPreparation, '21.31', name: 'Luis Mora'),
      ];
      await pumpGoodPizza(tester, backend, location: '/admin/orders');
      expect(find.text('Cliente'), findsOneWidget);
      expect(find.text('Luis Mora'), findsOneWidget);
      expect(find.text('GP-20261106-0003'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Pendiente'));
      await tester.pumpAndSettle();
      expect(backend.orders.listCalls.last.status, OrderStatus.pending);
      expect(find.text('Luis Mora'), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'luis');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(backend.orders.listCalls.last.search, 'luis');
      expect(find.text('Limpiar filtros'), findsWidgets);
    });

    testWidgets('lista vacia', (tester) async {
      await pumpGoodPizza(tester, adminBackend(), location: '/admin/orders');
      expect(find.text('No hay pedidos todavía.'), findsOneWidget);
    });

    Future<FakeBackend> openOrder(WidgetTester tester, String status) async {
      final backend = adminBackend();
      final order = sampleOrder(backend, status: status);
      backend.orders.orders[order.id] = order;
      await pumpGoodPizza(tester, backend, location: '/admin/orders/${order.id}');
      return backend;
    }

    testWidgets('WT-22 Pendiente: boton "Pasar a En preparación" con confirmacion', (tester) async {
      final backend = await openOrder(tester, 'PENDING');
      expect(find.text('GESTIÓN DEL ESTADO'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Pasar a En preparación'), findsOneWidget);
      expect(find.text('Marcar como Entregado'), findsNothing);
      expect(find.text('RESUMEN'), findsOneWidget, reason: 'comprobante incrustado');

      await tester.tap(find.widgetWithText(FilledButton, 'Pasar a En preparación'));
      await tester.pumpAndSettle();
      expect(find.textContaining('¿Pasar el pedido GP-20261106-0001 a En preparación? Esta acción no se puede deshacer.'),
          findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
      await tester.pumpAndSettle();
      expect(backend.orders.statusCalls.single, (id: 'order-1', status: OrderStatus.inPreparation));
      expect(find.text('Estado actualizado: En preparación'), findsOneWidget);
      // ahora el siguiente paso es Entregado
      expect(find.widgetWithText(FilledButton, 'Marcar como Entregado'), findsOneWidget);
      expect(find.text('Historial'), findsOneWidget);
    });

    testWidgets('WT-22 En preparacion: "Marcar como Entregado"; Entregado: sin boton', (tester) async {
      await openOrder(tester, 'IN_PREPARATION');
      expect(find.widgetWithText(FilledButton, 'Marcar como Entregado'), findsOneWidget);
      expect(find.text('Pasar a En preparación'), findsNothing);
    });

    testWidgets('WT-22 Entregado sin accion: no admite mas cambios', (tester) async {
      await openOrder(tester, 'DELIVERED');
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('Este pedido ya fue entregado. No admite más cambios.'), findsOneWidget);
    });

    testWidgets('WT-22 INVALID_STATUS_TRANSITION muestra su mensaje y recarga', (tester) async {
      final backend = await openOrder(tester, 'PENDING');
      backend.orders.statusError = apiError('INVALID_STATUS_TRANSITION', status: 422);
      await tester.tap(find.widgetWithText(FilledButton, 'Pasar a En preparación'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
      await tester.pumpAndSettle();
      expect(find.text('El pedido ya cambió de estado'), findsOneWidget);
      expect(find.text('El pedido ya cambió de estado. Actualiza para ver el estado actual.'), findsOneWidget);
      final loads = backend.orders.getCalls.length;
      await tester.tap(find.widgetWithText(FilledButton, 'Actualizar'));
      await tester.pumpAndSettle();
      expect(backend.orders.getCalls.length, greaterThan(loads), reason: 'recarga el detalle');
    });

    testWidgets('pedido inexistente: "El pedido ya no está disponible."', (tester) async {
      await pumpGoodPizza(tester, adminBackend(), location: '/admin/orders/zzz');
      expect(find.text('El pedido ya no está disponible.'), findsOneWidget);
    });
  });
}
