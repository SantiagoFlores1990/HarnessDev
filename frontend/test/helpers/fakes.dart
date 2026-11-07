import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:good_pizza/core/api/api_exception.dart';
import 'package:good_pizza/features/auth/data/auth_repository.dart';
import 'package:good_pizza/features/auth/domain/auth_models.dart';
import 'package:good_pizza/core/storage/token_storage.dart';
import 'package:good_pizza/features/catalog/data/catalog_repository.dart';
import 'package:good_pizza/features/catalog/domain/catalog_models.dart';
import 'package:good_pizza/features/orders/data/orders_repository.dart';
import 'package:good_pizza/features/orders/domain/order_models.dart';
import 'package:good_pizza/features/preset_pizzas/data/preset_repository.dart';
import 'package:good_pizza/features/preset_pizzas/domain/preset_models.dart';

import 'fixtures.dart' as fx;

int _cents(String amount) {
  final parts = amount.split('.');
  final whole = int.parse(parts[0]);
  final frac = parts.length > 1 ? int.parse(parts[1].padRight(2, '0').substring(0, 2)) : 0;
  return whole * 100 + frac;
}

String _money(int cents) => '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

/// Doble de prueba del motor del servidor (ADR-002): NO es codigo de la app. Permite que
/// los repositorios falsos devuelvan cotizaciones coherentes sin duplicar reglas en Dart de produccion.
class FakeServer {
  FakeServer({List<Ingredient>? ingredients, List<PresetPizza>? presets})
      : ingredients = ingredients ?? [...fx.catalog],
        presets = presets ?? defaultPresets();

  List<Ingredient> ingredients;
  List<PresetPizza> presets;

  static List<PresetPizza> defaultPresets() => [
        fx.preset('margherita', 'Margarita',
            [fx.recipeOf(fx.dough1, 1), fx.recipeOf(fx.sauce1, 1), fx.recipeOf(fx.mozzarella, 2)]),
        fx.preset('pepperoni', 'Pepperoni',
            [fx.recipeOf(fx.dough1, 1), fx.recipeOf(fx.sauce1, 1), fx.recipeOf(fx.pepperoni, 3)], sortOrder: 2),
        fx.preset(
          'hawaiian',
          'Hawaiana',
          [fx.recipeOf(fx.dough1, 1), fx.recipeOf(fx.sauce1, 1), fx.recipeOf(fx.ham, 1), fx.recipeOf(fx.pineapple, 1)],
          available: false,
          sortOrder: 3,
          reasons: const [
            Violation(
                code: 'PRESET_UNAVAILABLE', message: 'La pizza Hawaiana no está disponible: falta Piña.'),
          ],
        ),
        fx.preset('veggie', 'Vegetariana',
            [fx.recipeOf(fx.dough2, 1), fx.recipeOf(fx.sauce1, 1), fx.recipeOf(fx.mushrooms, 1)], sortOrder: 4),
        fx.preset('quattro', '4 Quesos',
            [fx.recipeOf(fx.dough1, 1), fx.recipeOf(fx.sauce2, 1), fx.recipeOf(fx.mozzarella, 2), fx.recipeOf(fx.cheddar, 1)],
            sortOrder: 5),
      ];

  Ingredient? _find(String? id) {
    for (final i in ingredients) {
      if (i.id == id && i.active) return i;
    }
    return null;
  }

  Map<String, dynamic> _component(Ingredient i, String size, String kind, int portions, int recipe) {
    final v = i.valueFor(size)!;
    return {
      'ingredientId': i.id,
      'code': i.code,
      'name': i.name,
      'component': kind,
      'categoryCode': i.categoryCode,
      'recipePortions': recipe,
      'portions': portions,
      'unitPrice': v.price,
      'unitCalories': v.calories,
      'vatRatePercent': i.vatRatePercent,
      'lineAmount': _money(_cents(v.price) * portions),
      'lineCalories': v.calories * portions,
    };
  }

  Map<String, dynamic> _violation(String code, String message, int index, {String? ingredientId}) =>
      {'code': code, 'message': message, 'itemIndex': index, 'ingredientId': ingredientId, 'meta': {}};

  /// Cotizacion con la forma del contrato (`data` de `POST /orders/quote`).
  Map<String, dynamic> quoteJson(List<PizzaItemInput> inputs) {
    final items = <Map<String, dynamic>>[];
    final required = <String, int>{};
    var sub15 = 0;
    var sub0 = 0;
    var kcal = 0;
    var allValid = true;

    for (var idx = 0; idx < inputs.length; idx++) {
      final input = inputs[idx];
      final size = input.sizeCode;
      final comps = <Map<String, dynamic>>[];
      final violations = <Map<String, dynamic>>[];
      Map<String, dynamic>? presetRef;

      void addComponent(Ingredient i, String kind, int portions, int recipe) {
        comps.add(_component(i, size, kind, portions, recipe));
        required[i.id] = (required[i.id] ?? 0) + portions * input.quantity;
      }

      if (input.isPreset) {
        final p = presets.firstWhere((e) => e.id == input.presetPizzaId);
        presetRef = {'id': p.id, 'code': p.code, 'name': p.name};
        final extras = {for (final e in input.extras) e.ingredientId: e.portions};
        for (final r in p.recipe) {
          final ing = _find(r.ingredientId);
          if (ing == null) continue;
          final kind = ing.isDough ? 'DOUGH' : (ing.isSauce ? 'SAUCE' : 'TOPPING');
          final total = r.portions + (extras.remove(r.ingredientId) ?? 0);
          addComponent(ing, kind, total, r.portions);
        }
        extras.forEach((id, n) {
          final ing = _find(id);
          if (ing != null) addComponent(ing, 'TOPPING', n, 0);
        });
      } else {
        final dough = _find(input.doughId);
        final sauce = _find(input.sauceId);
        if (dough == null) violations.add(_violation('DOUGH_REQUIRED', 'Elige una masa.', idx));
        if (sauce == null) violations.add(_violation('SAUCE_REQUIRED', 'Elige una salsa base.', idx));
        if (dough != null) addComponent(dough, 'DOUGH', 1, 0);
        if (sauce != null) addComponent(sauce, 'SAUCE', 1, 0);
        for (final t in input.toppings) {
          final ing = _find(t.ingredientId);
          if (ing != null) addComponent(ing, 'TOPPING', t.portions, 0);
        }
        if (input.toppings.length < 3) {
          violations.add({
            'code': 'MIN_TOPPINGS_NOT_MET',
            'message': 'Elige al menos 3 ingredientes distintos.',
            'itemIndex': idx,
            'ingredientId': null,
            'meta': {'min': 3, 'current': input.toppings.length},
          });
        }
      }
      for (final c in comps) {
        if (c['component'] == 'TOPPING' && (c['portions'] as int) > 3) {
          violations.add(_violation('MAX_PORTIONS_EXCEEDED',
              'Máximo 3 porciones por ingrediente (${c['name']}: ${c['portions']}).', idx,
              ingredientId: c['ingredientId'] as String));
        }
      }

      var unit = 0;
      var unitKcal = 0;
      var u15 = 0;
      var u0 = 0;
      for (final c in comps) {
        final amount = _cents(c['lineAmount'] as String);
        unit += amount;
        unitKcal += c['lineCalories'] as int;
        if (c['vatRatePercent'] == '15.00') {
          u15 += amount;
        } else {
          u0 += amount;
        }
      }
      sub15 += u15 * input.quantity;
      sub0 += u0 * input.quantity;
      kcal += unitKcal * input.quantity;
      if (violations.isNotEmpty) allValid = false;
      items.add({
        'index': idx,
        'type': input.type,
        'presetPizza': presetRef,
        'size': {'code': size, 'name': fx.sizes.firstWhere((s) => s.code == size).name},
        'quantity': input.quantity,
        'components': comps,
        'unitPrice': _money(unit),
        'unitCalories': unitKcal,
        'unitSubtotalVat15': _money(u15),
        'unitSubtotalVat0': _money(u0),
        'lineSubtotal': _money(unit * input.quantity),
        'lineCalories': unitKcal * input.quantity,
        'valid': violations.isEmpty,
        'violations': violations,
      });
    }

    final rootViolations = <Map<String, dynamic>>[];
    final stock = <Map<String, dynamic>>[];
    required.forEach((id, need) {
      final ing = ingredients.firstWhere((i) => i.id == id);
      stock.add({'ingredientId': id, 'name': ing.name, 'required': need, 'available': ing.stock});
      if (need > ing.stock) {
        allValid = false;
        rootViolations.add({
          'code': 'INSUFFICIENT_STOCK',
          'message': 'No hay stock suficiente de ${ing.name}: solicitado $need, disponible ${ing.stock}.',
          'itemIndex': null,
          'ingredientId': id,
          'meta': {},
        });
      }
    });

    final vat15 = (sub15 * 15 + 50) ~/ 100; // redondeo half-up
    return {
      'valid': allValid,
      'violations': rootViolations,
      'items': items,
      'totals': {
        'subtotalVat15': _money(sub15),
        'subtotalVat0': _money(sub0),
        'vat15': _money(vat15),
        'total': _money(sub15 + sub0 + vat15),
        'totalCalories': kcal,
      },
      'stock': stock,
    };
  }

  /// Predefinidas con `pricesBySize` calculado por el "motor".
  List<PresetPizza> presetsWithPrices() => presets.map((p) {
        final prices = <SizePrice>[];
        for (final s in fx.sizes) {
          final q = QuoteResult.fromJson(quoteJson([
            PizzaItemInput(type: PizzaTypes.preset, presetPizzaId: p.id, sizeCode: s.code),
          ]));
          prices.add(SizePrice(sizeCode: s.code, price: q.items.first.unitPrice, calories: q.items.first.unitCalories));
        }
        return PresetPizza(
          id: p.id,
          code: p.code,
          name: p.name,
          description: p.description,
          active: p.active,
          sortOrder: p.sortOrder,
          recipe: p.recipe,
          pricesBySize: prices,
          available: p.available,
          unavailableReasons: p.unavailableReasons,
        );
      }).toList();

  /// Comprobante (`OrderDetail`) construido desde una cotizacion.
  Map<String, dynamic> orderJson(List<PizzaItemInput> inputs,
      {String id = 'order-1',
      String number = 'GP-20261106-0001',
      String status = 'PENDING',
      String customerName = 'Ana Pérez'}) {
    final quote = quoteJson(inputs);
    final pizzas = (quote['items'] as List).map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      m['lineNumber'] = (m.remove('index') as int) + 1;
      m.remove('valid');
      m.remove('violations');
      return m;
    }).toList();
    final totals = quote['totals'] as Map<String, dynamic>;
    return {
      'id': id,
      'orderNumber': number,
      'orderDate': '2026-11-06',
      'createdAt': '2026-11-06T15:04:05.123Z',
      'status': status,
      'customer': {'id': 'u-1', 'fullName': customerName, 'email': 'ana@ejemplo.com'},
      'pizzaCount': inputs.fold<int>(0, (s, i) => s + i.quantity),
      'totalCalories': totals['totalCalories'],
      'total': totals['total'],
      'statusChangedAt': '2026-11-06T15:04:05.123Z',
      'pizzas': pizzas,
      'totals': totals,
      'statusHistory': [
        {
          'fromStatus': null,
          'toStatus': status,
          'changedAt': '2026-11-06T15:04:05.123Z',
          'changedBy': {'id': 'u-1', 'fullName': customerName},
        },
      ],
    };
  }
}

/// Repositorio de pedidos falso.
class FakeOrdersRepository implements OrdersRepository {
  FakeOrdersRepository(this.server);
  final FakeServer server;

  final List<List<PizzaItemInput>> quoteCalls = [];
  final List<({List<PizzaItemInput> items, String? expectedTotal})> createCalls = [];
  final List<OrdersQuery> listCalls = [];
  final List<String> getCalls = [];
  final List<({String id, OrderStatus status})> statusCalls = [];
  Duration quoteDelay = Duration.zero;
  Object? quoteError;
  final Queue<Object> createErrors = Queue();
  final Map<String, OrderDetail> orders = {};
  List<OrderSummary> summaries = [];
  Object? listError;
  Object? getError;
  Object? statusError;
  int cancelledQuotes = 0;
  bool enforceExpectedTotal = true;
  Map<String, dynamic> Function(Map<String, dynamic> engineQuote)? quoteTransform;

  @override
  Future<QuoteResult> quote(List<PizzaItemInput> items, {CancelToken? cancelToken}) async {
    quoteCalls.add(items);
    if (quoteDelay > Duration.zero) {
      await Future<void>.delayed(quoteDelay);
    } else {
      await Future<void>.value();
    }
    if (cancelToken?.isCancelled ?? false) {
      cancelledQuotes++;
      throw const ApiException(code: ErrorCodes.cancelled);
    }
    if (quoteError != null) throw quoteError!;
    final json = server.quoteJson(items);
    return QuoteResult.fromJson(quoteTransform?.call(json) ?? json);
  }

  @override
  Future<OrderDetail> create(List<PizzaItemInput> items, {String? expectedTotal}) async {
    createCalls.add((items: items, expectedTotal: expectedTotal));
    await Future<void>.value();
    if (createErrors.isNotEmpty) throw createErrors.removeFirst();
    final quote = server.quoteJson(items);
    if (enforceExpectedTotal && expectedTotal != null && (quote['totals'] as Map)['total'] != expectedTotal) {
      throw ApiException(code: ErrorCodes.priceChanged, statusCode: 409, details: [
        {'quote': {'items': quote['items'], 'totals': quote['totals']}},
      ]);
    }
    final order = OrderDetail.fromJson(server.orderJson(items));
    orders[order.id] = order;
    return order;
  }

  @override
  Future<PageResult<OrderSummary>> list(OrdersQuery query) async {
    listCalls.add(query);
    await Future<void>.value();
    if (listError != null) throw listError!;
    final filtered = summaries.where((o) => query.status == null || o.status == query.status).toList();
    return PageResult(items: filtered, page: query.page, pageSize: query.pageSize, total: filtered.length);
  }

  @override
  Future<OrderDetail> get(String id) async {
    getCalls.add(id);
    await Future<void>.value();
    if (getError != null) throw getError!;
    final order = orders[id];
    if (order == null) throw const ApiException(code: ErrorCodes.notFound, statusCode: 404);
    return order;
  }

  @override
  Future<OrderDetail> updateStatus(String id, OrderStatus status) async {
    statusCalls.add((id: id, status: status));
    await Future<void>.value();
    if (statusError != null) throw statusError!;
    final old = orders[id]!;
    final json = server.orderJson(const [], id: id, number: old.orderNumber, status: status.apiValue);
    final updated = OrderDetail(
      summary: OrderSummary(
        id: old.id,
        orderNumber: old.orderNumber,
        createdAt: old.createdAt,
        status: status,
        customer: old.customer,
        pizzaCount: old.summary.pizzaCount,
        totalCalories: old.summary.totalCalories,
        total: old.summary.total,
      ),
      statusChangedAt: DateTime.parse('2026-11-06T16:00:00.000Z'),
      pizzas: old.pizzas,
      totals: old.totals,
      statusHistory: [
        ...old.statusHistory,
        StatusHistoryEntry(
            fromStatus: old.status,
            toStatus: status,
            changedAt: DateTime.parse('2026-11-06T16:00:00.000Z'),
            changedByName: 'Admin'),
      ],
    );
    assert(json.isNotEmpty);
    orders[id] = updated;
    return updated;
  }
}

/// Repositorio de catalogo falso.
class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository(this.server);
  final FakeServer server;

  final List<bool> includeInactiveCalls = [];
  final List<IngredientDraft> created = [];
  final List<({String id, IngredientDraft draft})> updated = [];
  final List<({String id, String operation, int value})> stockCalls = [];
  final List<({String id, bool active})> statusCalls = [];
  Object? ingredientsError;
  Object? createError;
  Object? stockError;
  Object? statusError;

  @override
  Future<List<SizeOption>> sizes() async => fx.sizes;
  @override
  Future<List<IngredientCategory>> categories() async => fx.categories;
  @override
  Future<List<VatRate>> vatRates() async => fx.vatRates;

  @override
  Future<List<Ingredient>> ingredients({String? category, String? search, bool includeInactive = false}) async {
    includeInactiveCalls.add(includeInactive);
    if (ingredientsError != null) throw ingredientsError!;
    return server.ingredients
        .where((i) => (includeInactive || i.active) && (category == null || i.categoryCode == category))
        .where((i) => search == null || search.isEmpty || i.name.toLowerCase().contains(search.toLowerCase()))
        .toList();
  }

  @override
  Future<Ingredient> ingredient(String id) async => server.ingredients.firstWhere((i) => i.id == id);

  @override
  Future<Ingredient> createIngredient(IngredientDraft draft) async {
    created.add(draft);
    if (createError != null) throw createError!;
    return server.ingredients.first;
  }

  @override
  Future<Ingredient> updateIngredient(String id, IngredientDraft draft) async {
    updated.add((id: id, draft: draft));
    if (createError != null) throw createError!;
    return server.ingredients.first;
  }

  @override
  Future<Ingredient> adjustStock(String id, {required String operation, required int value}) async {
    stockCalls.add((id: id, operation: operation, value: value));
    if (stockError != null) throw stockError!;
    return server.ingredients.firstWhere((i) => i.id == id);
  }

  @override
  Future<Ingredient> setIngredientActive(String id, bool active) async {
    statusCalls.add((id: id, active: active));
    if (statusError != null) throw statusError!;
    return server.ingredients.firstWhere((i) => i.id == id);
  }
}

/// Repositorio de predefinidas falso.
class FakePresetRepository implements PresetRepository {
  FakePresetRepository(this.server);
  final FakeServer server;

  final List<bool> includeInactiveCalls = [];
  final List<PresetDraft> created = [];
  final List<({String id, bool active})> statusCalls = [];
  Object? listError;
  Object? createError;
  int listCalls = 0;

  @override
  Future<List<PresetPizza>> list({bool includeInactive = false}) async {
    listCalls++;
    includeInactiveCalls.add(includeInactive);
    if (listError != null) throw listError!;
    return server.presetsWithPrices().where((p) => includeInactive || p.active).toList();
  }

  @override
  Future<PresetPizza> get(String id) async {
    final all = server.presetsWithPrices();
    final found = all.where((p) => p.id == id);
    if (found.isEmpty) throw const ApiException(code: ErrorCodes.notFound, statusCode: 404);
    return found.first;
  }

  @override
  Future<PresetPizza> create(PresetDraft draft) async {
    created.add(draft);
    if (createError != null) throw createError!;
    return server.presetsWithPrices().first;
  }

  @override
  Future<PresetPizza> update(String id, PresetDraft draft) async {
    created.add(draft);
    if (createError != null) throw createError!;
    return server.presetsWithPrices().first;
  }

  @override
  Future<PresetPizza> setActive(String id, bool active) async {
    statusCalls.add((id: id, active: active));
    return server.presetsWithPrices().first;
  }
}

/// Repositorio de autenticacion falso.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? user}) : user = user ?? clientUser;

  static const clientUser =
      AppUser(id: 'u-1', fullName: 'Ana Pérez', email: 'ana@ejemplo.com', role: UserRole.client);
  static const adminUser =
      AppUser(id: 'u-0', fullName: 'Admin Local', email: 'admin@goodpizza.local', role: UserRole.admin);

  AppUser user;
  Object? loginError;
  Object? registerError;
  Object? meError;
  final List<({String email, String password})> loginCalls = [];
  final List<({String fullName, String email, String password})> registerCalls = [];
  int logoutCalls = 0;

  @override
  Future<AuthResult> login({required String email, required String password}) async {
    loginCalls.add((email: email, password: password));
    if (loginError != null) throw loginError!;
    return AuthResult(user: user, tokens: const Tokens(accessToken: 'access-1', refreshToken: 'refresh-1'));
  }

  @override
  Future<AuthResult> register({required String fullName, required String email, required String password}) async {
    registerCalls.add((fullName: fullName, email: email, password: password));
    if (registerError != null) throw registerError!;
    return AuthResult(
      user: AppUser(id: 'u-9', fullName: fullName, email: email, role: UserRole.client),
      tokens: const Tokens(accessToken: 'access-2', refreshToken: 'refresh-2'),
    );
  }

  @override
  Future<AppUser> me() async {
    if (meError != null) throw meError!;
    return user;
  }

  @override
  Future<void> logout(String refreshToken) async => logoutCalls++;
}

/// Conjunto de repositorios falsos que comparten el mismo "servidor".
class FakeBackend {
  FakeBackend({AppUser? user, FakeServer? server})
      : server = server ?? FakeServer(),
        auth = FakeAuthRepository(user: user) {
    orders = FakeOrdersRepository(this.server);
    catalog = FakeCatalogRepository(this.server);
    presets = FakePresetRepository(this.server);
  }

  final FakeServer server;
  final FakeAuthRepository auth;
  late final FakeOrdersRepository orders;
  late final FakeCatalogRepository catalog;
  late final FakePresetRepository presets;
}

/// Atajo para crear una excepcion de API en pruebas.
ApiException apiError(String code, {int status = 400, String? message, List<dynamic> details = const []}) =>
    ApiException(code: code, statusCode: status, serverMessage: message, details: details);

