import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/display_widgets.dart';
import '../../../core/widgets/good_pizza_logo.dart';
import '../domain/component_text.dart';
import '../domain/order_models.dart';

/// Pie fijo del comprobante (PA-UX-09).
const String receiptFooterText = 'Documento informativo del pedido. No es una factura electrónica.';

/// "4.50" -> "4 dólares con 50 centavos" para lectores de pantalla.
String spokenMoney(String amount) {
  final n = normalizeDecimal(amount);
  final parts = n.split('.');
  if (parts.length != 2) return '$amount dólares';
  return '${parts[0]} dólares con ${parts[1]} centavos';
}

/// Comprobante del pedido (solo pantalla; sin imprimir ni exportar). Todo proviene del
/// `OrderDetail` (snapshots): nunca se recalcula.
class ReceiptView extends StatelessWidget {
  const ReceiptView({super.key, required this.order});
  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Comprobante del pedido ${order.orderNumber}',
      child: SelectionArea(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          decoration: BoxDecoration(
            color: c.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.outlineVariant),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(order: order),
              const _Rule(thick: true),
              _CustomerBlock(order: order),
              for (final pizza in order.pizzas) ...[
                const _Rule(),
                _PizzaBlock(pizza: pizza),
              ],
              const _Rule(thick: true),
              _SummaryBlock(totals: order.totals),
              const _Rule(thick: true),
              _StatusBlock(order: order),
              const _Rule(),
              Text(receiptFooterText,
                  style: theme.textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({this.thick = false});
  final bool thick;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Divider(
          height: 1,
          thickness: thick ? 2 : 1,
          color: thick ? Theme.of(context).colorScheme.outline : Theme.of(context).colorScheme.outlineVariant,
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.order});
  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: AppSpacing.sm,
      spacing: AppSpacing.lg,
      children: [
        const GoodPizzaLogo(variant: LogoVariant.receipt),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Orden  ', style: theme.textTheme.bodyMedium),
                Text(order.orderNumber, style: tabular(theme.textTheme.titleMedium)),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Fecha  ', style: theme.textTheme.bodyMedium),
                Text(formatDateTime(order.createdAt), style: tabular(theme.textTheme.bodyMedium)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _CustomerBlock extends StatelessWidget {
  const _CustomerBlock({required this.order});
  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CLIENTE', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.secondary)),
        const SizedBox(height: 2),
        Text(order.customer.fullName, style: theme.textTheme.titleMedium),
        Text(order.customer.email, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _PizzaBlock extends StatelessWidget {
  const _PizzaBlock({required this.pizza});
  final PricedPizza pizza;

  String _componentName(String kind) {
    for (final c in pizza.components) {
      if (c.component == kind) return c.name;
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final headerStyle = theme.textTheme.titleSmall?.copyWith(color: muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('PIZZA ${pizza.index + 1} · ${pizza.kindLabel}',
                  style: theme.textTheme.titleMedium),
            ),
            Text('Cantidad x${pizza.quantity}', style: tabular(theme.textTheme.titleMedium)),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: AppSpacing.lg,
          children: [
            Text('Tamaño: ${pizza.sizeName}'),
            Text('Masa: ${_componentName('DOUGH')}'),
            Text('Salsa: ${_componentName('SAUCE')}'),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _TableRow(
          cells: ['Ingrediente', 'Cant.', 'Calorías', 'Precio (sin IVA)'],
          style: headerStyle,
        ),
        const Divider(height: 8),
        for (final c in pizza.components)
          Semantics(
            excludeSemantics: true,
            label: '${c.name}, cantidad ${c.portions}, ${c.lineCalories} calorías, ${spokenMoney(c.lineAmount)}',
            child: _TableRow(
              cells: [
                pizza.isPreset && c.component == 'TOPPING'
                    ? '${c.name}${_extraNote(c)}'
                    : c.name,
                '${c.portions}',
                formatKcal(c.lineCalories),
                formatMoney(c.lineAmount),
              ],
            ),
          ),
        const Divider(height: 8),
        _TableRow(
          cells: ['Por pizza', '', formatKcal(pizza.unitCalories), formatMoney(pizza.unitPrice)],
          style: theme.textTheme.titleSmall,
        ),
        if (pizza.quantity > 1)
          _TableRow(
            cells: [
              'Línea (x${pizza.quantity})',
              '',
              formatKcal(pizza.lineCalories),
              formatMoney(pizza.lineSubtotal),
            ],
            style: theme.textTheme.titleSmall,
          ),
      ],
    );
  }

  String _extraNote(PricedComponent c) {
    final text = componentSummary(c, preset: true);
    final i = text.indexOf(' (');
    return i < 0 ? '' : text.substring(i);
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.cells, this.style});
  final List<String> cells;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyMedium;
    final numeric = tabular(base);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text(cells[0], style: base)),
          Expanded(flex: 2, child: Text(cells[1], style: numeric, textAlign: TextAlign.center)),
          Expanded(flex: 3, child: Text(cells[2], style: numeric, textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text(cells[3], style: numeric, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({required this.totals});
  final Totals totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('RESUMEN', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.secondary)),
        const SizedBox(height: 4),
        LabeledValueRow(label: 'Calorías totales', value: Text(formatKcal(totals.totalCalories))),
        LabeledValueRow(label: 'Subtotal 15 %', value: Text(formatMoney(totals.subtotalVat15))),
        LabeledValueRow(label: 'Subtotal 0 %', value: Text(formatMoney(totals.subtotalVat0))),
        LabeledValueRow(label: 'IVA 15 %', value: Text(formatMoney(totals.vat15))),
        const Divider(height: AppSpacing.md),
        DefaultTextStyle.merge(
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          child: LabeledValueRow(
            label: 'TOTAL (USD)',
            value: Text(formatMoney(totals.total), key: const Key('receipt-total')),
          ),
        ),
      ],
    );
  }
}

class _StatusBlock extends StatelessWidget {
  const _StatusBlock({required this.order});
  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = order.status;
    final step = OrderStatus.values.indexOf(status) + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ESTADO ACTUAL', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.secondary)),
        const SizedBox(height: 4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xs,
          children: [
            OrderStatusChip(status),
            Text('Actualizado: ${formatDateTime(order.statusChangedAt)}', style: tabular(theme.textTheme.bodyMedium)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          label: 'Paso $step de 3: ${status.label}',
          excludeSemantics: true,
          child: _Timeline(current: step),
        ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    Widget dot(int index) {
      final reached = index <= current;
      return Icon(reached ? Icons.circle : Icons.circle_outlined,
          size: 16, color: reached ? c.primary : c.outline);
    }

    Widget line(int index) => Expanded(
          child: Container(height: 2, color: index < current ? c.primary : c.outlineVariant),
        );

    final labels = OrderStatus.values.map((s) => s.label).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [dot(1), line(1), dot(2), line(2), dot(3)]),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [for (final l in labels) Text(l, style: theme.textTheme.bodySmall)],
        ),
      ],
    );
  }
}
