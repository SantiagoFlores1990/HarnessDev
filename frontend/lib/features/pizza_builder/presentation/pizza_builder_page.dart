import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/page_widgets.dart';
import '../../cart/presentation/cart_provider.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../orders/domain/order_models.dart';
import '../../preset_pizzas/data/preset_repository.dart';
import '../../preset_pizzas/domain/preset_models.dart';
import 'builder_controller.dart';
import 'builder_widgets.dart';
import 'pizza_summary_panel.dart';

/// S-04 Personalizar pizza: casillas, cantidades y calculo en vivo desde el servidor.
class PizzaBuilderPage extends ConsumerWidget {
  const PizzaBuilderPage({super.key, this.presetId, this.sizeCode});

  final String? presetId;
  final String? sizeCode;

  void _reload(WidgetRef ref) {
    ref.invalidate(activeIngredientsProvider);
    ref.invalidate(sizesProvider);
    if (presetId != null) ref.invalidate(presetPizzaProvider(presetId!));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(refreshTickProvider, (_, _) => _reload(ref));
    final ingredients = ref.watch(activeIngredientsProvider);
    final sizes = ref.watch(sizesProvider);
    final preset = presetId == null ? null : ref.watch(presetPizzaProvider(presetId!));

    final all = <AsyncValue<Object?>>[ingredients, sizes, ?preset];
    final firstError = all.where((v) => v.hasError && !v.isLoading).firstOrNull;
    final loading = all.any((v) => v.isLoading && !v.hasValue);

    Widget body;
    if (firstError != null) {
      body = AsyncValueView<Object?>(
        value: firstError,
        data: (_) => const SizedBox.shrink(),
        errorMessage: 'No se pudo cargar el catálogo de ingredientes.',
        onRetry: () => _reload(ref),
      );
    } else if (loading || !ingredients.hasValue || !sizes.hasValue || (preset != null && !preset.hasValue)) {
      body = const _BuilderSkeleton();
    } else if (ingredients.requireValue.isEmpty) {
      body = const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No hay ingredientes disponibles por ahora.',
        message: 'Consulta con el local.',
      );
    } else {
      body = _BuilderBody(
        key: ValueKey('builder-$presetId-$sizeCode'),
        ingredients: ingredients.requireValue,
        sizes: sizes.requireValue,
        preset: preset?.value,
        initialSize: sizeCode,
      );
    }

    return PageFrame(
      title: 'Personalizar pizza',
      child: body,
    );
  }
}

class _BuilderSkeleton extends StatelessWidget {
  const _BuilderSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: AppSpacing.md),
        child: SkeletonRows(count: 8, height: 56, label: 'Cargando catálogo de ingredientes'),
      );
}

class _BuilderBody extends ConsumerStatefulWidget {
  const _BuilderBody({
    super.key,
    required this.ingredients,
    required this.sizes,
    required this.preset,
    required this.initialSize,
  });

  final List<Ingredient> ingredients;
  final List<SizeOption> sizes;
  final PresetPizza? preset;
  final String? initialSize;

  @override
  ConsumerState<_BuilderBody> createState() => _BuilderBodyState();
}

class _BuilderBodyState extends ConsumerState<_BuilderBody> {
  @override
  void initState() {
    super.initState();
    final size = widget.sizes.any((s) => s.code == widget.initialSize)
        ? widget.initialSize!
        : (widget.sizes.any((s) => s.code == 'MEDIUM') ? 'MEDIUM' : widget.sizes.first.code);
    // No se puede modificar un provider durante el build: se difiere al siguiente microtask.
    Future.microtask(() {
      if (mounted) ref.read(pizzaBuilderProvider.notifier).init(preset: widget.preset, sizeCode: size);
    });
  }

  Future<void> _add() async {
    final state = ref.read(pizzaBuilderProvider);
    if (!state.canAdd) return;
    ref.read(cartProvider.notifier).add(state.toInput(), presetName: widget.preset?.name);
    // El router se captura antes: la accion del snackbar puede ejecutarse cuando esta pagina ya no existe.
    final router = GoRouter.of(context);
    showAppSnack(context, 'Pizza agregada', actionLabel: 'Ver pedido', onAction: () => router.go('/cart'));
    if (state.isPreset) {
      router.go('/presets');
    } else {
      ref.read(pizzaBuilderProvider.notifier).reset();
    }
  }

  Future<void> _cancel() async {
    final state = ref.read(pizzaBuilderProvider);
    if (state.hasSelection) {
      final ok = await showConfirmDialog(
        context,
        title: 'Descartar pizza',
        message: '¿Descartar esta pizza?',
        confirmLabel: 'Descartar',
        cancelLabel: 'Seguir editando',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/presets');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pizzaBuilderProvider);
    final controller = ref.read(pizzaBuilderProvider.notifier);
    final theme = Theme.of(context);
    if (!state.initialized) return const LoadingView(label: 'Preparando el armado');

    final width = MediaQuery.sizeOf(context).width;
    final sideLayout = width >= Breakpoints.standardMin;
    final sizeName = widget.sizes
            .where((s) => s.code == state.sizeCode)
            .map((s) => s.name)
            .firstOrNull ??
        state.sizeCode;
    final violations = state.quote?.allViolations ?? const <Violation>[];
    final byIngredient = <String, List<Violation>>{};
    for (final v in violations) {
      final id = v.ingredientId;
      if (id != null) byIngredient.putIfAbsent(id, () => []).add(v);
    }
    bool has(String code) => violations.any((v) => v.code == code);

    final doughs = widget.ingredients.where((i) => i.isDough && i.active).toList();
    final sauces = widget.ingredients.where((i) => i.isSauce && i.active).toList();
    final toppings = widget.ingredients.where((i) => !i.isDough && !i.isSauce && i.active).toList();
    final grouped = <String, List<Ingredient>>{};
    for (final i in toppings) {
      grouped.putIfAbsent(i.categoryName, () => []).add(i);
    }

    final panel = PizzaSummaryPanel(
      state: state,
      ingredients: widget.ingredients,
      sizeName: sizeName,
      onQuantity: controller.setQuantity,
      onAdd: _add,
      onCancel: _cancel,
      onRetryQuote: controller.retryQuote,
    );

    final form = SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg, right: AppSpacing.xs),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.preset != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: NoticeBanner(
              message:
                  'Personalizando ${widget.preset!.name}. Puedes agregar ingredientes o porciones, pero no quitar los de la receta.',
            ),
          ),
        const SectionTitle('1. Tamaño'),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [for (final s in widget.sizes) ButtonSegment(value: s.code, label: Text(s.name))],
            selected: {state.sizeCode},
            onSelectionChanged: (v) => controller.setSize(v.first),
          ),
        ),
        const SectionTitle('2. Masa (elige 1)'),
        if (has('DOUGH_REQUIRED')) const _SectionError('Elige una masa.'),
        for (final d in doughs)
          ChoiceRow(
            ingredient: d,
            sizeCode: state.sizeCode,
            selected: state.doughId == d.id,
            locked: state.isPreset,
            onChanged: (on) => controller.selectDough(on ? d.id : null),
          ),
        const SectionTitle('3. Salsa base (elige 1)'),
        if (has('SAUCE_REQUIRED')) const _SectionError('Elige una salsa base.'),
        for (final s in sauces)
          ChoiceRow(
            ingredient: s,
            sizeCode: state.sizeCode,
            selected: state.sauceId == s.id,
            locked: state.isPreset,
            onChanged: (on) => controller.selectSauce(on ? s.id : null),
          ),
        SectionTitle(
          '4. Ingredientes (mín. 3 distintos, máx. 3 porciones)',
          trailing: state.isPreset
              ? null
              : Text('Ingredientes: ${state.portions.length} de 3 mínimos',
                  style: theme.textTheme.labelMedium),
        ),
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(entry.key, style: theme.textTheme.titleSmall),
          ),
          for (final i in entry.value)
            IngredientCheckRow(
              ingredient: i,
              state: state,
              violations: byIngredient[i.id] ?? const [],
              onToggle: () => controller.toggleTopping(i.id),
              onPortions: (n) => controller.setPortions(i.id, n),
            ),
        ],
      ],
    ));

    return PageShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _add,
      },
      child: sideLayout
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: form),
                const SizedBox(width: AppSpacing.lg),
                SizedBox(width: 320, child: Padding(padding: const EdgeInsets.only(bottom: AppSpacing.lg), child: panel)),
              ],
            )
          : Column(
              children: [
                Expanded(child: form),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: panel),
                ),
              ],
            ),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: c.error),
          const SizedBox(width: 4),
          Text(message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.error)),
        ],
      ),
    );
  }
}
