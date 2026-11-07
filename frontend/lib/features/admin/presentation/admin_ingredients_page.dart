import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/display_widgets.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/page_widgets.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/catalog_models.dart';
import 'stock_dialog.dart';

/// Filtro de la lista de ingredientes (record con igualdad por valor).
typedef IngredientFilter = ({String search, String? category, bool includeInactive});

/// Lista de ingredientes para el ADMIN: siempre envia `includeInactive=true` al mostrar inactivos.
final adminIngredientsProvider = FutureProvider.autoDispose.family<List<Ingredient>, IngredientFilter>(
  (ref, f) => ref.watch(catalogRepositoryProvider).ingredients(
        category: f.category,
        search: f.search,
        includeInactive: f.includeInactive,
      ),
);

/// S-07 Ingredientes (admin).
class AdminIngredientsPage extends ConsumerStatefulWidget {
  const AdminIngredientsPage({super.key});

  @override
  ConsumerState<AdminIngredientsPage> createState() => _AdminIngredientsPageState();
}

class _AdminIngredientsPageState extends ConsumerState<AdminIngredientsPage> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _debouncer = Debouncer(const Duration(milliseconds: 300));
  String _search = '';
  String? _category;
  bool _includeInactive = true;

  IngredientFilter get _filter => (search: _search, category: _category, includeInactive: _includeInactive);

  @override
  void dispose() {
    _debouncer.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _reload() => ref.invalidate(adminIngredientsProvider);

  Future<void> _toggleActive(Ingredient i, bool active) async {
    if (!active) {
      final ok = await showConfirmDialog(
        context,
        title: 'Desactivar ingrediente',
        message:
            '¿Desactivar ${i.name}? Dejará de ofrecerse a los clientes y las pizzas predefinidas que lo usan quedarán no disponibles. Los pedidos anteriores no cambian.',
        confirmLabel: 'Desactivar',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    try {
      await ref.read(catalogRepositoryProvider).setIngredientActive(i.id, active);
      _reload();
      if (mounted) showAppSnack(context, active ? 'Ingrediente activado' : 'Ingrediente desactivado');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == ErrorCodes.missingSizeValues) {
        final router = GoRouter.of(context);
        showAppSnack(context, 'No se puede activar: faltan precio y calorías de algún tamaño.',
            actionLabel: 'Editar', onAction: () => router.go('/admin/ingredients/${i.id}'));
      } else {
        showAppSnack(context, e.userMessage);
      }
      _reload();
    }
  }

  Future<void> _adjustStock(Ingredient i) async {
    final changed = await showStockDialog(context, i);
    if (changed) {
      _reload();
      if (mounted) showAppSnack(context, 'Stock actualizado');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(refreshTickProvider, (_, _) => _reload());
    final list = ref.watch(adminIngredientsProvider(_filter));
    final categories = ref.watch(categoriesProvider).value ?? const <IngredientCategory>[];
    final filtering = _search.isNotEmpty || _category != null;
    final compact = MediaQuery.sizeOf(context).width < Breakpoints.standardMin;

    return PageShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () => context.go('/admin/ingredients/new'),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _searchFocus.requestFocus,
      },
      child: PageFrame(
        title: 'Ingredientes',
        actions: [
          Tooltip(
            message: 'Nuevo ingrediente (Ctrl+N)',
            child: FilledButton.icon(
              onPressed: () => context.go('/admin/ingredients/new'),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Nuevo ingrediente'),
            ),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    decoration: const InputDecoration(
                      labelText: 'Buscar por código o nombre',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => _debouncer.run(() => setState(() => _search = v.trim())),
                    onTapOutside: (_) {},
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                      for (final c in categories) DropdownMenuItem<String?>(value: c.code, child: Text(c.name)),
                    ],
                    onChanged: (v) => setState(() => _category = v),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      label: 'Mostrar inactivos',
                      child: Switch(
                        value: _includeInactive,
                        onChanged: (v) => setState(() => _includeInactive = v),
                      ),
                    ),
                    const Text('Mostrar inactivos'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: AsyncValueView<List<Ingredient>>(
                value: list,
                onRetry: _reload,
                errorMessage: 'No se pudo cargar el catálogo.',
                loading: const SkeletonRows(count: 6, label: 'Cargando ingredientes'),
                isEmpty: (l) => l.isEmpty,
                empty: filtering
                    ? EmptyState(
                        icon: Icons.search_off,
                        title: 'Ningún ingrediente coincide con la búsqueda.',
                        actionLabel: 'Limpiar filtros',
                        onAction: () => setState(() {
                          _search = '';
                          _category = null;
                          _searchController.clear();
                        }),
                      )
                    : EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'Aún no hay ingredientes.',
                        actionLabel: 'Crear ingrediente',
                        onAction: () => context.go('/admin/ingredients/new'),
                      ),
                data: (items) => _IngredientsTable(
                  items: items,
                  compact: compact,
                  onEdit: (i) => context.go('/admin/ingredients/${i.id}'),
                  onStock: _adjustStock,
                  onActive: _toggleActive,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientsTable extends StatelessWidget {
  const _IngredientsTable({
    required this.items,
    required this.compact,
    required this.onEdit,
    required this.onStock,
    required this.onActive,
  });

  final List<Ingredient> items;
  final bool compact;
  final ValueChanged<Ingredient> onEdit;
  final ValueChanged<Ingredient> onStock;
  final void Function(Ingredient, bool) onActive;

  static const _sizeOrder = ['INDIVIDUAL', 'MEDIUM', 'FAMILY'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final head = theme.textTheme.titleSmall;
    final flex = compact ? const [3, 2, 2, 2, 4, 2, 1] : const [2, 3, 2, 2, 2, 2, 2, 2, 2, 1];

    // La ultima celda (acciones) tiene ancho fijo de 56 px para conservar el objetivo de toque de 48 px.
    Widget row(List<Widget> cells) => Row(
          children: [
            for (var i = 0; i < cells.length - 1; i++) Expanded(flex: flex[i], child: cells[i]),
            SizedBox(width: 56, child: cells.last),
          ],
        );

    String sizeCell(Ingredient i, String size) {
      final v = i.valueFor(size);
      return v == null ? '—' : '${normalizeDecimal(v.price)} · ${v.calories}';
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: c.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: row([
              if (!compact) Text('Código', style: head),
              Text('Nombre', style: head),
              Text('Categoría', style: head),
              Text('IVA', style: head),
              Text('Stock', style: head),
              if (compact) Text('Individual / Mediana / Familiar', style: head) else ...[
                Text('Individual', style: head),
                Text('Mediana', style: head),
                Text('Familiar', style: head),
              ],
              Text('Activo', style: head),
              const SizedBox.shrink(),
            ]),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final i = items[index];
                final muted = i.active ? null : c.onSurfaceVariant;
                final body = theme.textTheme.bodyMedium?.copyWith(color: muted);
                return HoverRow(
                  onTap: () => onEdit(i),
                  height: compact ? 72 : 52,
                  semanticsLabel: 'Editar ${i.name}',
                  child: row([
                    if (!compact) Text(i.code, style: tabular(body)),
                    Row(children: [
                      Flexible(child: Text(i.name, style: body, overflow: TextOverflow.ellipsis)),
                      if (!i.active) ...[const SizedBox(width: 6), const NeutralChip('Inactivo')],
                    ]),
                    Text(i.categoryName, style: body, overflow: TextOverflow.ellipsis),
                    Align(alignment: Alignment.centerLeft, child: NeutralChip('IVA ${formatPercent(i.vatRatePercent)}')),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Tooltip(
                        message: 'Ajustar stock',
                        child: TextButton(
                          onPressed: () => onStock(i),
                          style: TextButton.styleFrom(minimumSize: const Size(48, 36), padding: const EdgeInsets.symmetric(horizontal: 8)),
                          child: i.stock <= 0
                              ? const StockBadge(0)
                              : Text('${i.stock}', style: tabular(body)),
                        ),
                      ),
                    ),
                    if (compact)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [for (final s in _sizeOrder) Text(sizeCell(i, s), style: tabular(body))],
                      )
                    else
                      ...[for (final s in _sizeOrder) Text(sizeCell(i, s), style: tabular(body))],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Tooltip(
                        message: 'Los ingredientes no se eliminan, solo se desactivan.',
                        child: Semantics(
                          label: 'Activo: ${i.name}',
                          child: Switch(value: i.active, onChanged: (v) => onActive(i, v)),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Editar',
                        onPressed: () => onEdit(i),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
