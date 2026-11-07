import 'order_models.dart';

/// Textos de respaldo por codigo de violacion (screens.md §6.2).
const Map<String, String> _fallbackByViolation = {
  'DOUGH_REQUIRED': 'Elige una masa.',
  'SAUCE_REQUIRED': 'Elige una salsa base.',
  'INVALID_DOUGH': 'El ingrediente elegido no es una masa.',
  'INVALID_SAUCE': 'El ingrediente elegido no es una salsa.',
  'INGREDIENT_CATEGORY_NOT_ALLOWED':
      'La masa y la salsa no se agregan como ingredientes adicionales.',
  'DUPLICATE_INGREDIENT': 'Un ingrediente aparece repetido; usa la cantidad.',
  'MAX_PORTIONS_EXCEEDED': 'Máximo 3 porciones por ingrediente.',
  'MIN_TOPPINGS_NOT_MET': 'Elige al menos 3 ingredientes distintos.',
  'INGREDIENT_NOT_FOUND': 'Ingrediente inexistente.',
  'INGREDIENT_INACTIVE': 'Un ingrediente elegido no está disponible.',
  'MISSING_SIZE_VALUES': 'Un ingrediente no tiene precio para el tamaño elegido.',
  'PRESET_NOT_FOUND': 'La pizza predefinida no existe.',
  'PRESET_INACTIVE': 'La pizza predefinida no está disponible.',
  'PRESET_UNAVAILABLE': 'La pizza predefinida no está disponible.',
  'INSUFFICIENT_STOCK': 'No hay stock suficiente para esta pizza.',
};

/// Texto de una violacion: mensaje del servidor (ya en espanol) o respaldo por codigo.
String violationText(Violation v) {
  if (v.message.trim().isNotEmpty) return v.message;
  return _fallbackByViolation[v.code] ?? 'La pizza no cumple una regla de armado.';
}

/// Codigos de violacion conocidos (15 del contrato).
const List<String> knownViolationCodes = [
  'DOUGH_REQUIRED', 'SAUCE_REQUIRED', 'INVALID_DOUGH', 'INVALID_SAUCE',
  'INGREDIENT_CATEGORY_NOT_ALLOWED', 'DUPLICATE_INGREDIENT', 'MAX_PORTIONS_EXCEEDED',
  'MIN_TOPPINGS_NOT_MET', 'INGREDIENT_NOT_FOUND', 'INGREDIENT_INACTIVE',
  'MISSING_SIZE_VALUES', 'PRESET_NOT_FOUND', 'PRESET_INACTIVE', 'PRESET_UNAVAILABLE',
  'INSUFFICIENT_STOCK',
];

bool hasFallbackFor(String code) => _fallbackByViolation.containsKey(code);
