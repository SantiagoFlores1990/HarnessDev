import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/dio_provider.dart';
import '../domain/catalog_models.dart';

/// Catalogos e ingredientes (cliente y administrador).
abstract class CatalogRepository {
  Future<List<SizeOption>> sizes();
  Future<List<IngredientCategory>> categories();
  Future<List<VatRate>> vatRates();

  /// Sin `includeInactive` el API devuelve solo activos. El ADMIN debe enviarlo en `true`.
  Future<List<Ingredient>> ingredients({
    String? category,
    String? search,
    bool includeInactive = false,
  });
  Future<Ingredient> ingredient(String id);
  Future<Ingredient> createIngredient(IngredientDraft draft);
  Future<Ingredient> updateIngredient(String id, IngredientDraft draft);

  /// `operation`: `SET` (valor >= 0) o `ADD` (entero distinto de 0, admite negativo).
  Future<Ingredient> adjustStock(String id, {required String operation, required int value});
  Future<Ingredient> setIngredientActive(String id, bool active);
}

class DioCatalogRepository implements CatalogRepository {
  DioCatalogRepository(this._dio);
  final Dio _dio;

  List<Map<String, dynamic>> _list(Response<dynamic> r) => ((r.data as Map)['data'] as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  Map<String, dynamic> _obj(Response<dynamic> r) =>
      Map<String, dynamic>.from((r.data as Map)['data'] as Map);

  @override
  Future<List<SizeOption>> sizes() => apiCall(() async =>
      _list(await _dio.get<dynamic>('/sizes')).map(SizeOption.fromJson).toList());

  @override
  Future<List<IngredientCategory>> categories() => apiCall(() async =>
      _list(await _dio.get<dynamic>('/ingredient-categories'))
          .map(IngredientCategory.fromJson)
          .toList());

  @override
  Future<List<VatRate>> vatRates() => apiCall(() async =>
      _list(await _dio.get<dynamic>('/vat-rates')).map(VatRate.fromJson).toList());

  @override
  Future<List<Ingredient>> ingredients({
    String? category,
    String? search,
    bool includeInactive = false,
  }) =>
      apiCall(() async {
        final response = await _dio.get<dynamic>('/ingredients', queryParameters: {
          if (category != null && category.isNotEmpty) 'category': category,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
          if (includeInactive) 'includeInactive': 'true',
        });
        return _list(response).map(Ingredient.fromJson).toList();
      });

  @override
  Future<Ingredient> ingredient(String id) => apiCall(
      () async => Ingredient.fromJson(_obj(await _dio.get<dynamic>('/ingredients/$id'))));

  @override
  Future<Ingredient> createIngredient(IngredientDraft draft) => apiCall(() async =>
      Ingredient.fromJson(_obj(await _dio.post<dynamic>('/ingredients', data: draft.toCreateJson()))));

  @override
  Future<Ingredient> updateIngredient(String id, IngredientDraft draft) =>
      apiCall(() async => Ingredient.fromJson(
          _obj(await _dio.put<dynamic>('/ingredients/$id', data: draft.toUpdateJson()))));

  @override
  Future<Ingredient> adjustStock(String id, {required String operation, required int value}) =>
      apiCall(() async => Ingredient.fromJson(_obj(await _dio.patch<dynamic>(
            '/ingredients/$id/stock',
            data: {'operation': operation, 'value': value},
          ))));

  @override
  Future<Ingredient> setIngredientActive(String id, bool active) =>
      apiCall(() async => Ingredient.fromJson(
          _obj(await _dio.patch<dynamic>('/ingredients/$id/status', data: {'active': active}))));
}

final catalogRepositoryProvider =
    Provider<CatalogRepository>((ref) => DioCatalogRepository(ref.watch(dioProvider)));

/// Tamanos (`GET /sizes`).
final sizesProvider = FutureProvider<List<SizeOption>>((ref) async {
  final sizes = await ref.watch(catalogRepositoryProvider).sizes();
  return [...sizes]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
});

/// Categorias de ingrediente.
final categoriesProvider = FutureProvider<List<IngredientCategory>>((ref) async {
  final list = await ref.watch(catalogRepositoryProvider).categories();
  return [...list]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
});

/// Tarifas de IVA (solo ADMIN).
final vatRatesProvider = FutureProvider<List<VatRate>>(
    (ref) => ref.watch(catalogRepositoryProvider).vatRates());

/// Ingredientes activos con stock (lista completa, sin paginar) para el armado del cliente.
final activeIngredientsProvider = FutureProvider.autoDispose<List<Ingredient>>(
    (ref) => ref.watch(catalogRepositoryProvider).ingredients());
