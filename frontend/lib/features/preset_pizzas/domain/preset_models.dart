import '../../orders/domain/order_models.dart';

/// Ingrediente de la receta de una predefinida.
class RecipeItem {
  const RecipeItem({
    required this.ingredientId,
    required this.code,
    required this.name,
    required this.categoryCode,
    required this.portions,
    this.active = true,
    this.stock = 0,
  });
  final String ingredientId;
  final String code;
  final String name;
  final String categoryCode;
  final int portions;
  final bool active;
  final int stock;

  factory RecipeItem.fromJson(Map<String, dynamic> json) => RecipeItem(
        ingredientId: json['ingredientId'] as String,
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        categoryCode: json['categoryCode'] as String? ?? '',
        portions: (json['portions'] as num?)?.toInt() ?? 1,
        active: json['active'] as bool? ?? true,
        stock: (json['stock'] as num?)?.toInt() ?? 0,
      );
}

/// Precio y calorias calculados por el motor para un tamano.
class SizePrice {
  const SizePrice({required this.sizeCode, required this.price, required this.calories});
  final String sizeCode;
  final String price;
  final int calories;

  factory SizePrice.fromJson(Map<String, dynamic> json) => SizePrice(
        sizeCode: json['sizeCode'] as String,
        price: json['price'].toString(),
        calories: (json['calories'] as num).toInt(),
      );
}

/// Pizza predefinida con receta, precios por tamano y disponibilidad.
class PresetPizza {
  const PresetPizza({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.active,
    required this.sortOrder,
    required this.recipe,
    required this.pricesBySize,
    required this.available,
    required this.unavailableReasons,
  });
  final String id;
  final String code;
  final String name;
  final String description;
  final bool active;
  final int sortOrder;
  final List<RecipeItem> recipe;
  final List<SizePrice> pricesBySize;
  final bool available;
  final List<Violation> unavailableReasons;

  SizePrice? priceFor(String sizeCode) {
    for (final p in pricesBySize) {
      if (p.sizeCode == sizeCode) return p;
    }
    return null;
  }

  /// Motivo legible de no disponibilidad (primer mensaje del servidor).
  String? get unavailableText =>
      unavailableReasons.isEmpty ? null : unavailableReasons.first.message;

  factory PresetPizza.fromJson(Map<String, dynamic> json) => PresetPizza(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        active: json['active'] as bool? ?? true,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
        recipe: ((json['recipe'] as List?) ?? const [])
            .map((e) => RecipeItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        pricesBySize: ((json['pricesBySize'] as List?) ?? const [])
            .map((e) => SizePrice.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        available: json['available'] as bool? ?? true,
        unavailableReasons: Violation.listFrom(json['unavailableReasons']),
      );
}

/// Datos de formulario de una predefinida (alta o edicion).
class PresetDraft {
  const PresetDraft({
    required this.code,
    required this.name,
    required this.description,
    required this.sortOrder,
    required this.recipe,
    this.active = true,
  });
  final String code;
  final String name;
  final String description;
  final int sortOrder;
  final List<PortionInput> recipe;
  final bool active;

  Map<String, dynamic> toCreateJson() => {
        'code': code,
        'name': name,
        'description': description,
        'active': active,
        'sortOrder': sortOrder,
        'recipe': recipe.map((e) => e.toJson()).toList(),
      };

  /// `PUT` no admite `active`.
  Map<String, dynamic> toUpdateJson() => {
        'code': code,
        'name': name,
        'description': description,
        'sortOrder': sortOrder,
        'recipe': recipe.map((e) => e.toJson()).toList(),
      };
}
