/// Codigos de categoria con regla especial en el armado.
abstract final class CategoryCodes {
  static const dough = 'DOUGH';
  static const sauce = 'SAUCE';
}

/// Tamano de pizza (`GET /sizes`).
class SizeOption {
  const SizeOption({required this.code, required this.name, this.sortOrder = 0});
  final String code;
  final String name;
  final int sortOrder;

  factory SizeOption.fromJson(Map<String, dynamic> json) => SizeOption(
        code: json['code'] as String,
        name: json['name'] as String,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      );
}

/// Categoria de ingrediente (`GET /ingredient-categories`).
class IngredientCategory {
  const IngredientCategory({required this.code, required this.name, this.sortOrder = 0});
  final String code;
  final String name;
  final int sortOrder;

  factory IngredientCategory.fromJson(Map<String, dynamic> json) => IngredientCategory(
        code: json['code'] as String,
        name: json['name'] as String,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      );
}

/// Tarifa de IVA (`GET /vat-rates`, solo ADMIN).
class VatRate {
  const VatRate({
    required this.code,
    required this.name,
    required this.ratePercent,
    this.isDefault = false,
  });
  final String code;
  final String name;
  final String ratePercent;
  final bool isDefault;

  factory VatRate.fromJson(Map<String, dynamic> json) => VatRate(
        code: json['code'] as String,
        name: json['name'] as String,
        ratePercent: json['ratePercent'].toString(),
        isDefault: json['isDefault'] as bool? ?? false,
      );
}

/// Precio y calorias de un ingrediente para un tamano.
class SizeValue {
  const SizeValue({required this.sizeCode, required this.price, required this.calories});
  final String sizeCode;
  final String price;
  final int calories;

  factory SizeValue.fromJson(Map<String, dynamic> json) => SizeValue(
        sizeCode: json['sizeCode'] as String,
        price: json['price'].toString(),
        calories: (json['calories'] as num).toInt(),
      );

  Map<String, dynamic> toJson() =>
      {'sizeCode': sizeCode, 'price': price, 'calories': calories};
}

/// Ingrediente del catalogo (vista cliente o admin).
class Ingredient {
  const Ingredient({
    required this.id,
    required this.code,
    required this.name,
    required this.categoryCode,
    required this.categoryName,
    required this.vatRateCode,
    required this.vatRatePercent,
    required this.active,
    required this.stock,
    required this.sizeValues,
  });

  final String id;
  final String code;
  final String name;
  final String categoryCode;
  final String categoryName;
  final String vatRateCode;
  final String vatRatePercent;
  final bool active;
  final int stock;
  final List<SizeValue> sizeValues;

  bool get isDough => categoryCode == CategoryCodes.dough;
  bool get isSauce => categoryCode == CategoryCodes.sauce;
  bool get isOutOfStock => stock <= 0;

  SizeValue? valueFor(String sizeCode) {
    for (final v in sizeValues) {
      if (v.sizeCode == sizeCode) return v;
    }
    return null;
  }

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>;
    final vat = json['vatRate'] as Map<String, dynamic>;
    return Ingredient(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      categoryCode: category['code'] as String,
      categoryName: category['name'] as String,
      vatRateCode: vat['code'] as String,
      vatRatePercent: vat['ratePercent'].toString(),
      active: json['active'] as bool? ?? true,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      sizeValues: ((json['sizeValues'] as List?) ?? const [])
          .map((e) => SizeValue.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Datos de formulario de ingrediente (alta o edicion).
class IngredientDraft {
  const IngredientDraft({
    required this.code,
    required this.name,
    required this.categoryCode,
    required this.vatRateCode,
    required this.sizeValues,
    this.active = true,
    this.stock = 0,
  });
  final String code;
  final String name;
  final String categoryCode;
  final String vatRateCode;
  final List<SizeValue> sizeValues;
  final bool active;
  final int stock;

  Map<String, dynamic> toCreateJson() => {
        'code': code,
        'name': name,
        'categoryCode': categoryCode,
        'vatRateCode': vatRateCode,
        'active': active,
        'stock': stock,
        'sizeValues': sizeValues.map((e) => e.toJson()).toList(),
      };

  /// `PUT` no admite `stock` ni `active`.
  Map<String, dynamic> toUpdateJson() => {
        'code': code,
        'name': name,
        'categoryCode': categoryCode,
        'vatRateCode': vatRateCode,
        'sizeValues': sizeValues.map((e) => e.toJson()).toList(),
      };
}

/// Pagina generica `{ data, page, pageSize, total }`.
class PageResult<T> {
  const PageResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });
  final List<T> items;
  final int page;
  final int pageSize;
  final int total;

  int get totalPages => total == 0 ? 1 : (total + pageSize - 1) ~/ pageSize;
}
