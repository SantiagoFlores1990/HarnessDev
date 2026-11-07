import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fila (Row) mas cercana que contiene el texto exacto [name].
Finder rowOf(String name) => find.ancestor(of: find.text(name), matching: find.byType(Row)).first;

/// Casilla de la fila del ingrediente [name].
Finder checkboxOf(String name) => find.descendant(of: rowOf(name), matching: find.byType(Checkbox));

/// Boton "+" (agregar una porcion) de la fila [name].
Finder plusOf(String name) => find.descendant(of: rowOf(name), matching: find.widgetWithIcon(IconButton, Icons.add));

/// Boton "-" de la fila [name].
Finder minusOf(String name) => find.descendant(of: rowOf(name), matching: find.widgetWithIcon(IconButton, Icons.remove));

bool isChecked(WidgetTester tester, String name) => tester.widget<Checkbox>(checkboxOf(name)).value == true;

bool isEnabled(WidgetTester tester, Finder iconButton) => tester.widget<IconButton>(iconButton).onPressed != null;

/// Boton "Agregar al pedido" del panel "Tu pizza".
Finder addToOrderButton() => find.widgetWithText(FilledButton, 'Agregar al pedido');

/// Mueve el foco con Tab (recorrido real de teclado) hasta que el foco quede dentro de [target].
/// Falla si no lo alcanza en [maxTabs] pulsaciones.
Future<void> tabUntilFocused(WidgetTester tester, Finder target, {int maxTabs = 80}) async {
  bool focusedInside() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    for (final element in target.evaluate()) {
      if (identical(focusContext, element)) return true;
      var found = false;
      focusContext.visitAncestorElements((ancestor) {
        if (identical(ancestor, element)) {
          found = true;
          return false;
        }
        return true;
      });
      if (found) return true;
    }
    return false;
  }

  for (var i = 0; i < maxTabs; i++) {
    if (focusedInside()) return;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  fail('El foco con Tab no llego a $target en $maxTabs pulsaciones');
}
