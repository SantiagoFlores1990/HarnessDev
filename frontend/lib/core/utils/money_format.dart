import 'package:intl/intl.dart';

final RegExp _decimalRe = RegExp(r'^(-?)(\d+)(?:\.(\d+))?$');

/// Da formato a un importe en string decimal del API: `"7.50"` -> `"$ 7.50"`.
/// Nunca calcula: solo da formato (ADR-002). Separador decimal: punto.
String formatMoney(String? amount) {
  if (amount == null || amount.isEmpty) return '\$ --';
  return '\$ ${normalizeDecimal(amount)}';
}

/// Normaliza a 2 decimales exactos usando solo texto (sin flotantes).
String normalizeDecimal(String amount) {
  final m = _decimalRe.firstMatch(amount.trim());
  if (m == null) return amount;
  final sign = m.group(1) ?? '';
  final whole = m.group(2)!;
  var frac = m.group(3) ?? '';
  if (frac.length > 2) frac = frac.substring(0, 2);
  frac = frac.padRight(2, '0');
  return '$sign$whole.$frac';
}

/// `"15.00"` -> `"15 %"`, `"0.00"` -> `"0 %"`.
String formatPercent(String? percent) {
  if (percent == null) return '-- %';
  final m = _decimalRe.firstMatch(percent.trim());
  if (m == null) return '$percent %';
  final whole = m.group(2)!;
  final frac = (m.group(3) ?? '').replaceFirst(RegExp(r'0+$'), '');
  return frac.isEmpty ? '$whole %' : '$whole.$frac %';
}

/// `820` -> `"820 kcal"`.
String formatKcal(int? kcal) => kcal == null ? '-- kcal' : '$kcal kcal';

final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

/// Fecha y hora local del equipo: `dd/MM/yyyy HH:mm`.
String formatDateTime(DateTime value) => _dateTimeFormat.format(value.toLocal());

/// Valida un importe escrito por el administrador: decimal >= 0 con max. 2 decimales.
/// Devuelve null si es valido; si no, el mensaje de error.
String? validatePriceText(String? raw) {
  final text = (raw ?? '').trim().replaceAll(',', '.');
  if (text.isEmpty) return 'Ingresa un precio.';
  if (text.startsWith('-')) return 'El precio no puede ser negativo.';
  final m = _decimalRe.firstMatch(text);
  if (m == null) return 'Ingresa un precio válido (ejemplo: 1.50).';
  if ((m.group(3) ?? '').length > 2) return 'Usa como máximo 2 decimales.';
  return null;
}

/// Texto de precio del formulario -> string para el API (`"1.50"`).
String priceTextToApi(String raw) => normalizeDecimal(raw.trim().replaceAll(',', '.'));
