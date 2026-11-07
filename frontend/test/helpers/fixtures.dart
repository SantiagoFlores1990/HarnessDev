import 'package:good_pizza/features/catalog/domain/catalog_models.dart';
import 'package:good_pizza/features/orders/domain/order_models.dart';
import 'package:good_pizza/features/preset_pizzas/domain/preset_models.dart';

/// Datos de ejemplo de pruebas (no son los del seed del backend).
const sizes = [
  SizeOption(code: 'INDIVIDUAL', name: 'Individual', sortOrder: 1),
  SizeOption(code: 'MEDIUM', name: 'Mediana', sortOrder: 2),
  SizeOption(code: 'FAMILY', name: 'Familiar', sortOrder: 3),
];

const categories = [
  IngredientCategory(code: 'DOUGH', name: 'Masa', sortOrder: 1),
  IngredientCategory(code: 'SAUCE', name: 'Salsa', sortOrder: 2),
  IngredientCategory(code: 'CHEESE', name: 'Queso', sortOrder: 3),
  IngredientCategory(code: 'MEAT', name: 'Carne', sortOrder: 4),
  IngredientCategory(code: 'VEGETABLE', name: 'Vegetal', sortOrder: 5),
  IngredientCategory(code: 'OTHER', name: 'Otros', sortOrder: 6),
];

const vatRates = [
  VatRate(code: 'VAT_15', name: 'IVA 15 %', ratePercent: '15.00', isDefault: true),
  VatRate(code: 'VAT_0', name: 'IVA 0 %', ratePercent: '0.00'),
];

/// Construye un ingrediente con valores para los tres tamanos.
Ingredient ingredient(
  String id,
  String name,
  String category, {
  required int stock,
  required String medium,
  required int mediumKcal,
  String vat = 'VAT_15',
  bool active = true,
}) {
  String scale(String m, double f) => (double.parse(m) * f).toStringAsFixed(2);
  final cat = categories.firstWhere((c) => c.code == category);
  return Ingredient(
    id: id,
    code: id.toUpperCase(),
    name: name,
    categoryCode: category,
    categoryName: cat.name,
    vatRateCode: vat,
    vatRatePercent: vat == 'VAT_15' ? '15.00' : '0.00',
    active: active,
    stock: stock,
    sizeValues: [
      SizeValue(sizeCode: 'INDIVIDUAL', price: scale(medium, 0.8), calories: (mediumKcal * 0.8).round()),
      SizeValue(sizeCode: 'MEDIUM', price: medium, calories: mediumKcal),
      SizeValue(sizeCode: 'FAMILY', price: scale(medium, 1.5), calories: (mediumKcal * 1.5).round()),
    ],
  );
}

final dough1 = ingredient('d1', 'Masa tradicional', 'DOUGH', stock: 40, medium: '2.00', mediumKcal: 300);
final dough2 = ingredient('d2', 'Masa delgada', 'DOUGH', stock: 25, medium: '1.80', mediumKcal: 240);
final dough3 = ingredient('d3', 'Masa integral', 'DOUGH', stock: 0, medium: '2.20', mediumKcal: 280);
final sauce1 = ingredient('s1', 'Salsa de tomate', 'SAUCE', stock: 60, medium: '1.00', mediumKcal: 60, vat: 'VAT_0');
final sauce2 = ingredient('s2', 'Salsa BBQ', 'SAUCE', stock: 30, medium: '1.10', mediumKcal: 80);
final mozzarella = ingredient('c1', 'Queso mozzarella', 'CHEESE', stock: 120, medium: '1.50', mediumKcal: 110);
final cheddar = ingredient('c2', 'Queso cheddar', 'CHEESE', stock: 3, medium: '1.60', mediumKcal: 120);
final ham = ingredient('m1', 'Jamón', 'MEAT', stock: 80, medium: '1.20', mediumKcal: 90);
final pepperoni = ingredient('m2', 'Pepperoni', 'MEAT', stock: 50, medium: '1.40', mediumKcal: 130);
final mushrooms = ingredient('v1', 'Champiñones', 'VEGETABLE', stock: 2, medium: '0.90', mediumKcal: 25);
final pineapple = ingredient('o1', 'Piña', 'OTHER', stock: 0, medium: '0.80', mediumKcal: 40, vat: 'VAT_0');

final catalog = <Ingredient>[
  dough1, dough2, dough3, sauce1, sauce2, mozzarella, cheddar, ham, pepperoni, mushrooms, pineapple,
];

RecipeItem recipeOf(Ingredient i, int portions) => RecipeItem(
      ingredientId: i.id,
      code: i.code,
      name: i.name,
      categoryCode: i.categoryCode,
      portions: portions,
      active: i.active,
      stock: i.stock,
    );

PresetPizza preset(
  String id,
  String name,
  List<RecipeItem> recipe, {
  bool available = true,
  bool active = true,
  int sortOrder = 1,
  List<Violation> reasons = const [],
}) =>
    PresetPizza(
      id: id,
      code: id.toUpperCase(),
      name: name,
      description: 'Receta de $name',
      active: active,
      sortOrder: sortOrder,
      recipe: recipe,
      pricesBySize: const [],
      available: available,
      unavailableReasons: reasons,
    );
