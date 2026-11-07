import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/catalog_models.dart';

/// Dialogo "Stock de `nombre`": fijar un valor (>= 0) o sumar/restar (entero distinto de 0).
/// Devuelve true si el stock se actualizo.
Future<bool> showStockDialog(BuildContext context, Ingredient ingredient) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => StockDialog(ingredient: ingredient),
  );
  return result ?? false;
}

class StockDialog extends ConsumerStatefulWidget {
  const StockDialog({super.key, required this.ingredient});
  final Ingredient ingredient;

  @override
  ConsumerState<StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends ConsumerState<StockDialog> {
  final _controller = TextEditingController();
  String _operation = 'SET';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _value => int.tryParse(_controller.text.trim());

  String? _validate() {
    final v = _value;
    if (v == null) return 'Ingresa un número entero válido.';
    if (_operation == 'SET' && v < 0) return 'El stock debe ser un número entero mayor o igual a 0.';
    if (_operation == 'ADD' && v == 0) return 'Ingresa un número entero distinto de 0.';
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(catalogRepositoryProvider)
          .adjustStock(widget.ingredient.id, operation: _operation, value: _value!);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (e.code) {
          ErrorCodes.stockWouldBeNegative => 'El ajuste dejaría el stock por debajo de 0.',
          ErrorCodes.validation => 'Ingresa un número entero válido.',
          _ => e.userMessage,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = _value;
    final preview = v == null
        ? null
        : (_operation == 'SET' ? v : widget.ingredient.stock + v);
    return AlertDialog(
      title: Text('Stock de ${widget.ingredient.name}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Stock actual: ${widget.ingredient.stock}'),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'SET', label: Text('Fijar valor')),
                ButtonSegment(value: 'ADD', label: Text('Sumar o restar')),
              ],
              selected: {_operation},
              onSelectionChanged: _busy ? null : (s) => setState(() {
                    _operation = s.first;
                    _error = null;
                  }),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _controller,
              autofocus: true,
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))],
              decoration: InputDecoration(
                labelText: _operation == 'SET' ? 'Nuevo valor de stock' : 'Cantidad a sumar (o restar con -)',
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(preview == null ? 'Nuevo stock: —' : 'Nuevo stock: $preview',
                style: theme.textTheme.bodyMedium),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              ErrorBanner(message: _error!),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Guardando…' : 'Guardar'),
        ),
      ],
    );
  }
}
