import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/dio_provider.dart';
import '../../catalog/domain/catalog_models.dart';
import '../domain/order_models.dart';

/// Filtros de `GET /orders`.
class OrdersQuery {
  const OrdersQuery({this.status, this.from, this.to, this.search, this.page = 1, this.pageSize = 20});
  final OrderStatus? status;
  final String? from;
  final String? to;
  final String? search;
  final int page;
  final int pageSize;

  OrdersQuery copyWith({
    Object? status = _unset,
    Object? from = _unset,
    Object? to = _unset,
    Object? search = _unset,
    int? page,
  }) =>
      OrdersQuery(
        status: identical(status, _unset) ? this.status : status as OrderStatus?,
        from: identical(from, _unset) ? this.from : from as String?,
        to: identical(to, _unset) ? this.to : to as String?,
        search: identical(search, _unset) ? this.search : search as String?,
        page: page ?? this.page,
        pageSize: pageSize,
      );

  @override
  bool operator ==(Object other) =>
      other is OrdersQuery &&
      other.status == status &&
      other.from == from &&
      other.to == to &&
      other.search == search &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(status, from, to, search, page, pageSize);
}

const Object _unset = Object();

abstract class OrdersRepository {
  /// Cotizacion sin efectos. El motor del servidor calcula todo (ADR-002).
  Future<QuoteResult> quote(List<PizzaItemInput> items, {CancelToken? cancelToken});

  /// Confirma el pedido. Con `expectedTotal` el servidor responde 409 `PRICE_CHANGED` si cambio.
  Future<OrderDetail> create(List<PizzaItemInput> items, {String? expectedTotal});
  Future<PageResult<OrderSummary>> list(OrdersQuery query);
  Future<OrderDetail> get(String id);
  Future<OrderDetail> updateStatus(String id, OrderStatus status);
}

class DioOrdersRepository implements OrdersRepository {
  DioOrdersRepository(this._dio);
  final Dio _dio;

  Map<String, dynamic> _obj(Response<dynamic> r) =>
      Map<String, dynamic>.from((r.data as Map)['data'] as Map);

  @override
  Future<QuoteResult> quote(List<PizzaItemInput> items, {CancelToken? cancelToken}) =>
      apiCall(() async => QuoteResult.fromJson(_obj(await _dio.post<dynamic>(
            '/orders/quote',
            data: {'items': items.map((e) => e.toJson()).toList()},
            cancelToken: cancelToken,
          ))));

  @override
  Future<OrderDetail> create(List<PizzaItemInput> items, {String? expectedTotal}) =>
      apiCall(() async => OrderDetail.fromJson(_obj(await _dio.post<dynamic>(
            '/orders',
            data: {
              'items': items.map((e) => e.toJson()).toList(),
            'expectedTotal': ?expectedTotal,
            },
          ))));

  @override
  Future<PageResult<OrderSummary>> list(OrdersQuery query) => apiCall(() async {
        final response = await _dio.get<dynamic>('/orders', queryParameters: {
          'page': query.page,
          'pageSize': query.pageSize,
          if (query.status != null) 'status': query.status!.apiValue,
          if (query.from != null) 'from': query.from,
          if (query.to != null) 'to': query.to,
          if (query.search != null && query.search!.trim().isNotEmpty) 'search': query.search!.trim(),
        });
        final body = response.data as Map;
        return PageResult<OrderSummary>(
          items: (body['data'] as List)
              .map((e) => OrderSummary.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList(),
          page: (body['page'] as num?)?.toInt() ?? query.page,
          pageSize: (body['pageSize'] as num?)?.toInt() ?? query.pageSize,
          total: (body['total'] as num?)?.toInt() ?? 0,
        );
      });

  @override
  Future<OrderDetail> get(String id) =>
      apiCall(() async => OrderDetail.fromJson(_obj(await _dio.get<dynamic>('/orders/$id'))));

  @override
  Future<OrderDetail> updateStatus(String id, OrderStatus status) => apiCall(() async =>
      OrderDetail.fromJson(
          _obj(await _dio.patch<dynamic>('/orders/$id/status', data: {'status': status.apiValue}))));
}

final ordersRepositoryProvider =
    Provider<OrdersRepository>((ref) => DioOrdersRepository(ref.watch(dioProvider)));

/// Comprobante por id (cliente dueno o admin).
final orderDetailProvider = FutureProvider.autoDispose.family<OrderDetail, String>(
    (ref, id) => ref.watch(ordersRepositoryProvider).get(id));
