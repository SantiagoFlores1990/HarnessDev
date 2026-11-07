import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/utils/debouncer.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../orders/data/orders_repository.dart';
import '../../preset_pizzas/domain/preset_models.dart';
import '../domain/builder_state.dart';

/// Espera antes de cotizar tras un cambio de la seleccion (~150 ms, arquitectura §2.4).
final quoteDebounceProvider = Provider<Duration>((ref) => const Duration(milliseconds: 150));

/// Controlador del armado: mantiene la seleccion y pide el calculo en vivo al servidor
/// con debounce y cancelacion de la peticion anterior.
class PizzaBuilderController extends Notifier<BuilderState> {
  late Debouncer _debouncer;
  CancelToken? _cancel;
  int _seq = 0;

  @override
  BuilderState build() {
    _debouncer = Debouncer(ref.read(quoteDebounceProvider));
    ref.onDispose(() {
      _debouncer.cancel();
      _cancel?.cancel();
    });
    return const BuilderState();
  }

  /// Inicia el armado desde cero o sobre una predefinida (receta bloqueada, solo agregar).
  void init({PresetPizza? preset, String sizeCode = 'MEDIUM'}) {
    final portions = <String, int>{};
    final recipe = <String, int>{};
    String? dough;
    String? sauce;
    if (preset != null) {
      for (final r in preset.recipe) {
        if (r.categoryCode == CategoryCodes.dough) {
          dough = r.ingredientId;
        } else if (r.categoryCode == CategoryCodes.sauce) {
          sauce = r.ingredientId;
        } else {
          portions[r.ingredientId] = r.portions;
          recipe[r.ingredientId] = r.portions;
        }
      }
    }
    state = BuilderState(
      sizeCode: sizeCode,
      doughId: dough,
      sauceId: sauce,
      portions: portions,
      preset: preset,
      recipePortions: recipe,
      initialized: true,
    );
    _requestQuote();
  }

  /// Vuelve a una seleccion vacia (o a la receta base) tras agregar al pedido.
  void reset() => init(preset: state.preset, sizeCode: state.sizeCode);

  void setSize(String code) {
    if (code == state.sizeCode) return;
    state = state.copyWith(sizeCode: code);
    _requestQuote();
  }

  /// Masa exclusiva: marcar otra desmarca la anterior; `null` desmarca.
  void selectDough(String? id) {
    if (state.isPreset) return;
    state = state.copyWith(doughId: id);
    _requestQuote();
  }

  void selectSauce(String? id) {
    if (state.isPreset) return;
    state = state.copyWith(sauceId: id);
    _requestQuote();
  }

  /// Marca (1 porcion) o desmarca un ingrediente. Los de receta no se pueden quitar.
  void toggleTopping(String id) {
    if (state.isRecipeIngredient(id)) return;
    final next = {...state.portions};
    if (next.containsKey(id)) {
      next.remove(id);
    } else {
      next[id] = 1;
    }
    state = state.copyWith(portions: next);
    _requestQuote();
  }

  /// Fija las porciones totales (1..3); nunca por debajo de las de receta.
  void setPortions(String id, int portions) {
    final min = state.isRecipeIngredient(id) ? state.recipePortionsOf(id) : 1;
    final value = portions.clamp(min, maxPortionsPerIngredient);
    state = state.copyWith(portions: {...state.portions, id: value});
    _requestQuote();
  }

  void setQuantity(int quantity) {
    state = state.copyWith(quantity: quantity.clamp(1, 20));
    _requestQuote();
  }

  /// Reintenta la cotizacion tras un error.
  void retryQuote() => _requestQuote(immediate: true);

  void _requestQuote({bool immediate = false}) {
    state = state.copyWith(quoting: true, quoteError: null);
    _cancel?.cancel();
    _debouncer.cancel();
    if (immediate) {
      _runQuote();
    } else {
      _debouncer.run(_runQuote);
    }
  }

  Future<void> _runQuote() async {
    final seq = ++_seq;
    final cancel = CancelToken();
    _cancel = cancel;
    try {
      final result = await ref
          .read(ordersRepositoryProvider)
          .quote([state.toInput()], cancelToken: cancel);
      if (seq != _seq) return;
      state = state.copyWith(quote: result, quoting: false, quoteError: null);
    } on ApiException catch (e) {
      if (e.isCancelled || seq != _seq) return;
      state = state.copyWith(quoting: false, quoteError: e);
    }
  }
}

final pizzaBuilderProvider =
    NotifierProvider.autoDispose<PizzaBuilderController, BuilderState>(PizzaBuilderController.new);
