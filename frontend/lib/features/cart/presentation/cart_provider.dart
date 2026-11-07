import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/session_provider.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/domain/order_models.dart';
import '../domain/cart_state.dart';

/// Carrito del cliente. Se reinicia al cambiar de usuario o cerrar sesion.
class CartNotifier extends Notifier<CartState> {
  int _seq = 0;

  @override
  CartState build() {
    ref.watch(sessionProvider.select((s) => s.value?.user.id));
    return const CartState();
  }

  String _nextId() => 'line-${_seq++}';

  /// Agrega una linea. Las predefinidas iguales sin extras se fusionan sumando cantidad (max. 20);
  /// las personalizadas nunca se fusionan.
  void add(PizzaItemInput input, {String? presetName}) {
    final lines = [...state.lines];
    final i = lines.indexWhere((l) => l.input.canMergeWith(input));
    if (i >= 0) {
      final merged = (lines[i].input.quantity + input.quantity).clamp(1, maxLineQuantity);
      lines[i] = lines[i].withInput(lines[i].input.withQuantity(merged));
    } else {
      lines.add(CartLine(id: _nextId(), input: input, presetName: presetName));
    }
    state = CartState(lines);
  }

  void setQuantity(String id, int quantity) {
    final q = quantity.clamp(1, maxLineQuantity);
    state = CartState([
      for (final l in state.lines) l.id == id ? l.withInput(l.input.withQuantity(q)) : l,
    ]);
  }

  /// Quita una linea y devuelve (linea, posicion) para poder deshacer.
  (CartLine, int)? remove(String id) {
    final i = state.lines.indexWhere((l) => l.id == id);
    if (i < 0) return null;
    final removed = state.lines[i];
    state = CartState([...state.lines]..removeAt(i));
    return (removed, i);
  }

  void restore(CartLine line, int index) {
    final lines = [...state.lines];
    lines.insert(index.clamp(0, lines.length), line);
    state = CartState(lines);
  }

  void clear() => state = const CartState();

  /// Confirma el pedido con `expectedTotal`. Lanza `ApiException` (409, 422, 403, red...).
  /// Si tiene exito vacia el carrito y devuelve el comprobante.
  Future<OrderDetail> confirm({required String expectedTotal}) async {
    final order = await ref
        .read(ordersRepositoryProvider)
        .create(state.inputs, expectedTotal: expectedTotal);
    clear();
    return order;
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);

/// Cotizacion del carrito completo (totales, IVA y stock agregado). Cancela la anterior
/// cuando el carrito cambia.
final cartQuoteProvider = FutureProvider.autoDispose<QuoteResult?>((ref) async {
  final cart = ref.watch(cartProvider);
  if (cart.isEmpty) return null;
  final cancel = CancelToken();
  ref.onDispose(() => cancel.cancel());
  return ref.watch(ordersRepositoryProvider).quote(cart.inputs, cancelToken: cancel);
});
