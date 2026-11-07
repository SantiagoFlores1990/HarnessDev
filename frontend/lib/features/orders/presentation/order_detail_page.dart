import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/page_widgets.dart';
import '../data/orders_repository.dart';
import '../domain/order_models.dart';
import 'receipt_view.dart';

/// S-13 Detalle del pedido y comprobante (cliente dueno).
class OrderDetailPage extends ConsumerWidget {
  const OrderDetailPage({super.key, required this.orderId, this.justConfirmed = false});

  final String orderId;
  final bool justConfirmed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void reload() => ref.invalidate(orderDetailProvider(orderId));
    ref.listen(refreshTickProvider, (_, _) => reload());
    final detail = ref.watch(orderDetailProvider(orderId));

    return PageFrame(
      title: detail.value == null ? 'Pedido' : 'Pedido ${detail.value!.orderNumber}',
      leading: TextButton.icon(
        onPressed: () => context.go('/orders'),
        icon: const Icon(Icons.arrow_back),
        label: const Text('Mis pedidos'),
      ),
      actions: [RefreshButton(onPressed: reload)],
      maxWidth: 800,
      child: AsyncValueView<OrderDetail>(
        value: detail,
        onRetry: reload,
        errorMessage: 'No se pudo cargar el pedido.',
        loading: const SkeletonRows(count: 6, height: 72, label: 'Cargando el pedido'),
        notFound: EmptyState(
          icon: Icons.search_off,
          title: 'No encontramos este pedido.',
          message: 'Puede que no exista o que no sea tuyo.',
          actionLabel: 'Volver a Mis pedidos',
          onAction: () => context.go('/orders'),
        ),
        data: (order) => SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (justConfirmed) ...[
                NoticeBanner(
                  kind: NoticeKind.success,
                  message:
                      'Pedido ${order.orderNumber} confirmado. Lo estamos preparando; el estado cambiará aquí.',
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Center(child: ReceiptView(order: order)),
            ],
          ),
        ),
      ),
    );
  }
}
