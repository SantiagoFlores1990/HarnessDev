import '../../orders/domain/order_models.dart';

/// Linea del carrito: payload del API + datos de apoyo para mostrar mientras se cotiza.
class CartLine {
  const CartLine({required this.id, required this.input, this.presetName});
  final String id;
  final PizzaItemInput input;

  /// Nombre de la predefinida (solo para mostrar antes de recibir la cotizacion).
  final String? presetName;

  CartLine withInput(PizzaItemInput value) =>
      CartLine(id: id, input: value, presetName: presetName);
}

/// Carrito en memoria (no persistido).
class CartState {
  const CartState([this.lines = const []]);
  final List<CartLine> lines;

  bool get isEmpty => lines.isEmpty;

  /// Total de pizzas (suma de cantidades), para el badge del menu.
  int get pizzaCount => lines.fold(0, (sum, l) => sum + l.input.quantity);

  List<PizzaItemInput> get inputs => lines.map((l) => l.input).toList();
}

/// Tope de cantidad por linea.
const int maxLineQuantity = 20;
