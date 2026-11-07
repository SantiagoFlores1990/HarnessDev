import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/display_widgets.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/page_widgets.dart';
import '../../cart/presentation/cart_provider.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../orders/domain/order_models.dart';
import '../data/preset_repository.dart';
import '../domain/preset_models.dart';

/// S-03 Pizzas predefinidas (inicio del cliente).
class PresetsPage extends ConsumerStatefulWidget {
  const PresetsPage({super.key});

  @override
  ConsumerState<PresetsPage> createState() => _PresetsPageState();
}

class _PresetsPageState extends ConsumerState<PresetsPage> {
  String? _sizeCode;

  void _reload() {
    ref.invalidate(presetPizzasProvider);
    ref.invalidate(sizesProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(refreshTickProvider, (_, _) => _reload());
    final presets = ref.watch(presetPizzasProvider);
    final sizes = ref.watch(sizesProvider);

    return PageFrame(
      title: 'Pizzas predefinidas',
      actions: [RefreshButton(onPressed: _reload)],
      child: AsyncValueView<List<PresetPizza>>(
        value: presets,
        onRetry: _reload,
        errorMessage: 'No se pudieron cargar las pizzas predefinidas.',
        loading: const _PresetsSkeleton(),
        isEmpty: (list) => list.isEmpty,
        empty: EmptyState(
          icon: Icons.local_pizza,
          title: 'Todavía no hay pizzas predefinidas.',
          message: 'Puedes armar la tuya desde cero.',
          actionLabel: 'Personalizar pizza',
          onAction: () => context.go('/builder'),
        ),
        data: (list) {
          final sizeList = sizes.value ?? const <SizeOption>[];
          final selected = _sizeCode ??
              (sizeList.any((s) => s.code == 'MEDIUM') ? 'MEDIUM' : (sizeList.isNotEmpty ? sizeList.first.code : 'MEDIUM'));
          return _PresetsContent(
            presets: list,
            sizes: sizeList,
            sizeCode: selected,
            onSize: (c) => setState(() => _sizeCode = c),
          );
        },
      ),
    );
  }
}

class _PresetsSkeleton extends StatelessWidget {
  const _PresetsSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        label: 'Cargando pizzas predefinidas',
        child: const Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [SkeletonBlock(width: 280, height: 240), SkeletonBlock(width: 280, height: 240), SkeletonBlock(width: 280, height: 240), SkeletonBlock(width: 280, height: 240), SkeletonBlock(width: 280, height: 240)],
        ),
      );
}

class _PresetsContent extends StatelessWidget {
  const _PresetsContent({
    required this.presets,
    required this.sizes,
    required this.sizeCode,
    required this.onSize,
  });

  final List<PresetPizza> presets;
  final List<SizeOption> sizes;
  final String sizeCode;
  final ValueChanged<String> onSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = Breakpoints.presetColumns(MediaQuery.sizeOf(context).width);
        const gap = AppSpacing.md;
        final cardWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  const Text('Tamaño para ver precios:'),
                  if (sizes.isNotEmpty)
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: [
                        for (final s in sizes) ButtonSegment(value: s.code, label: Text(s.name)),
                      ],
                      selected: {sizeCode},
                      onSelectionChanged: (v) => onSize(v.first),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final p in presets)
                    SizedBox(width: cardWidth, child: PresetCard(preset: p, sizeCode: sizeCode)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Las pizzas predefinidas solo permiten agregar ingredientes, no quitarlos.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tarjeta de una predefinida con receta, precio/calorias del tamano y acciones.
class PresetCard extends ConsumerWidget {
  const PresetCard({super.key, required this.preset, required this.sizeCode});
  final PresetPizza preset;
  final String sizeCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final price = preset.priceFor(sizeCode);
    final available = preset.available;
    final reason = preset.unavailableText ?? 'Esta pizza no está disponible.';

    void personalize() => context.go('/builder?presetId=${preset.id}&size=$sizeCode');

    void addToCart() {
      ref.read(cartProvider.notifier).add(
            PizzaItemInput(
              type: PizzaTypes.preset,
              presetPizzaId: preset.id,
              sizeCode: sizeCode,
              quantity: 1,
            ),
            presetName: preset.name,
          );
      final router = GoRouter.of(context);
      showAppSnack(context, 'Pizza agregada', actionLabel: 'Ver pedido', onAction: () => router.go('/cart'));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(preset.name, style: theme.textTheme.titleLarge)),
                const SizedBox(width: AppSpacing.xs),
                AvailabilityChip(available: available),
              ],
            ),
            if (preset.description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(preset.description,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            if (!available) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(reason, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text('Receta:', style: theme.textTheme.labelLarge),
            for (final r in preset.recipe) Text('${r.name} x${r.portions}', style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.md,
              children: [
                Text(available && price != null ? formatMoney(price.price) : '\$ --',
                    style: tabular(theme.textTheme.titleMedium)),
                Text(available && price != null ? formatKcal(price.calories) : '-- kcal',
                    style: tabular(theme.textTheme.titleMedium)),
              ],
            ),
            Text('Precio sin IVA',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                Tooltip(
                  message: available ? '' : reason,
                  child: OutlinedButton(
                    onPressed: available ? personalize : null,
                    child: const Text('Personalizar'),
                  ),
                ),
                Tooltip(
                  message: available ? '' : reason,
                  child: FilledButton(
                    onPressed: available ? addToCart : null,
                    child: const Text('Agregar al pedido'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
