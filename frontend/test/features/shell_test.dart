import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:good_pizza/core/theme/app_theme.dart';
import 'package:good_pizza/core/widgets/feedback_widgets.dart';
import 'package:good_pizza/core/widgets/good_pizza_logo.dart';
import 'package:good_pizza/features/cart/presentation/cart_provider.dart';
import 'package:good_pizza/features/orders/domain/order_models.dart';

import '../helpers/fakes.dart';
import '../helpers/finders.dart';
import '../helpers/pump_app.dart';

List<String> railLabels(WidgetTester tester) => tester
    .widget<NavigationRail>(find.byType(NavigationRail))
    .destinations
    .map((d) => (d.label as Text).data!)
    .toList();

Future<void> shortcut(WidgetTester tester, LogicalKeyboardKey key,
    {bool control = false, bool shift = false, bool alt = false}) async {
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(key);
  if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void main() {
  group('logotipo', () {
    testWidgets('WT-02 GoodPizzaLogo renderiza el SVG y el texto "Good Pizza" como Text real', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(body: Center(child: GoodPizzaLogo())),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(SvgPicture), findsOneWidget);
      expect(find.text('Good Pizza'), findsOneWidget);
      expect(find.byType(Text), findsOneWidget, reason: 'el nombre no va dentro del SVG (<text>)');
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svg.width, 128);
    });

    testWidgets('variantes de tamano y logotipo solo emblema con etiqueta semantica', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(body: Column(children: [
          GoodPizzaLogo(variant: LogoVariant.receipt),
          GoodPizzaLogo(variant: LogoVariant.railCompact, showText: false),
        ])),
      ));
      await tester.pumpAndSettle();
      final sizes = tester.widgetList<SvgPicture>(find.byType(SvgPicture)).map((s) => s.width).toList();
      expect(sizes, [56, 32]);
      expect(find.bySemanticsLabel('Good Pizza'), findsWidgets);
    });
  });

  group('AppShell', () {
    testWidgets('WT-03 cliente: NavigationRail con 4 destinos y sin barra inferior', (tester) async {
      await pumpGoodPizza(tester, FakeBackend());
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(railLabels(tester), ['Pizzas predefinidas', 'Personalizar pizza', 'Mi pedido', 'Mis pedidos']);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('Cliente'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
    });

    testWidgets('WT-03 administrador: 3 destinos', (tester) async {
      await pumpGoodPizza(tester, FakeBackend(user: FakeAuthRepository.adminUser));
      expect(railLabels(tester), ['Ingredientes', 'Pizzas predefinidas', 'Pedidos']);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.text('Administrador'), findsOneWidget);
    });

    testWidgets('el destino seleccionado sigue la ruta (incluida una ruta hija)', (tester) async {
      final backend = FakeBackend();
      await pumpGoodPizza(tester, backend);
      int selected() => tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex!;
      expect(selected(), 0);
      await goTo(tester, '/cart');
      expect(selected(), 2);
      await goTo(tester, '/orders/loquesea');
      expect(selected(), 3, reason: 'el detalle mantiene "Mis pedidos"');
    });

    testWidgets('badge de "Mi pedido" con el numero de pizzas', (tester) async {
      final container = await pumpGoodPizza(tester, FakeBackend());
      expect(find.byType(Badge), findsNothing);
      container.read(cartProvider.notifier)
        ..add(const PizzaItemInput(type: 'PRESET', presetPizzaId: 'margherita', sizeCode: 'MEDIUM', quantity: 2))
        ..add(const PizzaItemInput(type: 'PRESET', presetPizzaId: 'pepperoni', sizeCode: 'MEDIUM'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(Badge), matching: find.text('3')), findsOneWidget);
    });

    testWidgets('cerrar sesion pide confirmacion y avisa si hay pizzas sin confirmar', (tester) async {
      final backend = FakeBackend();
      final container = await pumpGoodPizza(tester, backend);
      container.read(cartProvider.notifier)
          .add(const PizzaItemInput(type: 'PRESET', presetPizzaId: 'margherita', sizeCode: 'MEDIUM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tu pedido tiene pizzas sin confirmar'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(backend.auth.logoutCalls, 0);
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(backend.auth.logoutCalls, 1);
      expect(find.text('Crear cuenta'), findsOneWidget);
      // el carrito se vacia al cerrar sesion
      expect(container.read(cartProvider).isEmpty, isTrue);
    });
  });

  group('WT-28 responsive', () {
    testWidgets('rail compacto a 1100 px (icono + etiqueta) y 2 columnas de predefinidas', (tester) async {
      await pumpGoodPizza(tester, FakeBackend(), size: const Size(1100, 800), textScale: 0.5);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse);
      expect(rail.labelType, NavigationRailLabelType.all);
      expect(find.text('Cerrar sesión'), findsNothing, reason: 'compacto: solo "Salir"');
      expect(find.text('Salir'), findsOneWidget);
      final xs = {for (final n in ['Margarita', 'Pepperoni', 'Hawaiana', 'Vegetariana', '4 Quesos']) n: tester.getTopLeft(find.text(n)).dx};
      final ys = {for (final n in ['Margarita', 'Pepperoni', 'Hawaiana']) n: tester.getTopLeft(find.text(n)).dy};
      expect(ys['Margarita'], ys['Pepperoni'], reason: 'la fila tiene 2 tarjetas');
      expect(ys['Hawaiana'], greaterThan(ys['Margarita']!), reason: 'la 3a pasa a la segunda fila');
      expect(xs['Hawaiana'], xs['Margarita']);
    });

    testWidgets('rail extendido a 1400 px y 3 columnas', (tester) async {
      await pumpGoodPizza(tester, FakeBackend(), size: const Size(1400, 900));
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      double y(String n) => tester.getTopLeft(find.text(n)).dy;
      expect(y('Margarita'), y('Pepperoni'));
      expect(y('Pepperoni'), y('Hawaiana'), reason: '3 tarjetas por fila');
      expect(y('Vegetariana'), greaterThan(y('Margarita')));
    });

    testWidgets('4 columnas a partir de 1600 px', (tester) async {
      await pumpGoodPizza(tester, FakeBackend(), size: const Size(1700, 900));
      double y(String n) => tester.getTopLeft(find.text(n)).dy;
      expect(y('Vegetariana'), y('Margarita'));
      expect(y('4 Quesos'), greaterThan(y('Margarita')));
    });

    testWidgets('a 1100 px el panel "Tu pizza" pasa a barra inferior; a 1400 px es lateral', (tester) async {
      await pumpGoodPizza(tester, FakeBackend(), size: const Size(1100, 800), textScale: 0.5, location: '/builder');
      await settleQuote(tester);
      final compactPanel = tester.getTopLeft(find.text('TU PIZZA'));
      final form = tester.getTopLeft(find.text('1. Tamaño'));
      expect(compactPanel.dy, greaterThan(form.dy), reason: 'barra inferior: debajo del formulario');
      expect(tester.takeException(), isNull);
    });

    testWidgets('el panel lateral a 1400 px esta a la derecha del formulario', (tester) async {
      await pumpGoodPizza(tester, FakeBackend(), location: '/builder');
      await settleQuote(tester);
      expect(tester.getTopLeft(find.text('TU PIZZA')).dx, greaterThan(tester.getTopLeft(find.text('1. Tamaño')).dx + 500));
    });

    testWidgets('redimensionar no pierde la seleccion del armado (estado en providers)', (tester) async {
      await pumpGoodPizza(tester, FakeBackend(), size: const Size(1400, 900), location: '/builder');
      await settleQuote(tester);
      await tester.tap(checkboxOf('Masa tradicional'));
      await tester.pump();
      tester.view.physicalSize = const Size(1100, 800);
      await tester.pumpAndSettle();
      expect(isChecked(tester, 'Masa tradicional'), isTrue);
    });
  });

  group('WT-27 atajos de teclado', () {
    testWidgets('Ctrl+1..4 cambian de destino', (tester) async {
      await pumpGoodPizza(tester, FakeBackend());
      await shortcut(tester, LogicalKeyboardKey.digit4, control: true);
      expect(find.text('Aún no tienes pedidos.'), findsOneWidget);
      await shortcut(tester, LogicalKeyboardKey.digit3, control: true);
      expect(find.text('Tu pedido está vacío.'), findsOneWidget);
      await shortcut(tester, LogicalKeyboardKey.digit2, control: true);
      expect(find.text('1. Tamaño'), findsOneWidget);
      await shortcut(tester, LogicalKeyboardKey.digit1, control: true);
      expect(find.text('Margarita'), findsOneWidget);
    });

    testWidgets('F5 y Ctrl+R recargan la pantalla actual', (tester) async {
      final backend = FakeBackend();
      await pumpGoodPizza(tester, backend);
      final before = backend.presets.listCalls;
      await shortcut(tester, LogicalKeyboardKey.f5);
      expect(backend.presets.listCalls, before + 1);
      await shortcut(tester, LogicalKeyboardKey.keyR, control: true);
      expect(backend.presets.listCalls, before + 2);
    });

    testWidgets('F1 muestra la ayuda de atajos y Esc la cierra', (tester) async {
      await pumpGoodPizza(tester, FakeBackend());
      await shortcut(tester, LogicalKeyboardKey.f1);
      expect(find.text('Atajos de teclado'), findsOneWidget);
      expect(find.text('Ctrl+Enter'), findsOneWidget);
      await shortcut(tester, LogicalKeyboardKey.escape);
      expect(find.text('Atajos de teclado'), findsNothing);
    });

    testWidgets('Ctrl+Enter agrega la pizza (S-04) y confirma el pedido (S-05)', (tester) async {
      final backend = FakeBackend();
      final container = await pumpGoodPizza(tester, backend, location: '/builder');
      await settleQuote(tester);
      for (final n in ['Masa tradicional', 'Salsa de tomate', 'Queso mozzarella', 'Jamón', 'Pepperoni']) {
        await tester.tap(checkboxOf(n));
      }
      await settleQuote(tester);
      await shortcut(tester, LogicalKeyboardKey.enter, control: true);
      expect(container.read(cartProvider).pizzaCount, 1);
      expect(find.text('Pizza agregada'), findsOneWidget);

      await goTo(tester, '/cart');
      await settleQuote(tester);
      await shortcut(tester, LogicalKeyboardKey.enter, control: true);
      expect(find.textContaining('¿Confirmar el pedido por'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
      await tester.pumpAndSettle();
      expect(backend.orders.createCalls.length, 1);
    });

    testWidgets('Ctrl+Enter no agrega una pizza invalida', (tester) async {
      final container = await pumpGoodPizza(tester, FakeBackend(), location: '/builder');
      await settleQuote(tester);
      await shortcut(tester, LogicalKeyboardKey.enter, control: true);
      expect(container.read(cartProvider).isEmpty, isTrue);
    });

    testWidgets('admin: Ctrl+N abre el formulario, Ctrl+S guarda, Alt+Izquierda vuelve', (tester) async {
      final backend = FakeBackend(user: FakeAuthRepository.adminUser);
      await pumpGoodPizza(tester, backend);
      await shortcut(tester, LogicalKeyboardKey.keyN, control: true);
      expect(find.text('Guardar ingrediente'), findsOneWidget);

      await shortcut(tester, LogicalKeyboardKey.arrowLeft, alt: true);
      expect(find.text('Guardar ingrediente'), findsNothing);
      expect(find.text('Nuevo ingrediente'), findsOneWidget);

      await shortcut(tester, LogicalKeyboardKey.keyN, control: true);
      Finder field(String l) => find.widgetWithText(TextFormField, l);
      await tester.enterText(field('Código'), 'ZZ-1');
      await tester.enterText(field('Nombre'), 'Prueba');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Carne').last);
      await tester.pumpAndSettle();
      for (final s in ['Individual', 'Mediana', 'Familiar']) {
        await tester.enterText(field('Precio (USD) $s'), '1.00');
        await tester.enterText(field('Calorías (kcal) $s'), '10');
      }
      await shortcut(tester, LogicalKeyboardKey.keyS, control: true);
      expect(backend.catalog.created.single.code, 'ZZ-1');
    });

    testWidgets('Ctrl+Shift+Q abre la confirmacion de cierre de sesion', (tester) async {
      await pumpGoodPizza(tester, FakeBackend());
      await shortcut(tester, LogicalKeyboardKey.keyQ, control: true, shift: true);
      expect(find.text('¿Quieres cerrar sesión?'), findsOneWidget);
    });

    testWidgets('admin: Ctrl+Enter avanza el estado del pedido (con confirmacion)', (tester) async {
      final backend = FakeBackend(user: FakeAuthRepository.adminUser);
      final order = OrderDetail.fromJson(backend.server.orderJson(const [
        PizzaItemInput(type: 'PRESET', presetPizzaId: 'margherita', sizeCode: 'MEDIUM'),
      ]));
      backend.orders.orders[order.id] = order;
      await pumpGoodPizza(tester, backend, location: '/admin/orders/${order.id}');
      await shortcut(tester, LogicalKeyboardKey.enter, control: true);
      expect(find.textContaining('¿Pasar el pedido'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
      await tester.pumpAndSettle();
      expect(backend.orders.statusCalls.single.status, OrderStatus.inPreparation);
    });
  });

  group('WT-26 recorrido solo con teclado', () {
    testWidgets('agregar predefinida (Enter), ir al pedido (Ctrl+3) y confirmar (Ctrl+Enter, Tab, Enter)',
        (tester) async {
      final backend = FakeBackend();
      await pumpGoodPizza(tester, backend);

      // Tab hasta "Agregar al pedido" de Margarita y activacion con Enter
      final addButton = find.widgetWithText(FilledButton, 'Agregar al pedido').first;
      await tabUntilFocused(tester, addButton);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Pizza agregada'), findsOneWidget);

      // Ctrl+3 -> Mi pedido
      await shortcut(tester, LogicalKeyboardKey.digit3, control: true);
      await settleQuote(tester);
      expect(find.text('Resumen del pedido'), findsOneWidget);

      // Ctrl+Enter abre el dialogo con foco en "Cancelar"; Tab pasa a "Confirmar"; Enter confirma
      await shortcut(tester, LogicalKeyboardKey.enter, control: true);
      expect(find.textContaining('¿Confirmar el pedido por'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(backend.orders.createCalls.length, 1);
      expect(find.text('TOTAL (USD)'), findsOneWidget);
    });

    testWidgets('Esc cancela el dialogo de confirmacion sin crear el pedido', (tester) async {
      final backend = FakeBackend();
      final container = await pumpGoodPizza(tester, backend);
      container.read(cartProvider.notifier)
          .add(const PizzaItemInput(type: 'PRESET', presetPizzaId: 'margherita', sizeCode: 'MEDIUM'));
      await goTo(tester, '/cart');
      await settleQuote(tester);
      await shortcut(tester, LogicalKeyboardKey.enter, control: true);
      expect(find.textContaining('¿Confirmar el pedido por'), findsOneWidget);
      await shortcut(tester, LogicalKeyboardKey.escape);
      expect(find.textContaining('¿Confirmar el pedido por'), findsNothing);
      expect(backend.orders.createCalls, isEmpty);
    });

    testWidgets('espacio marca la casilla enfocada y las flechas cambian porciones', (tester) async {
      await pumpGoodPizza(tester, FakeBackend(), location: '/builder');
      await settleQuote(tester);
      await tabUntilFocused(tester, checkboxOf('Queso mozzarella'));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(isChecked(tester, 'Queso mozzarella'), isTrue);

      await tabUntilFocused(tester, plusOf('Queso mozzarella'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(find.descendant(of: rowOf('Queso mozzarella'), matching: find.text('2')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(find.descendant(of: rowOf('Queso mozzarella'), matching: find.text('1')), findsOneWidget);
    });
  });

  group('WT-24 AsyncValueView', () {
    Widget host(AsyncValue<List<String>> value, {VoidCallback? onRetry}) => MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: AsyncValueView<List<String>>(
              value: value,
              onRetry: onRetry,
              errorMessage: 'No se pudo cargar.',
              isEmpty: (l) => l.isEmpty,
              empty: const EmptyState(icon: Icons.inbox, title: 'No hay nada.', actionLabel: 'Crear'),
              data: (l) => Text('datos: ${l.join(',')}'),
            ),
          ),
        );

    testWidgets('cargando', (tester) async {
      await tester.pumpWidget(host(const AsyncLoading()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Cargando…'), findsOneWidget);
    });

    testWidgets('vacio con accion', (tester) async {
      await tester.pumpWidget(host(const AsyncData(<String>[])));
      expect(find.text('No hay nada.'), findsOneWidget);
      expect(find.text('Crear'), findsOneWidget);
    });

    testWidgets('con datos', (tester) async {
      await tester.pumpWidget(host(const AsyncData(['a', 'b'])));
      expect(find.text('datos: a,b'), findsOneWidget);
    });

    testWidgets('error con Reintentar', (tester) async {
      var retries = 0;
      await tester.pumpWidget(host(AsyncError(apiError('INTERNAL_ERROR', status: 500), StackTrace.empty), onRetry: () => retries++));
      expect(find.text('No se pudo cargar.'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      expect(retries, 1);
    });

    testWidgets('error de red muestra el mensaje de conexion', (tester) async {
      await tester.pumpWidget(host(AsyncError(apiError('NETWORK_ERROR'), StackTrace.empty), onRetry: () {}));
      expect(find.textContaining('No se pudo conectar con el servidor.'), findsOneWidget);
    });
  });
}
