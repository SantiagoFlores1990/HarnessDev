import '../../../core/api/api_exception.dart';
import '../../orders/domain/order_models.dart';
import '../../preset_pizzas/domain/preset_models.dart';

/// Maximo de porciones por ingrediente (limite de entrada; la regla real es del servidor).
const int maxPortionsPerIngredient = 3;

/// Estado del armado de una pizza. Solo guarda la seleccion; precio, calorias y reglas
/// vienen siempre de `POST /orders/quote` (ADR-002).
class BuilderState {
  const BuilderState({
    this.sizeCode = 'MEDIUM',
    this.doughId,
    this.sauceId,
    this.portions = const {},
    this.quantity = 1,
    this.preset,
    this.recipePortions = const {},
    this.quote,
    this.quoting = false,
    this.quoteError,
    this.initialized = false,
  });

  final String sizeCode;
  final String? doughId;
  final String? sauceId;

  /// Porciones totales por ingrediente (ingredientId -> 1..3), incluidas las de receta.
  final Map<String, int> portions;
  final int quantity;

  /// Predefinida base (modo "solo agregar"), o null si se arma desde cero.
  final PresetPizza? preset;

  /// Porciones de receta por ingrediente (ingredientId -> n); vacio si no hay predefinida.
  final Map<String, int> recipePortions;

  final QuoteResult? quote;
  final bool quoting;
  final ApiException? quoteError;
  final bool initialized;

  bool get isPreset => preset != null;

  String? get recipeDoughId => _recipeIdOf('DOUGH');
  String? get recipeSauceId => _recipeIdOf('SAUCE');

  String? _recipeIdOf(String category) {
    if (preset == null) return null;
    for (final r in preset!.recipe) {
      if (r.categoryCode == category) return r.ingredientId;
    }
    return null;
  }

  bool isRecipeIngredient(String id) => recipePortions.containsKey(id);
  int recipePortionsOf(String id) => recipePortions[id] ?? 0;
  int portionsOf(String id) => portions[id] ?? 0;

  /// Hay algo elegido que se perderia al cancelar (mas alla de la receta base).
  bool get hasSelection {
    if (isPreset) {
      return portions.entries.any((e) => e.value != recipePortionsOf(e.key)) || quantity != 1;
    }
    return doughId != null || sauceId != null || portions.isNotEmpty || quantity != 1;
  }

  /// Item para el API. En PRESET solo se envian las porciones adicionales a la receta.
  PizzaItemInput toInput() {
    if (isPreset) {
      final extras = <PortionInput>[];
      portions.forEach((id, total) {
        final extra = total - recipePortionsOf(id);
        if (extra > 0) extras.add(PortionInput(ingredientId: id, portions: extra));
      });
      return PizzaItemInput(
        type: PizzaTypes.preset,
        presetPizzaId: preset!.id,
        sizeCode: sizeCode,
        extras: extras,
        quantity: quantity,
      );
    }
    return PizzaItemInput(
      type: PizzaTypes.custom,
      sizeCode: sizeCode,
      doughId: doughId,
      sauceId: sauceId,
      toppings: [
        for (final e in portions.entries) PortionInput(ingredientId: e.key, portions: e.value),
      ],
      quantity: quantity,
    );
  }

  /// "Agregar al pedido" solo con cotizacion vigente y valida.
  bool get canAdd {
    final q = quote;
    return initialized &&
        !quoting &&
        quoteError == null &&
        q != null &&
        q.valid &&
        q.items.isNotEmpty &&
        q.items.first.valid;
  }

  BuilderState copyWith({
    String? sizeCode,
    Object? doughId = _unset,
    Object? sauceId = _unset,
    Map<String, int>? portions,
    int? quantity,
    Object? quote = _unset,
    bool? quoting,
    Object? quoteError = _unset,
    bool? initialized,
  }) =>
      BuilderState(
        sizeCode: sizeCode ?? this.sizeCode,
        doughId: identical(doughId, _unset) ? this.doughId : doughId as String?,
        sauceId: identical(sauceId, _unset) ? this.sauceId : sauceId as String?,
        portions: portions ?? this.portions,
        quantity: quantity ?? this.quantity,
        preset: preset,
        recipePortions: recipePortions,
        quote: identical(quote, _unset) ? this.quote : quote as QuoteResult?,
        quoting: quoting ?? this.quoting,
        quoteError: identical(quoteError, _unset) ? this.quoteError : quoteError as ApiException?,
        initialized: initialized ?? this.initialized,
      );
}

const Object _unset = Object();
