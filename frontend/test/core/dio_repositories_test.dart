import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:good_pizza/core/api/api_exception.dart';
import 'package:good_pizza/features/auth/data/auth_repository.dart';
import 'package:good_pizza/features/catalog/data/catalog_repository.dart';
import 'package:good_pizza/features/catalog/domain/catalog_models.dart';
import 'package:good_pizza/features/orders/data/orders_repository.dart';
import 'package:good_pizza/features/orders/domain/order_models.dart';
import 'package:good_pizza/features/preset_pizzas/data/preset_repository.dart';
import 'package:good_pizza/features/preset_pizzas/domain/preset_models.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart' as fx;

/// Adaptador HTTP falso que registra metodo, ruta, query, cuerpo y cabeceras de cada peticion.
class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter(this.respond);
  final ({int status, Object body}) Function(RequestOptions o) respond;
  final List<RequestOptions> calls = [];

  RequestOptions get last => calls.last;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls.add(options);
    final r = respond(options);
    if (r.status == 204) return ResponseBody.fromString('', 204);
    return ResponseBody.fromString(jsonEncode(r.body), r.status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Dio dioWith(RecordingAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'http://api.test/api/v1'))..httpClientAdapter = adapter;

Map<String, dynamic> ingredientJson(Ingredient i) => {
      'id': i.id,
      'code': i.code,
      'name': i.name,
      'category': {'code': i.categoryCode, 'name': i.categoryName},
      'vatRate': {'code': i.vatRateCode, 'ratePercent': i.vatRatePercent},
      'active': i.active,
      'stock': i.stock,
      'sizeValues': [for (final v in i.sizeValues) v.toJson()],
    };

void main() {
  group('DioAuthRepository', () {
    test('login/register/logout no llevan token (skipAuth) y parsean usuario y tokens', () async {
      final adapter = RecordingAdapter((o) {
        if (o.path == '/auth/logout') return (status: 204, body: '');
        return (
          status: o.path == '/auth/register' ? 201 : 200,
          body: {
            'data': {
              'user': {'id': 'u1', 'fullName': 'Ana Pérez', 'email': 'ana@ejemplo.com', 'role': 'CLIENT'},
              'accessToken': 'a',
              'accessTokenExpiresIn': 900,
              'refreshToken': 'r',
              'refreshTokenExpiresIn': 604800,
            },
          },
        );
      });
      final repo = DioAuthRepository(dioWith(adapter));
      final login = await repo.login(email: 'ana@ejemplo.com', password: 'secreto123');
      expect(adapter.last.method, 'POST');
      expect(adapter.last.path, '/auth/login');
      expect(adapter.last.data, {'email': 'ana@ejemplo.com', 'password': 'secreto123'});
      expect(adapter.last.extra['skipAuth'], isTrue);
      expect(login.user.fullName, 'Ana Pérez');
      expect(login.tokens.refreshToken, 'r');

      final reg = await repo.register(fullName: 'Ana Pérez', email: 'ana@ejemplo.com', password: 'secreto123');
      expect(adapter.last.path, '/auth/register');
      expect(adapter.last.data, {'fullName': 'Ana Pérez', 'email': 'ana@ejemplo.com', 'password': 'secreto123'},
          reason: 'sin campo role');
      expect(reg.user.role.apiValue, 'CLIENT');

      await repo.logout('r');
      expect(adapter.last.path, '/auth/logout');
      expect(adapter.last.data, {'refreshToken': 'r'});
    });

    test('me() usa GET /auth/me y errores se convierten en ApiException', () async {
      var fail = false;
      final adapter = RecordingAdapter((o) => fail
          ? (status: 401, body: {'error': {'code': 'INVALID_CREDENTIALS', 'message': 'x', 'details': []}})
          : (status: 200, body: {'data': {'id': 'u0', 'fullName': 'Admin', 'email': 'a@b.c', 'role': 'ADMIN'}}));
      final repo = DioAuthRepository(dioWith(adapter));
      expect((await repo.me()).isAdmin, isTrue);
      expect(adapter.last.path, '/auth/me');
      fail = true;
      await expectLater(
        repo.login(email: 'a@b.c', password: 'x'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INVALID_CREDENTIALS')),
      );
    });
  });

  group('DioCatalogRepository', () {
    test('catalogos: /sizes, /ingredient-categories, /vat-rates', () async {
      final adapter = RecordingAdapter((o) {
        switch (o.path) {
          case '/sizes':
            return (status: 200, body: {'data': [{'code': 'MEDIUM', 'name': 'Mediana', 'sortOrder': 2}]});
          case '/ingredient-categories':
            return (status: 200, body: {'data': [{'code': 'DOUGH', 'name': 'Masa', 'sortOrder': 1}]});
          default:
            return (status: 200, body: {'data': [{'code': 'VAT_15', 'name': 'IVA 15 %', 'ratePercent': '15.00', 'isDefault': true}]});
        }
      });
      final repo = DioCatalogRepository(dioWith(adapter));
      expect((await repo.sizes()).single.name, 'Mediana');
      expect((await repo.categories()).single.code, 'DOUGH');
      final vat = (await repo.vatRates()).single;
      expect(vat.isDefault, isTrue);
      expect(vat.ratePercent, '15.00');
    });

    test('GET /ingredients: includeInactive solo se envia cuando es true; sin page (lista completa)', () async {
      final adapter = RecordingAdapter((o) => (status: 200, body: {'data': [ingredientJson(fx.mozzarella)]}));
      final repo = DioCatalogRepository(dioWith(adapter));
      await repo.ingredients();
      expect(adapter.last.path, '/ingredients');
      expect(adapter.last.queryParameters, isEmpty, reason: 'el cliente no envia includeInactive ni page');
      final admin = await repo.ingredients(category: 'CHEESE', search: ' moz ', includeInactive: true);
      expect(adapter.last.queryParameters, {'category': 'CHEESE', 'search': 'moz', 'includeInactive': 'true'});
      expect(admin.single.valueFor('MEDIUM')!.price, '1.50');
      expect(admin.single.stock, 120);
    });

    test('alta, edicion, stock y estado usan los metodos y cuerpos del contrato', () async {
      final adapter = RecordingAdapter((o) => (status: 200, body: {'data': ingredientJson(fx.mozzarella)}));
      final repo = DioCatalogRepository(dioWith(adapter));
      final draft = IngredientDraft(
        code: 'QUE-MOZ',
        name: 'Queso mozzarella',
        categoryCode: 'CHEESE',
        vatRateCode: 'VAT_15',
        stock: 120,
        sizeValues: const [SizeValue(sizeCode: 'MEDIUM', price: '1.50', calories: 110)],
      );
      await repo.createIngredient(draft);
      expect([adapter.last.method, adapter.last.path], ['POST', '/ingredients']);
      expect((adapter.last.data as Map).keys, containsAll(['code', 'name', 'categoryCode', 'vatRateCode', 'active', 'stock', 'sizeValues']));

      await repo.updateIngredient('i1', draft);
      expect([adapter.last.method, adapter.last.path], ['PUT', '/ingredients/i1']);
      expect((adapter.last.data as Map).containsKey('stock'), isFalse);
      expect((adapter.last.data as Map).containsKey('active'), isFalse);

      await repo.adjustStock('i1', operation: 'ADD', value: -5);
      expect([adapter.last.method, adapter.last.path], ['PATCH', '/ingredients/i1/stock']);
      expect(adapter.last.data, {'operation': 'ADD', 'value': -5});

      await repo.setIngredientActive('i1', false);
      expect([adapter.last.method, adapter.last.path], ['PATCH', '/ingredients/i1/status']);
      expect(adapter.last.data, {'active': false});

      await repo.ingredient('i1');
      expect([adapter.last.method, adapter.last.path], ['GET', '/ingredients/i1']);
    });
  });

  group('DioPresetRepository', () {
    Map<String, dynamic> presetJson() => {
          'id': 'p1',
          'code': 'MARGHERITA',
          'name': 'Margarita',
          'description': 'Tomate y mozzarella',
          'active': true,
          'sortOrder': 1,
          'recipe': [
            {'ingredientId': 'd1', 'code': 'D1', 'name': 'Masa tradicional', 'categoryCode': 'DOUGH', 'portions': 1, 'active': true, 'stock': 40},
          ],
          'pricesBySize': [
            {'sizeCode': 'MEDIUM', 'price': '6.00', 'calories': 580},
          ],
          'available': false,
          'unavailableReasons': [
            {'code': 'PRESET_UNAVAILABLE', 'message': 'La pizza Margarita no está disponible: falta Masa.', 'itemIndex': null, 'ingredientId': null, 'meta': {}},
          ],
        };

    test('lista (includeInactive solo si true), detalle, alta, edicion y estado', () async {
      final adapter = RecordingAdapter((o) => (
            status: 200,
            body: {'data': o.method == 'GET' && o.path == '/preset-pizzas' ? [presetJson()] : presetJson()},
          ));
      final repo = DioPresetRepository(dioWith(adapter));
      final list = await repo.list();
      expect(adapter.last.queryParameters, isEmpty);
      expect(list.single.priceFor('MEDIUM')!.price, '6.00');
      expect(list.single.available, isFalse);
      expect(list.single.unavailableText, 'La pizza Margarita no está disponible: falta Masa.');
      await repo.list(includeInactive: true);
      expect(adapter.last.queryParameters, {'includeInactive': 'true'});

      await repo.get('p1');
      expect(adapter.last.path, '/preset-pizzas/p1');

      const draft = PresetDraft(
        code: 'MARGHERITA',
        name: 'Margarita',
        description: 'x',
        sortOrder: 1,
        recipe: [PortionInput(ingredientId: 'd1', portions: 1)],
      );
      await repo.create(draft);
      expect([adapter.last.method, adapter.last.path], ['POST', '/preset-pizzas']);
      expect((adapter.last.data as Map)['active'], true);
      await repo.update('p1', draft);
      expect([adapter.last.method, adapter.last.path], ['PUT', '/preset-pizzas/p1']);
      expect((adapter.last.data as Map).containsKey('active'), isFalse);
      await repo.setActive('p1', false);
      expect([adapter.last.method, adapter.last.path], ['PATCH', '/preset-pizzas/p1/status']);
      expect(adapter.last.data, {'active': false});
    });
  });

  group('DioOrdersRepository', () {
    final server = FakeServer();
    const item = PizzaItemInput(
      type: 'CUSTOM',
      sizeCode: 'MEDIUM',
      doughId: 'd1',
      sauceId: 's1',
      toppings: [PortionInput(ingredientId: 'c1', portions: 3)],
    );

    test('quote: POST /orders/quote con items[] y CancelToken', () async {
      final adapter = RecordingAdapter((o) => (status: 200, body: {'data': server.quoteJson([item])}));
      final repo = DioOrdersRepository(dioWith(adapter));
      final token = CancelToken();
      final q = await repo.quote([item], cancelToken: token);
      expect([adapter.last.method, adapter.last.path], ['POST', '/orders/quote']);
      expect(adapter.last.data, {'items': [item.toJson()]});
      expect(adapter.last.cancelToken, same(token));
      expect(q.items.single.unitPrice, '7.50');
    });

    test('quote cancelada se convierte en ApiException CANCELLED', () async {
      final adapter = RecordingAdapter((o) => (status: 200, body: {'data': server.quoteJson([item])}));
      final repo = DioOrdersRepository(dioWith(adapter));
      final token = CancelToken()..cancel();
      await expectLater(
        repo.quote([item], cancelToken: token),
        throwsA(isA<ApiException>().having((e) => e.isCancelled, 'cancelled', isTrue)),
      );
    });

    test('create: expectedTotal opcional y 409 PRICE_CHANGED con details[0].quote', () async {
      var conflict = false;
      final adapter = RecordingAdapter((o) => conflict
          ? (
              status: 409,
              body: {
                'error': {
                  'code': 'PRICE_CHANGED',
                  'message': 'x',
                  'details': [
                    {'quote': {'items': [], 'totals': {'total': '9.99'}}},
                  ],
                },
              },
            )
          : (status: 201, body: {'data': server.orderJson([item])}));
      final repo = DioOrdersRepository(dioWith(adapter));
      final order = await repo.create([item], expectedTotal: '10.89');
      expect([adapter.last.method, adapter.last.path], ['POST', '/orders']);
      expect(adapter.last.data, {'items': [item.toJson()], 'expectedTotal': '10.89'});
      expect(order.orderNumber, 'GP-20261106-0001');

      await repo.create([item]);
      expect((adapter.last.data as Map).containsKey('expectedTotal'), isFalse);

      conflict = true;
      await expectLater(
        repo.create([item], expectedTotal: '10.89'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'PRICE_CHANGED')
            .having((e) => e.newTotalFromPriceChanged, 'nuevo total', '9.99')),
      );
    });

    test('list: filtros, paginacion y respuesta { data, page, pageSize, total }', () async {
      final adapter = RecordingAdapter((o) => (
            status: 200,
            body: {
              'data': [
                {
                  'id': 'o1',
                  'orderNumber': 'GP-20261106-0001',
                  'orderDate': '2026-11-06',
                  'createdAt': '2026-11-06T15:04:05.123Z',
                  'status': 'IN_PREPARATION',
                  'customer': {'id': 'u1', 'fullName': 'Ana Pérez', 'email': 'ana@ejemplo.com'},
                  'pizzaCount': 3,
                  'totalCalories': 2070,
                  'total': '25.44',
                },
              ],
              'page': 2,
              'pageSize': 20,
              'total': 41,
            },
          ));
      final repo = DioOrdersRepository(dioWith(adapter));
      final page = await repo.list(const OrdersQuery(status: OrderStatus.inPreparation, page: 2, from: '2026-11-01', search: ' ana '));
      expect(adapter.last.path, '/orders');
      expect(adapter.last.queryParameters, {
        'page': 2,
        'pageSize': 20,
        'status': 'IN_PREPARATION',
        'from': '2026-11-01',
        'search': 'ana',
      });
      expect(page.total, 41);
      expect(page.totalPages, 3);
      expect(page.items.single.status, OrderStatus.inPreparation);
      expect(page.items.single.total, '25.44');
    });

    test('get y updateStatus', () async {
      final adapter = RecordingAdapter((o) => (status: 200, body: {'data': server.orderJson([item], status: 'IN_PREPARATION')}));
      final repo = DioOrdersRepository(dioWith(adapter));
      final order = await repo.get('o1');
      expect([adapter.last.method, adapter.last.path], ['GET', '/orders/o1']);
      expect(order.status, OrderStatus.inPreparation);
      await repo.updateStatus('o1', OrderStatus.delivered);
      expect([adapter.last.method, adapter.last.path], ['PATCH', '/orders/o1/status']);
      expect(adapter.last.data, {'status': 'DELIVERED'});
    });

    test('OrdersQuery: igualdad por valor y copyWith explicito de null', () {
      const a = OrdersQuery(status: OrderStatus.pending);
      expect(a, const OrdersQuery(status: OrderStatus.pending));
      expect(a.copyWith(status: null).status, isNull);
      expect(a.copyWith(page: 3).page, 3);
      expect(a.copyWith(page: 3).status, OrderStatus.pending);
    });
  });
}
