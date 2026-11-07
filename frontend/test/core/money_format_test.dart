import 'package:flutter_test/flutter_test.dart';
import 'package:good_pizza/core/utils/money_format.dart';

void main() {
  group('WT-30 formato de importes', () {
    test('"7.50" -> "\$ 7.50" y "15.00" -> "15 %"', () {
      expect(formatMoney('7.50'), '\$ 7.50');
      expect(formatPercent('15.00'), '15 %');
    });
    test('normaliza a 2 decimales sin usar flotantes', () {
      expect(formatMoney('7'), '\$ 7.00');
      expect(formatMoney('7.5'), '\$ 7.50');
      expect(formatMoney('0.98'), '\$ 0.98');
      expect(formatMoney('1234567.10'), '\$ 1234567.10');
    });
    test('porcentajes y calorias', () {
      expect(formatPercent('0.00'), '0 %');
      expect(formatPercent('7.50'), '7.5 %');
      expect(formatKcal(820), '820 kcal');
    });
    test('importe ausente', () => expect(formatMoney(null), '\$ --'));
    test('fecha local dd/MM/yyyy HH:mm', () {
      final local = DateTime(2026, 11, 6, 10, 4);
      expect(formatDateTime(local), '06/11/2026 10:04');
      // una fecha UTC se muestra en hora local del equipo
      final utc = DateTime.utc(2026, 11, 6, 15, 4, 5);
      expect(formatDateTime(utc), formatDateTime(utc.toLocal()));
    });
  });

  group('validacion de precios (S-08)', () {
    test('acepta decimales validos', () {
      expect(validatePriceText('1.50'), isNull);
      expect(validatePriceText('2'), isNull);
      expect(validatePriceText('0'), isNull);
      expect(validatePriceText('1,5'), isNull);
    });
    test('rechaza negativos, vacios, texto y mas de 2 decimales', () {
      expect(validatePriceText('-1'), 'El precio no puede ser negativo.');
      expect(validatePriceText(''), 'Ingresa un precio.');
      expect(validatePriceText('abc'), isNotNull);
      expect(validatePriceText('1.234'), 'Usa como máximo 2 decimales.');
    });
    test('convierte a string del API', () {
      expect(priceTextToApi('1.5'), '1.50');
      expect(priceTextToApi('1,5'), '1.50');
    });
  });
}
