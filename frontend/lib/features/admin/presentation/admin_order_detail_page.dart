import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/display_widgets.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/page_widgets.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/domain/order_models.dart';
import '../../orders/presentation/orders_table.dart';
import '../../orders/presentation/receipt_view.dart';

/// S-12 Pedido (admin): comprobante y cambio de estado.
class AdminOrderDetailPage extends ConsumerStatefulWidget {
  const AdminOrderDetailPage({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<AdminOrderDetailPage> createState() => _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends ConsumerState<AdminOrderDetailPage> {
  bool _busy = false;

  void _reload() => ref.invalidate(orderDetailProvider(widget.orderId));

  Future<void> _advance(OrderDetail order) async {
    final next = order.status.next;
    if (next == null || _busy) return;
    final text = next == OrderStatus.inPreparation
        ? '¿Pasar el pedido ${order.orderNumber} a En preparación? Esta acción no se puede deshacer.'
        : '¿Marcar el pedido ${order.orderNumber} como Entregado? Esta acción no se puede deshacer.';
    final ok = await showConfirmDialog(context, title: 'Cambiar estado', message: text, confirmLabel: 'Confirmar');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(ordersRepositoryProvider).updateStatus(order.id, next);
      ref.invalidate(ordersListProvider);
      _reload();
      if (mounted) showAppSnack(context, 'Estado actualizado: ${next.label}');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false); // antes de abrir dialogos, para no dejar el indicador girando
      switch (e.code) {
        case ErrorCodes.invalidTransition:
          await showInfoDialog(
            context,
            title: 'El pedido ya cambió de estado',
            content: const Text('El pedido ya cambió de estado. Actualiza para ver el estado actual.'),
            actionLabel: 'Actualizar',
          );
          _reload();
        case ErrorCodes.notFound:
          showAppSnack(context, 'El pedido ya no está disponible.');
          context.go('/admin/orders');
        case ErrorCodes.forbidden:
          showAppSnack(context, 'No tienes permiso para esta acción.');
        default:
          showAppSnack(context, e.userMessage);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(refreshTickProvider, (_, _) => _reload());
    final detail = ref.watch(orderDetailProvider(widget.orderId));
    final sideLayout = MediaQuery.sizeOf(context).width >= Breakpoints.standardMin;
    final order = detail.value;

    return PageShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (order != null) _advance(order);
        },
      },
      child: PageFrame(
        title: order == null ? 'Pedido' : 'Pedido ${order.orderNumber}',
        leading: TextButton.icon(
          onPressed: () => context.go('/admin/orders'),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Pedidos'),
        ),
        actions: [RefreshButton(onPressed: _reload)],
        child: AsyncValueView<OrderDetail>(
          value: detail,
          onRetry: _reload,
          errorMessage: 'No se pudo cargar el pedido.',
          loading: const SkeletonRows(count: 6, height: 72, label: 'Cargando el pedido'),
          notFound: EmptyState(
            icon: Icons.search_off,
            title: 'El pedido ya no está disponible.',
            actionLabel: 'Volver a Pedidos',
            onAction: () => context.go('/admin/orders'),
          ),
          data: (o) {
            final panel = _StatusPanel(order: o, busy: _busy, onAdvance: () => _advance(o));
            final receipt = Center(child: ReceiptView(order: o));
            return sideLayout
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.only(bottom: AppSpacing.xl), child: receipt)),
                      const SizedBox(width: AppSpacing.lg),
                      SizedBox(width: 320, child: SingleChildScrollView(child: panel)),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                    children: [panel, const SizedBox(height: AppSpacing.md), receipt],
                  );
          },
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.order, required this.busy, required this.onAdvance});
  final OrderDetail order;
  final bool busy;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = order.status.next;
    final label = switch (order.status) {
      OrderStatus.pending => 'Pasar a En preparación',
      OrderStatus.inPreparation => 'Marcar como Entregado',
      OrderStatus.delivered => '',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('GESTIÓN DEL ESTADO',
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.secondary)),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.xs,
              children: [const Text('Estado actual:'), OrderStatusChip(order.status)],
            ),
            const SizedBox(height: AppSpacing.md),
            if (next != null)
              Tooltip(
                message: '$label (Ctrl+Enter)',
                child: FilledButton(
                  onPressed: busy ? null : onAdvance,
                  child: busy
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text('Actualizando…'),
                          ],
                        )
                      : Text(label),
                ),
              )
            else
              const Text('Este pedido ya fue entregado. No admite más cambios.'),
            const SizedBox(height: AppSpacing.md),
            Text('Historial', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            if (order.statusHistory.isEmpty)
              Text('Sin cambios registrados.', style: theme.textTheme.bodyMedium)
            else
              for (final h in order.statusHistory)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '· ${h.toStatus.label} — ${formatDateTime(h.changedAt)}${h.changedByName == null ? '' : ' (${h.changedByName})'}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
