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
import '../../../core/widgets/steppers.dart';
import '../../orders/domain/component_text.dart';
import '../../orders/domain/order_models.dart';
import '../../orders/domain/violation_text.dart';
import '../domain/cart_state.dart';
import 'cart_provider.dart';

/// S-05 Resumen del pedido (carrito).
class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  bool _confirming = false;
  List<String> _errorLines = const [];
  bool _retryable = false;

  Future<void> _confirm() async {
    final quote = ref.read(cartQuoteProvider);
    final result = quote.value;
    final cart = ref.read(cartProvider);
    if (_confirming || cart.isEmpty || result == null || !result.valid || quote.isLoading) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Confirmar pedido',
      message:
          '¿Confirmar el pedido por ${formatMoney(result.totals.total)}? Al confirmar se reserva el stock y no se puede cancelar.',
      confirmLabel: 'Confirmar',
    );
    if (!ok || !mounted) return;
    await _submit(result.totals.total);
  }

  Future<void> _submit(String expectedTotal) async {
    setState(() {
      _confirming = true;
      _errorLines = const [];
    });
    try {
      final order = await ref.read(cartProvider.notifier).confirm(expectedTotal: expectedTotal);
      if (!mounted) return;
      context.go('/orders/${order.id}?confirmed=1');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _confirming = false);
      await _handleError(e, expectedTotal);
    }
  }

  Future<void> _handleError(ApiException e, String previousTotal) async {
    switch (e.code) {
      case ErrorCodes.insufficientStock:
        ref.invalidate(cartQuoteProvider);
        final lines = e.stockLines;
        await showInfoDialog(
          context,
          title: 'Stock insuficiente',
          actionLabel: 'Ajustar pedido',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lines.isEmpty) Text(e.serverMessage ?? e.userMessage) else for (final l in lines) Text(l),
            ],
          ),
        );
      case ErrorCodes.priceChanged:
        final newTotal = e.newTotalFromPriceChanged;
        ref.invalidate(cartQuoteProvider);
        final accept = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('El precio cambió'),
            content: Text(newTotal == null
                ? e.userMessage
                : 'El total ahora es ${formatMoney(newTotal)} (antes ${formatMoney(previousTotal)}).'),
            actions: [
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Revisar pedido'),
              ),
              FilledButton(
                onPressed: newTotal == null ? null : () => Navigator.of(ctx).pop(true),
                child: const Text('Aceptar y confirmar'),
              ),
            ],
          ),
        );
        if (accept == true && newTotal != null && mounted) await _submit(newTotal);
      case ErrorCodes.pizzaRulesViolated:
        ref.invalidate(cartQuoteProvider);
        setState(() {
          _retryable = false;
          _errorLines = [
            for (final d in e.detailMaps)
              '${d['itemIndex'] is num ? 'Pizza ${(d['itemIndex'] as num).toInt() + 1}: ' : ''}${violationText(Violation.fromJson(d))}',
          ];
          if (_errorLines.isEmpty) _errorLines = [e.userMessage];
        });
      case ErrorCodes.forbidden:
        setState(() {
          _retryable = false;
          _errorLines = const ['Tu cuenta no puede crear pedidos.'];
        });
      default:
        setState(() {
          _retryable = true;
          _errorLines = const ['No se pudo confirmar el pedido. Inténtalo de nuevo.'];
        });
    }
  }

  void _remove(String id) {
    final removed = ref.read(cartProvider.notifier).remove(id);
    if (removed == null) return;
    showAppSnack(
      context,
      'Pizza quitada',
      actionLabel: 'Deshacer',
      onAction: () => ref.read(cartProvider.notifier).restore(removed.$1, removed.$2),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(refreshTickProvider, (_, _) => ref.invalidate(cartQuoteProvider));
    final cart = ref.watch(cartProvider);
    final quote = ref.watch(cartQuoteProvider);

    if (cart.isEmpty) {
      return PageFrame(
        title: 'Resumen del pedido',
        child: EmptyState(
          icon: Icons.shopping_cart_outlined,
          title: 'Tu pedido está vacío.',
          message: 'Agrega una pizza predefinida o arma la tuya.',
          actionLabel: 'Ver pizzas predefinidas',
          onAction: () => context.go('/presets'),
          secondaryLabel: 'Personalizar pizza',
          onSecondary: () => context.go('/builder'),
        ),
      );
    }

    final result = quote.value;
    final loadingQuote = quote.isLoading;
    final quoteFailed = quote.hasError && !quote.isLoading;
    final canConfirm = !_confirming && !loadingQuote && !quoteFailed && result != null && result.valid;

    final lines = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cart.lines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _LineCard(
              number: i + 1,
              line: cart.lines[i],
              priced: result != null && i < result.items.length ? result.items[i] : null,
              enabled: !_confirming,
              onQuantity: (q) => ref.read(cartProvider.notifier).setQuantity(cart.lines[i].id, q),
              onRemove: () => _remove(cart.lines[i].id),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: () => context.go('/presets'),
            child: const Text('Seguir agregando pizzas'),
          ),
        ),
      ],
    );

    final violations = result?.allViolations ?? const <Violation>[];
    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TotalsCard(totals: result?.totals, loading: loadingQuote),
        if (quoteFailed) ...[
          const SizedBox(height: AppSpacing.sm),
          ErrorBanner(
            message: 'No se pudo calcular el pedido.',
            onRetry: () => ref.invalidate(cartQuoteProvider),
          ),
        ],
        if (violations.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _ViolationsBanner(violations: violations),
        ],
        if (_errorLines.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          ErrorBanner(
            message: _errorLines.join('\n'),
            onRetry: _retryable && result != null ? () => _submit(result.totals.total) : null,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Tooltip(
          message: 'Confirmar pedido (Ctrl+Enter)',
          child: FilledButton(
            onPressed: canConfirm ? _confirm : null,
            child: _confirming
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Confirmando…'),
                    ],
                  )
                : const Text('Confirmar pedido'),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Precios sin IVA; IVA 15 % calculado sobre el subtotal.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );

    final sideLayout = MediaQuery.sizeOf(context).width >= Breakpoints.standardMin;
    return PageFrame(
      title: 'Resumen del pedido',
      child: PageShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.enter, control: true): _confirm},
        child: sideLayout
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: SingleChildScrollView(padding: const EdgeInsets.only(bottom: AppSpacing.lg), child: lines)),
                  const SizedBox(width: AppSpacing.lg),
                  SizedBox(width: 320, child: SingleChildScrollView(child: side)),
                ],
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                children: [lines, const SizedBox(height: AppSpacing.md), side],
              ),
      ),
    );
  }
}

class _ViolationsBanner extends StatelessWidget {
  const _ViolationsBanner({required this.violations});
  final List<Violation> violations;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: c.errorContainer, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final v in violations)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, size: 18, color: c.onErrorContainer),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${v.itemIndex != null ? 'Pizza ${v.itemIndex! + 1}: ' : ''}${violationText(v)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.number,
    required this.line,
    required this.priced,
    required this.enabled,
    required this.onQuantity,
    required this.onRemove,
  });

  final int number;
  final CartLine line;
  final PricedPizza? priced;
  final bool enabled;
  final ValueChanged<int> onQuantity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final p = priced;
    final kind = line.input.isPreset ? (p?.presetPizza?.name ?? line.presetName ?? 'Predefinida') : 'Personalizada';
    final sizeName = p?.sizeName.isNotEmpty == true ? p!.sizeName : line.input.sizeCode;
    final isPreset = line.input.isPreset;

    String components() {
      if (p == null) return 'Calculando detalle…';
      return p.components.map((c) => componentSummary(c, preset: isPreset)).join(', ');
    }

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.delete): () => enabled ? onRemove() : null},
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Pizza $number · $kind · $sizeName', style: theme.textTheme.titleMedium),
                  ),
                  QuantityStepper(value: line.input.quantity, onChanged: onQuantity, enabled: enabled),
                  IconButton(
                    tooltip: 'Quitar del pedido',
                    onPressed: enabled ? onRemove : null,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              Text(components(), style: theme.textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.xs),
              if (p != null)
                Wrap(
                  spacing: AppSpacing.md,
                  children: [
                    Text('${formatMoney(p.unitPrice)} c/u · ${formatKcal(p.unitCalories)} c/u',
                        style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                    Text('Línea: ${formatMoney(p.lineSubtotal)} (${p.lineCalories})',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resumen de totales: calorias, subtotales, IVA y TOTAL, exactamente como los devuelve el API.
class TotalsCard extends StatelessWidget {
  const TotalsCard({super.key, required this.totals, this.loading = false});
  final Totals? totals;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = totals;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('RESUMEN',
                        style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.secondary)),
                  ),
                ),
                if (loading)
                  Semantics(
                    liveRegion: true,
                    label: 'Calculando',
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 6),
                        Text('Calculando…'),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            LabeledValueRow(
                label: 'Calorías totales', value: Text(t == null ? '—' : formatKcal(t.totalCalories))),
            LabeledValueRow(label: 'Subtotal 15 %', value: Text(t == null ? '—' : formatMoney(t.subtotalVat15))),
            LabeledValueRow(label: 'Subtotal 0 %', value: Text(t == null ? '—' : formatMoney(t.subtotalVat0))),
            LabeledValueRow(label: 'IVA 15 %', value: Text(t == null ? '—' : formatMoney(t.vat15))),
            const Divider(height: AppSpacing.md),
            LabeledValueRow(
              label: 'TOTAL (USD)',
              strong: true,
              value: Text(t == null ? '—' : formatMoney(t.total), key: const Key('cart-total')),
            ),
          ],
        ),
      ),
    );
  }
}
