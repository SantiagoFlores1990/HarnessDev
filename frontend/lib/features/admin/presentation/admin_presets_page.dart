import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/layout/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/display_widgets.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/page_widgets.dart';
import '../../preset_pizzas/data/preset_repository.dart';
import '../../preset_pizzas/domain/preset_models.dart';

/// Predefinidas para el ADMIN (incluye inactivas segun el interruptor).
final adminPresetsProvider = FutureProvider.autoDispose.family<List<PresetPizza>, bool>(
  (ref, includeInactive) => ref.watch(presetRepositoryProvider).list(includeInactive: includeInactive),
);

/// S-09 Pizzas predefinidas (admin, lista).
class AdminPresetsPage extends ConsumerStatefulWidget {
  const AdminPresetsPage({super.key});

  @override
  ConsumerState<AdminPresetsPage> createState() => _AdminPresetsPageState();
}

class _AdminPresetsPageState extends ConsumerState<AdminPresetsPage> {
  bool _includeInactive = true;

  void _reload() => ref.invalidate(adminPresetsProvider);

  Future<void> _toggle(PresetPizza p, bool active) async {
    if (!active) {
      final ok = await showConfirmDialog(
        context,
        title: 'Desactivar pizza',
        message: '¿Desactivar ${p.name}? Dejará de mostrarse a los clientes. Los pedidos anteriores no cambian.',
        confirmLabel: 'Desactivar',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    try {
      await ref.read(presetRepositoryProvider).setActive(p.id, active);
      _reload();
      if (mounted) showAppSnack(context, active ? 'Pizza activada' : 'Pizza desactivada');
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.userMessage);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(refreshTickProvider, (_, _) => _reload());
    final list = ref.watch(adminPresetsProvider(_includeInactive));
    final compact = MediaQuery.sizeOf(context).width < Breakpoints.standardMin;
    return PageShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.keyN, control: true): () => context.go('/admin/presets/new')},
      child: PageFrame(
        title: 'Pizzas predefinidas',
        actions: [
          Tooltip(
            message: 'Nueva pizza (Ctrl+N)',
            child: FilledButton.icon(
              onPressed: () => context.go('/admin/presets/new'),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Nueva pizza'),
            ),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Semantics(
                  label: 'Mostrar inactivas',
                  child: Switch(value: _includeInactive, onChanged: (v) => setState(() => _includeInactive = v)),
                ),
                const Text('Mostrar inactivas'),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: AsyncValueView<List<PresetPizza>>(
                value: list,
                onRetry: _reload,
                errorMessage: 'No se pudieron cargar las pizzas predefinidas.',
                loading: const SkeletonRows(count: 5, label: 'Cargando pizzas predefinidas'),
                isEmpty: (l) => l.isEmpty,
                empty: EmptyState(
                  icon: Icons.local_pizza_outlined,
                  title: 'Aún no hay pizzas predefinidas.',
                  actionLabel: 'Nueva pizza',
                  onAction: () => context.go('/admin/presets/new'),
                ),
                data: (items) => _PresetsTable(
                  items: items,
                  compact: compact,
                  onEdit: (p) => context.go('/admin/presets/${p.id}'),
                  onActive: _toggle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetsTable extends StatelessWidget {
  const _PresetsTable({required this.items, required this.compact, required this.onEdit, required this.onActive});

  final List<PresetPizza> items;
  final bool compact;
  final ValueChanged<PresetPizza> onEdit;
  final void Function(PresetPizza, bool) onActive;

  static const _sizeOrder = ['INDIVIDUAL', 'MEDIUM', 'FAMILY'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final head = theme.textTheme.titleSmall;
    final flex = compact ? const [1, 3, 4, 3, 3, 2, 1] : const [1, 3, 3, 4, 2, 2, 2, 3, 2, 1];

    // La ultima celda (acciones) tiene ancho fijo de 56 px para conservar el objetivo de toque de 48 px.
    Widget row(List<Widget> cells) => Row(
          children: [
            for (var i = 0; i < cells.length - 1; i++) Expanded(flex: flex[i], child: cells[i]),
            SizedBox(width: 56, child: cells.last),
          ],
        );

    String sizeCell(PresetPizza p, String s) {
      final v = p.priceFor(s);
      return v == null ? '—' : '${formatMoney(v.price)} · ${v.calories}';
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: c.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: row([
              Text('Orden', style: head),
              Text('Nombre', style: head),
              if (!compact) Text('Código', style: head),
              Text('Receta', style: head),
              if (compact) Text('Individual / Mediana / Familiar', style: head) else ...[
                Text('Individual', style: head),
                Text('Mediana', style: head),
                Text('Familiar', style: head),
              ],
              Text('Estado', style: head),
              Text('Activa', style: head),
              const SizedBox.shrink(),
            ]),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final p = items[index];
                final muted = p.active ? null : c.onSurfaceVariant;
                final body = theme.textTheme.bodyMedium?.copyWith(color: muted);
                final recipe = p.recipe.map((r) => r.name).join(', ');
                return HoverRow(
                  onTap: () => onEdit(p),
                  height: compact ? 72 : 56,
                  semanticsLabel: 'Editar ${p.name}',
                  child: row([
                    Text('${p.sortOrder}', style: tabular(body)),
                    Row(children: [
                      Flexible(child: Text(p.name, style: body, overflow: TextOverflow.ellipsis)),
                      if (!p.active) ...[const SizedBox(width: 6), const NeutralChip('Inactiva')],
                    ]),
                    if (!compact) Text(p.code, style: tabular(body), overflow: TextOverflow.ellipsis),
                    Text(recipe, style: body, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (compact)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [for (final s in _sizeOrder) Text(sizeCell(p, s), style: tabular(body))],
                      )
                    else
                      ...[for (final s in _sizeOrder) Text(sizeCell(p, s), style: tabular(body))],
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AvailabilityChip(available: p.available),
                        if (!p.available && p.unavailableText != null)
                          Text(p.unavailableText!, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Tooltip(
                        message: 'Las pizzas no se eliminan, solo se desactivan.',
                        child: Semantics(
                          label: 'Activa: ${p.name}',
                          child: Switch(value: p.active, onChanged: (v) => onActive(p, v)),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Editar',
                        onPressed: () => onEdit(p),
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
