import 'package:flutter/material.dart';

import '../../features/orders/domain/order_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/money_format.dart';

/// Importe `$ 0.00` con cifras tabulares. Nunca calcula: solo da formato.
class MoneyText extends StatelessWidget {
  const MoneyText(this.amount, {super.key, this.total = false, this.style});
  final String? amount;
  final bool total;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = total
        ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)
        : theme.textTheme.bodyMedium;
    return Text(formatMoney(amount), style: tabular(style ?? base));
  }
}

/// Chip de estado del pedido: color + icono + texto (nunca solo color).
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip(this.status, {super.key});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final s = context.semantic;
    final (bg, fg, icon) = switch (status) {
      OrderStatus.pending => (s.warningContainer, s.onWarningContainer, Icons.schedule),
      OrderStatus.inPreparation => (c.primaryContainer, c.onPrimaryContainer, Icons.soup_kitchen),
      OrderStatus.delivered => (s.successContainer, s.onSuccessContainer, Icons.check_circle),
    };
    return Semantics(
      label: 'Estado: ${status.label}',
      excludeSemantics: true,
      child: _Pill(background: bg, foreground: fg, icon: icon, label: status.label),
    );
  }
}

/// Chip de disponibilidad: Disponible / No disponible / Agotado.
class AvailabilityChip extends StatelessWidget {
  const AvailabilityChip({super.key, required this.available, this.unavailableLabel = 'No disponible'});
  final bool available;
  final String unavailableLabel;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final s = context.semantic;
    return available
        ? _Pill(
            background: s.successContainer,
            foreground: s.onSuccessContainer,
            icon: Icons.check_circle,
            label: 'Disponible')
        : _Pill(
            background: c.errorContainer,
            foreground: c.onErrorContainer,
            icon: Icons.block,
            label: unavailableLabel);
  }
}

/// Chip neutro (IVA 15 %, Inactivo...).
class NeutralChip extends StatelessWidget {
  const NeutralChip(this.label, {super.key, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return _Pill(
        background: c.surfaceContainerHighest, foreground: c.onSurface, icon: icon, label: label);
  }
}

/// "Stock: N" o "Agotado" si es 0.
class StockBadge extends StatelessWidget {
  const StockBadge(this.stock, {super.key});
  final int stock;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    if (stock <= 0) {
      return _Pill(
          background: c.errorContainer, foreground: c.onErrorContainer, icon: Icons.block, label: 'Agotado');
    }
    return _Pill(
        background: c.surfaceContainerHighest,
        foreground: c.onSurface,
        label: 'Stock: $stock',
        tabularNumbers: true);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.background,
    required this.foreground,
    required this.label,
    this.icon,
    this.tabularNumbers = false,
  });
  final Color background;
  final Color foreground;
  final String label;
  final IconData? icon;
  final bool tabularNumbers;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(color: foreground);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: foreground), const SizedBox(width: 4)],
          Flexible(
            child: Text(label,
                style: tabularNumbers ? tabular(style) : style, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// Fila "etiqueta ........ valor" para totales y resumenes.
class LabeledValueRow extends StatelessWidget {
  const LabeledValueRow({super.key, required this.label, required this.value, this.strong = false});
  final String label;
  final Widget value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = strong
        ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          DefaultTextStyle(style: tabular(style) ?? const TextStyle(), child: value),
        ],
      ),
    );
  }
}
