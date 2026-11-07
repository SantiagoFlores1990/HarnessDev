import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/page_widgets.dart';
import '../../catalog/domain/catalog_models.dart';
import '../data/orders_repository.dart';
import '../domain/order_models.dart';
import 'orders_table.dart';

/// S-06 Mis pedidos (cliente). Refresco manual: boton y F5.
class MyOrdersPage extends ConsumerStatefulWidget {
  const MyOrdersPage({super.key});

  @override
  ConsumerState<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends ConsumerState<MyOrdersPage> {
  OrdersQuery _query = const OrdersQuery();

  void _reload() => ref.invalidate(ordersListProvider);

  @override
  Widget build(BuildContext context) {
    ref.listen(refreshTickProvider, (_, _) => _reload());
    final orders = ref.watch(ordersListProvider(_query));
    return PageFrame(
      title: 'Mis pedidos',
      actions: [RefreshButton(onPressed: _reload)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatusFilterChips(
            selected: _query.status,
            onChanged: (s) => setState(() => _query = _query.copyWith(status: s, page: 1)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: AsyncValueView<PageResult<OrderSummary>>(
              value: orders,
              onRetry: _reload,
              errorMessage: 'No se pudieron cargar tus pedidos.',
              loading: const SkeletonRows(count: 5, label: 'Cargando tus pedidos'),
              isEmpty: (p) => p.items.isEmpty,
              empty: _query.status != null
                  ? EmptyState(
                      icon: Icons.receipt_long,
                      title: 'No hay pedidos con ese estado.',
                      actionLabel: 'Quitar filtro',
                      onAction: () => setState(() => _query = _query.copyWith(status: null, page: 1)),
                    )
                  : EmptyState(
                      icon: Icons.receipt_long,
                      title: 'Aún no tienes pedidos.',
                      message: 'Cuando confirmes uno, aparecerá aquí con su estado.',
                      actionLabel: 'Ver pizzas predefinidas',
                      onAction: () => context.go('/presets'),
                    ),
              data: (page) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: OrdersTable(
                      orders: page.items,
                      onOpen: (o) => context.go('/orders/${o.id}'),
                    ),
                  ),
                  PaginationBar(
                    page: page.page,
                    totalPages: page.totalPages,
                    onPage: (p) => setState(() => _query = _query.copyWith(page: p)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      'Los pedidos no se pueden cancelar desde la aplicación.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
