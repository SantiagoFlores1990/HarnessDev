import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('WT-07 S-03 lista 5 predefinidas; la no disponible deshabilita botones; el tamano cambia precios',
      (tester) async {
    final backend = FakeBackend();
    await pumpGoodPizza(tester, backend);

    expect(find.text('Pizzas predefinidas'), findsWidgets);
    for (final name in ['Margarita', 'Pepperoni', 'Hawaiana', 'Vegetariana', '4 Quesos']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('No disponible'), findsOneWidget);
    expect(find.text('La pizza Hawaiana no está disponible: falta Piña.'), findsOneWidget);

    final personalize = tester.widgetList<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Personalizar')).toList();
    final add = tester.widgetList<FilledButton>(find.widgetWithText(FilledButton, 'Agregar al pedido')).toList();
    expect(personalize.length, 5);
    expect(add.where((b) => b.onPressed == null).length, 1);
    expect(personalize.where((b) => b.onPressed == null).length, 1);

    // Mediana (por defecto): Margarita = masa 2.00 + salsa 1.00 + queso 1.50 x2 = 6.00
    expect(find.text('\$ 6.00'), findsOneWidget);
    await tester.tap(find.text('Familiar'));
    await tester.pumpAndSettle();
    // Familiar: 3.00 + 1.50 + 2.25 x2 = 9.00
    expect(find.text('\$ 9.00'), findsOneWidget);
    expect(find.text('\$ 6.00'), findsNothing);
    expect(backend.presets.listCalls, 1, reason: 'cambiar de tamano no pide de nuevo al API');
  });
}
