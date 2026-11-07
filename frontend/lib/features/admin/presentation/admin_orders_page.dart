import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/page_widgets.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/domain/order_models.dart';
import '../../orders/presentation/orders_table.dart';

final DateFormat _apiDate = DateFormat('yyyy-MM-dd');
final DateFormat _uiDate = DateFormat('dd/MM/yyyy');

/// S-11 Gestion de pedidos (admin, lista).
class AdminOrdersPage extends ConsumerStatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  ConsumerState<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends ConsumerState<AdminOrdersPage> {
  OrdersQuery _query = const OrdersQuery();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _debouncer = Debouncer(const Duration(milliseconds: 300));
  DateTime? _from;
  DateTime? _to;

  bool get _filtering =>
      _query.status != null || _query.search != null || _query.from != null || _query.to != null;

  @override
  void dispose() {
    _debouncer.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _reload() => ref.invalidate(ordersListProvider);

  Future<void> _pickDate({required bool from}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      helpText: from ? 'Desde' : 'Hasta',
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
        _query = _query.copyWith(from: _apiDate.format(picked), page: 1);
      } else {
        _to = picked;
        _query = _query.copyWith(to: _apiDate.format(picked), page: 1);
      }
    });
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _from = null;
      _to = null;
      _query = const OrdersQuery();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(refreshTickProvider, (_, _) => _reload());
    final orders = ref.watch(ordersListProvider(_query));
    return PageFrame(
      title: 'Pedidos',
      actions: [RefreshButton(onPressed: _reload)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  decoration: const InputDecoration(
                    labelText: 'Nº de orden o email',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => _debouncer.run(() => setState(
                      () => _query = _query.copyWith(search: v.trim().isEmpty ? null : v.trim(), page: 1))),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDate(from: true),
                icon: const Icon(Icons.event, size: 20),
                label: Text('Desde: ${_from == null ? 'dd/mm/aaaa' : _uiDate.format(_from!)}'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDate(from: false),
                icon: const Icon(Icons.event, size: 20),
                label: Text('Hasta: ${_to == null ? 'dd/mm/aaaa' : _uiDate.format(_to!)}'),
              ),
              if (_filtering) TextButton(onPressed: _clearFilters, child: const Text('Limpiar filtros')),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          StatusFilterChips(
            selected: _query.status,
            onChanged: (s) => setState(() => _query = _query.copyWith(status: s, page: 1)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: AsyncValueView<PageResult<OrderSummary>>(
              value: orders,
              onRetry: _reload,
              errorMessage: 'No se pudieron cargar los pedidos.',
              loading: const SkeletonRows(count: 6, label: 'Cargando pedidos'),
              isEmpty: (p) => p.items.isEmpty,
              empty: _filtering
                  ? EmptyState(
                      icon: Icons.receipt_long,
                      title: 'Ningún pedido coincide con los filtros.',
                      actionLabel: 'Limpiar filtros',
                      onAction: _clearFilters,
                    )
                  : const EmptyState(icon: Icons.receipt_long, title: 'No hay pedidos todavía.'),
              data: (page) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: OrdersTable(
                      orders: page.items,
                      showCustomer: true,
                      onOpen: (o) => context.go('/admin/orders/${o.id}'),
                    ),
                  ),
                  PaginationBar(
                    page: page.page,
                    totalPages: page.totalPages,
                    onPage: (p) => setState(() => _query = _query.copyWith(page: p)),
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
