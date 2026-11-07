import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:good_pizza/features/catalog/data/catalog_repository.dart';
import 'package:good_pizza/features/orders/data/orders_repository.dart';
import 'package:good_pizza/features/orders/domain/component_text.dart';
import 'package:good_pizza/features/orders/domain/order_models.dart';
import 'package:good_pizza/features/pizza_builder/presentation/builder_controller.dart';
import 'package:good_pizza/features/preset_pizzas/data/preset_repository.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart' as fx;

ProviderContainer makeContainer(FakeBackend backend) {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      ordersRepositoryProvider.overrideWithValue(backend.orders),
      catalogRepositoryProvider.overrideWithValue(backend.catalog),
      presetRepositoryProvider.overrideWithValue(backend.presets),
      quoteDebounceProvider.overrideWithValue(const Duration(milliseconds: 20)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('PizzaBuilderController (ProviderContainer con repositorio falso)', () {
    test('init desde cero: sin seleccion y cotiza una vez', () async {
      final backend = FakeBackend();
      final c = makeContainer(backend);
      final sub = c.listen(pizzaBuilderProvider, (_, _) {});
      addTearDown(sub.close);
      c.read(pizzaBuilderProvider.notifier).init(sizeCode: 'FAMILY');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final s = c.read(pizzaBuilderProvider);
      expect(s.sizeCode, 'FAMILY');
      expect(s.portions, isEmpty);
      expect(s.quoting, isFalse);
      expect(s.canAdd, isFalse, reason: 'faltan masa, salsa y 3 ingredientes');
      expect(backend.orders.quoteCalls.length, 1);
    });

    test('masa y salsa son exclusivas; los ingredientes se limitan a 1..3 porciones', () async {
      final c = makeContainer(FakeBackend());
      final sub = c.listen(pizzaBuilderProvider, (_, _) {});
      addTearDown(sub.close);
      final ctl = c.read(pizzaBuilderProvider.notifier)..init();
      ctl.selectDough('d1');
      ctl.selectDough('d2');
      expect(c.read(pizzaBuilderProvider).doughId, 'd2');
      ctl.toggleTopping('c1');
      expect(c.read(pizzaBuilderProvider).portionsOf('c1'), 1);
      ctl.setPortions('c1', 9);
      expect(c.read(pizzaBuilderProvider).portionsOf('c1'), 3);
      ctl.setPortions('c1', 0);
      expect(c.read(pizzaBuilderProvider).portionsOf('c1'), 1);
      ctl.toggleTopping('c1');
      expect(c.read(pizzaBuilderProvider).portions, isEmpty);
      ctl.setQuantity(99);
      expect(c.read(pizzaBuilderProvider).quantity, 20);
      ctl.setQuantity(-3);
      expect(c.read(pizzaBuilderProvider).quantity, 1);
    });

    test('payload CUSTOM: doughId, sauceId y toppings con porciones', () {
      final c = makeContainer(FakeBackend());
      final sub = c.listen(pizzaBuilderProvider, (_, _) {});
      addTearDown(sub.close);
      final ctl = c.read(pizzaBuilderProvider.notifier)..init(sizeCode: 'INDIVIDUAL');
      ctl
        ..selectDough('d1')
        ..selectSauce('s1')
        ..toggleTopping('c1')
        ..setPortions('c1', 3);
      final json = c.read(pizzaBuilderProvider).toInput().toJson();
      expect(json, {
        'type': 'CUSTOM',
        'sizeCode': 'INDIVIDUAL',
        'doughId': 'd1',
        'sauceId': 's1',
        'toppings': [
          {'ingredientId': 'c1', 'portions': 3},
        ],
        'quantity': 1,
      });
    });

    test('payload PRESET: solo extras = porciones - receta (> 0); masa y salsa no se envian', () {
      final backend = FakeBackend();
      final c = makeContainer(backend);
      final sub = c.listen(pizzaBuilderProvider, (_, _) {});
      addTearDown(sub.close);
      final margherita = backend.server.presets.first; // mozzarella x2
      final ctl = c.read(pizzaBuilderProvider.notifier)..init(preset: margherita);
      expect(c.read(pizzaBuilderProvider).toInput().extras, isEmpty);

      ctl.toggleTopping('c1'); // ingrediente de receta: no se puede quitar
      expect(c.read(pizzaBuilderProvider).portionsOf('c1'), 2);
      ctl.setPortions('c1', 1); // por debajo de la receta: se corrige a 2
      expect(c.read(pizzaBuilderProvider).portionsOf('c1'), 2);
      ctl.setPortions('c1', 3);
      ctl.toggleTopping('m1');
      final json = c.read(pizzaBuilderProvider).toInput().toJson();
      expect(json['type'], 'PRESET');
      expect(json['presetPizzaId'], 'margherita');
      expect(json.containsKey('doughId'), isFalse);
      expect(json.containsKey('sauceId'), isFalse);
      expect(json.containsKey('toppings'), isFalse);
      expect(
        (json['extras'] as List).map((e) => '${(e as Map)['ingredientId']}:${e['portions']}').toSet(),
        {'c1:1', 'm1:1'},
      );
      // en modo predefinida no se puede cambiar masa ni salsa
      ctl.selectDough('d2');
      expect(c.read(pizzaBuilderProvider).doughId, 'd1');
    });

    test('solo se aplica la ultima respuesta (la anterior se cancela)', () async {
      final backend = FakeBackend();
      backend.orders.quoteDelay = const Duration(milliseconds: 60);
      final c = makeContainer(backend);
      final sub = c.listen(pizzaBuilderProvider, (_, _) {});
      addTearDown(sub.close);
      final ctl = c.read(pizzaBuilderProvider.notifier)..init();
      await Future<void>.delayed(const Duration(milliseconds: 40)); // 1a peticion en vuelo
      ctl.selectDough('d1');
      await Future<void>.delayed(const Duration(milliseconds: 40)); // 2a peticion en vuelo, cancela la 1a
      ctl.selectSauce('s1');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final s = c.read(pizzaBuilderProvider);
      expect(s.quoting, isFalse);
      expect(s.quote!.items.single.components.map((x) => x.component), containsAll(['DOUGH', 'SAUCE']));
      expect(backend.orders.cancelledQuotes, greaterThanOrEqualTo(1));
    });

    test('error de cotizacion se conserva y retryQuote lo resuelve', () async {
      final backend = FakeBackend();
      backend.orders.quoteError = apiError('INTERNAL_ERROR', status: 500);
      final c = makeContainer(backend);
      final sub = c.listen(pizzaBuilderProvider, (_, _) {});
      addTearDown(sub.close);
      final ctl = c.read(pizzaBuilderProvider.notifier)..init();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(c.read(pizzaBuilderProvider).quoteError?.code, 'INTERNAL_ERROR');
      expect(c.read(pizzaBuilderProvider).canAdd, isFalse);
      backend.orders.quoteError = null;
      ctl.retryQuote();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(c.read(pizzaBuilderProvider).quoteError, isNull);
      expect(c.read(pizzaBuilderProvider).quote, isNotNull);
    });
  });

  group('modelos (parseo del contrato)', () {
    test('QuoteResult/PricedPizza/Totals desde JSON del contrato', () {
      final json = FakeServer().quoteJson(const [
        PizzaItemInput(
          type: 'CUSTOM',
          sizeCode: 'MEDIUM',
          doughId: 'd1',
          sauceId: 's1',
          toppings: [PortionInput(ingredientId: 'c1', portions: 3)],
        ),
      ]);
      final q = QuoteResult.fromJson(json);
      expect(q.items.single.unitPrice, '7.50');
      expect(q.items.single.unitCalories, 690);
      expect(q.totals.total, isNotEmpty);
      expect(q.valid, isFalse, reason: 'faltan ingredientes distintos');
      expect(q.allViolations.single.code, 'MIN_TOPPINGS_NOT_MET');
      expect(q.allViolations.single.meta['min'], 3);
    });

    test('OrderDetail desde JSON: lineNumber -> index base 0, statusHistory, snapshots', () {
      final order = OrderDetail.fromJson(FakeServer().orderJson(const [
        PizzaItemInput(type: 'PRESET', presetPizzaId: 'margherita', sizeCode: 'MEDIUM', quantity: 2),
      ]));
      expect(order.orderNumber, 'GP-20261106-0001');
      expect(order.status, OrderStatus.pending);
      expect(order.pizzas.single.index, 0);
      expect(order.pizzas.single.presetPizza?.name, 'Margarita');
      expect(order.pizzas.single.kindLabel, 'Margarita (predefinida)');
      expect(order.statusHistory.single.fromStatus, isNull);
      expect(order.createdAt.isUtc, isTrue);
    });

    test('estados: Pendiente -> En preparacion -> Entregado', () {
      expect(OrderStatus.pending.next, OrderStatus.inPreparation);
      expect(OrderStatus.inPreparation.next, OrderStatus.delivered);
      expect(OrderStatus.delivered.next, isNull);
      expect(OrderStatus.fromApi('IN_PREPARATION').label, 'En preparación');
    });

    test('Ingredient.fromJson y valores por tamano', () {
      final i = fx.mozzarella;
      expect(i.valueFor('MEDIUM')!.price, '1.50');
      expect(i.valueFor('NOPE'), isNull);
      final parsed = i.sizeValues.first.toJson();
      expect(parsed['sizeCode'], 'INDIVIDUAL');
    });

    test('texto de componentes con extras de predefinida', () {
      PricedComponent comp(int recipe, int portions) => PricedComponent(
            ingredientId: 'x',
            code: 'X',
            name: 'Jamón',
            component: 'TOPPING',
            categoryCode: 'MEAT',
            recipePortions: recipe,
            portions: portions,
            unitPrice: '1.00',
            unitCalories: 10,
            vatRatePercent: '15.00',
            lineAmount: '1.00',
            lineCalories: 10,
          );
      expect(componentSummary(comp(0, 1), preset: true), 'Jamón x1 (extra)');
      expect(componentSummary(comp(2, 3), preset: true), 'Jamón x3 (2 receta + 1 extra)');
      expect(componentSummary(comp(2, 2), preset: true), 'Jamón x2');
      expect(componentSummary(comp(0, 1)), 'Jamón x1', reason: 'en personalizadas no hay extras');
    });
  });
}
