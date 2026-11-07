import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/display_widgets.dart';
import '../../../core/widgets/page_widgets.dart';
import '../../catalog/domain/catalog_models.dart';
import '../data/orders_repository.dart';
import '../domain/order_models.dart';

/// Pagina de pedidos segun filtros (cliente: solo propios; admin: todos).
final ordersListProvider = FutureProvider.autoDispose.family<PageResult<OrderSummary>, OrdersQuery>(
    (ref, query) => ref.watch(ordersRepositoryProvider).list(query));

/// Tabla de pedidos con filas de 52 px, hover y apertura con clic o Enter.
class OrdersTable extends StatelessWidget {
  const OrdersTable({super.key, required this.orders, required this.onOpen, this.showCustomer = false});

  final List<OrderSummary> orders;
  final ValueChanged<OrderSummary> onOpen;
  final bool showCustomer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final headerStyle = theme.textTheme.titleSmall;

    Widget cells(List<Widget> children, {List<int>? flex}) => Row(
          children: [
            for (var i = 0; i < children.length; i++)
              Expanded(flex: (flex ?? const [])[i], child: children[i]),
          ],
        );

    final flex = showCustomer ? const [3, 3, 3, 1, 2, 3, 1] : const [3, 3, 1, 2, 3, 1];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: c.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: cells([
              Text('Nº de orden', style: headerStyle),
              Text('Fecha', style: headerStyle),
              if (showCustomer) Text('Cliente', style: headerStyle),
              Text('Pizzas', style: headerStyle),
              Text('Total', style: headerStyle),
              Text('Estado', style: headerStyle),
              const SizedBox.shrink(),
            ], flex: flex),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: orders.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, i) {
                final o = orders[i];
                return HoverRow(
                  onTap: () => onOpen(o),
                  semanticsLabel:
                      'Pedido ${o.orderNumber}, ${o.status.label}, total ${formatMoney(o.total)}',
                  child: cells([
                    Text(o.orderNumber, style: tabular(theme.textTheme.bodyMedium)),
                    Text(formatDateTime(o.createdAt), style: tabular(theme.textTheme.bodyMedium)),
                    if (showCustomer)
                      Text(o.customer.fullName, overflow: TextOverflow.ellipsis),
                    Text('${o.pizzaCount}', style: tabular(theme.textTheme.bodyMedium)),
                    MoneyText(o.total),
                    Align(alignment: Alignment.centerLeft, child: OrderStatusChip(o.status)),
                    const Align(alignment: Alignment.centerRight, child: Icon(Icons.chevron_right)),
                  ], flex: flex),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}

/// Chips de filtro por estado ("Todos" + 3 estados).
class StatusFilterChips extends StatelessWidget {
  const StatusFilterChips({super.key, required this.selected, required this.onChanged});
  final OrderStatus? selected;
  final ValueChanged<OrderStatus?> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Estado:'),
          ChoiceChip(
            label: const Text('Todos'),
            selected: selected == null,
            onSelected: (_) => onChanged(null),
          ),
          for (final s in OrderStatus.values)
            ChoiceChip(
              label: Text(s.label),
              selected: selected == s,
              onSelected: (_) => onChanged(s),
            ),
        ],
      );
}
