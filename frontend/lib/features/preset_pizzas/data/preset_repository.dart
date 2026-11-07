import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/dio_provider.dart';
import '../domain/preset_models.dart';

abstract class PresetRepository {
  /// El cliente recibe solo activas (las no disponibles llegan con `available: false`).
  /// El ADMIN debe enviar `includeInactive: true`.
  Future<List<PresetPizza>> list({bool includeInactive = false});
  Future<PresetPizza> get(String id);
  Future<PresetPizza> create(PresetDraft draft);
  Future<PresetPizza> update(String id, PresetDraft draft);
  Future<PresetPizza> setActive(String id, bool active);
}

class DioPresetRepository implements PresetRepository {
  DioPresetRepository(this._dio);
  final Dio _dio;

  Map<String, dynamic> _obj(Response<dynamic> r) =>
      Map<String, dynamic>.from((r.data as Map)['data'] as Map);

  @override
  Future<List<PresetPizza>> list({bool includeInactive = false}) => apiCall(() async {
        final response = await _dio.get<dynamic>('/preset-pizzas',
            queryParameters: {if (includeInactive) 'includeInactive': 'true'});
        return ((response.data as Map)['data'] as List)
            .map((e) => PresetPizza.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      });

  @override
  Future<PresetPizza> get(String id) =>
      apiCall(() async => PresetPizza.fromJson(_obj(await _dio.get<dynamic>('/preset-pizzas/$id'))));

  @override
  Future<PresetPizza> create(PresetDraft draft) => apiCall(() async =>
      PresetPizza.fromJson(_obj(await _dio.post<dynamic>('/preset-pizzas', data: draft.toCreateJson()))));

  @override
  Future<PresetPizza> update(String id, PresetDraft draft) => apiCall(() async =>
      PresetPizza.fromJson(_obj(await _dio.put<dynamic>('/preset-pizzas/$id', data: draft.toUpdateJson()))));

  @override
  Future<PresetPizza> setActive(String id, bool active) => apiCall(() async => PresetPizza.fromJson(
      _obj(await _dio.patch<dynamic>('/preset-pizzas/$id/status', data: {'active': active}))));
}

final presetRepositoryProvider =
    Provider<PresetRepository>((ref) => DioPresetRepository(ref.watch(dioProvider)));

/// Predefinidas para el cliente (S-03).
final presetPizzasProvider = FutureProvider.autoDispose<List<PresetPizza>>(
    (ref) => ref.watch(presetRepositoryProvider).list());

/// Una predefinida por id (S-04 con `presetId`).
final presetPizzaProvider = FutureProvider.autoDispose.family<PresetPizza, String>(
    (ref, id) => ref.watch(presetRepositoryProvider).get(id));
