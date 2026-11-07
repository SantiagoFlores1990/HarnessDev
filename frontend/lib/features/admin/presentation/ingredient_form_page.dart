import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/page_widgets.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/catalog_models.dart';
import 'admin_ingredients_page.dart';
import 'stock_dialog.dart';

final _ingredientDetailProvider = FutureProvider.autoDispose.family<Ingredient, String>(
    (ref, id) => ref.watch(catalogRepositoryProvider).ingredient(id));

/// S-08 Ingrediente (nuevo / editar).
class IngredientFormPage extends ConsumerWidget {
  const IngredientFormPage({super.key, this.ingredientId});

  /// `null` = alta.
  final String? ingredientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final vatRates = ref.watch(vatRatesProvider);
    final sizes = ref.watch(sizesProvider);
    final detail = ingredientId == null ? null : ref.watch(_ingredientDetailProvider(ingredientId!));

    void reload() {
      ref.invalidate(categoriesProvider);
      ref.invalidate(vatRatesProvider);
      ref.invalidate(sizesProvider);
      if (ingredientId != null) ref.invalidate(_ingredientDetailProvider(ingredientId!));
    }

    ref.listen(refreshTickProvider, (_, _) => reload());

    final all = <AsyncValue<Object?>>[categories, vatRates, sizes, ?detail];
    final failed = all.where((v) => v.hasError && !v.isLoading).firstOrNull;
    final ready = categories.hasValue && vatRates.hasValue && sizes.hasValue && (detail == null || detail.hasValue);

    return PageFrame(
      title: ingredientId == null ? 'Nuevo ingrediente' : 'Editar ingrediente',
      leading: TextButton.icon(
        onPressed: () => context.go('/admin/ingredients'),
        icon: const Icon(Icons.arrow_back),
        label: const Text('Ingredientes'),
      ),
      maxWidth: 960,
      child: failed != null
          ? AsyncValueView<Object?>(
              value: failed,
              data: (_) => const SizedBox.shrink(),
              errorMessage: 'No se pudo cargar el catálogo.',
              onRetry: reload,
              notFound: EmptyState(
                icon: Icons.search_off,
                title: 'Este ingrediente no existe.',
                actionLabel: 'Volver a Ingredientes',
                onAction: () => context.go('/admin/ingredients'),
              ),
            )
          : !ready
              ? const SkeletonRows(count: 6, height: 56, label: 'Cargando formulario')
              : _IngredientForm(
                  key: ValueKey(ingredientId ?? 'new'),
                  initial: detail?.value,
                  categories: categories.requireValue,
                  vatRates: vatRates.requireValue,
                  sizes: sizes.requireValue,
                ),
    );
  }
}

class _IngredientForm extends ConsumerStatefulWidget {
  const _IngredientForm({
    super.key,
    required this.initial,
    required this.categories,
    required this.vatRates,
    required this.sizes,
  });

  final Ingredient? initial;
  final List<IngredientCategory> categories;
  final List<VatRate> vatRates;
  final List<SizeOption> sizes;

  @override
  ConsumerState<_IngredientForm> createState() => _IngredientFormState();
}

class _IngredientFormState extends ConsumerState<_IngredientForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _stock;
  final Map<String, TextEditingController> _price = {};
  final Map<String, TextEditingController> _calories = {};
  String? _categoryCode;
  late String _vatCode;
  bool _active = true;
  bool _busy = false;
  bool _dirty = false;
  String? _banner;
  Map<String, String> _serverErrors = {};
  Set<String> _missingSizes = {};
  String? _vatError;

  bool get _isNew => widget.initial == null;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _code = TextEditingController(text: i?.code ?? '');
    _name = TextEditingController(text: i?.name ?? '');
    _stock = TextEditingController(text: '${i?.stock ?? 0}');
    _categoryCode = i?.categoryCode;
    _vatCode = i?.vatRateCode ??
        (widget.vatRates.where((v) => v.isDefault).map((v) => v.code).firstOrNull ??
            (widget.vatRates.isNotEmpty ? widget.vatRates.first.code : 'VAT_15'));
    _active = i?.active ?? true;
    for (final s in widget.sizes) {
      final v = i?.valueFor(s.code);
      _price[s.code] = TextEditingController(text: v == null ? '' : normalizeDecimal(v.price));
      _calories[s.code] = TextEditingController(text: v == null ? '' : '${v.calories}');
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _stock.dispose();
    for (final c in [..._price.values, ..._calories.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _touch() {
    if (!_dirty) _dirty = true;
  }

  Future<void> _leave() async {
    if (_dirty) {
      final stay = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Descartar cambios'),
          content: const Text('¿Descartar los cambios? Se perderán los datos no guardados.'),
          actions: [
            TextButton(autofocus: true, onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Seguir editando')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Descartar')),
          ],
        ),
      );
      if (stay != false || !mounted) return;
    }
    context.go('/admin/ingredients');
  }

  String? _err(String path) => _serverErrors[path];

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _banner = null;
      _serverErrors = {};
      _missingSizes = {};
      _vatError = null;
    });
    if (!_formKey.currentState!.validate()) return;
    final draft = IngredientDraft(
      code: _code.text.trim().toUpperCase(),
      name: _name.text.trim(),
      categoryCode: _categoryCode!,
      vatRateCode: _vatCode,
      active: _active,
      stock: int.tryParse(_stock.text.trim()) ?? 0,
      sizeValues: [
        for (final s in widget.sizes)
          SizeValue(
            sizeCode: s.code,
            price: priceTextToApi(_price[s.code]!.text),
            calories: int.parse(_calories[s.code]!.text.trim()),
          ),
      ],
    );
    setState(() => _busy = true);
    final repo = ref.read(catalogRepositoryProvider);
    try {
      if (_isNew) {
        await repo.createIngredient(draft);
      } else {
        await repo.updateIngredient(widget.initial!.id, draft);
      }
      ref.invalidate(adminIngredientsProvider);
      if (!mounted) return;
      _dirty = false;
      showAppSnack(context, 'Ingrediente guardado');
      context.go('/admin/ingredients');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        switch (e.code) {
          case ErrorCodes.ingredientCodeExists:
            _serverErrors = {'code': 'Ya existe un ingrediente con ese código.'};
          case ErrorCodes.missingSizeValues:
            _banner = 'Define precio y calorías para los tres tamaños.';
            for (final d in e.detailMaps) {
              final missing = d['missing'];
              if (missing is List) _missingSizes = missing.map((m) => '$m').toSet();
            }
          case ErrorCodes.categoryLocked:
            final names = <String>[];
            for (final d in e.detailMaps) {
              final list = d['presetPizzas'];
              if (list is List) names.addAll(list.map((p) => '$p'));
            }
            _banner = names.isEmpty
                ? e.userMessage
                : 'No se puede cambiar la categoría: el ingrediente se usa en las pizzas predefinidas: ${names.join(', ')}.';
          case ErrorCodes.invalidVatRate:
            _vatError = 'Elige una tarifa de IVA válida (15 % o 0 %).';
          case ErrorCodes.validation:
            _serverErrors = e.fieldErrors;
            if (_serverErrors.isEmpty) _banner = e.userMessage;
          default:
            _banner = e.userMessage;
        }
      });
    }
  }

  Future<void> _adjustStock() async {
    final changed = await showStockDialog(context, widget.initial!);
    if (changed && mounted) {
      ref.invalidate(_ingredientDetailProvider(widget.initial!.id));
      ref.invalidate(adminIngredientsProvider);
      showAppSnack(context, 'Stock actualizado');
    }
  }

  Future<void> _toggleActive(bool active) async {
    final i = widget.initial!;
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
      ref.invalidate(_ingredientDetailProvider(i.id));
      ref.invalidate(adminIngredientsProvider);
      if (mounted) showAppSnack(context, active ? 'Ingrediente activado' : 'Ingrediente desactivado');
    } on ApiException catch (e) {
      if (mounted) {
        showAppSnack(
          context,
          e.code == ErrorCodes.missingSizeValues
              ? 'No se puede activar: faltan precio y calorías de algún tamaño.'
              : e.userMessage,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return PageShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save},
      child: Form(
        key: _formKey,
        onChanged: _touch,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            if (_banner != null) ...[
              ErrorBanner(message: _banner!),
              const SizedBox(height: AppSpacing.md),
            ],
            if (!_isNew)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: NoticeBanner(
                  message:
                      'Los cambios de precio, calorías e IVA aplican a nuevos pedidos; los pedidos anteriores conservan sus valores.',
                ),
              ),
            _Section(
              title: 'DATOS',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      SizedBox(
                        width: 240,
                        child: TextFormField(
                          controller: _code,
                          enabled: !_busy,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                            TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toUpperCase())),
                          ],
                          decoration: InputDecoration(labelText: 'Código', errorText: _err('code')),
                          validator: (v) => RegExp(r'^[A-Z0-9-]{2,20}$').hasMatch((v ?? '').trim().toUpperCase())
                              ? null
                              : 'Usa 2 a 20 caracteres: letras mayúsculas, números y guion.',
                        ),
                      ),
                      SizedBox(
                        width: 360,
                        child: TextFormField(
                          controller: _name,
                          enabled: !_busy,
                          decoration: InputDecoration(labelText: 'Nombre', errorText: _err('name')),
                          validator: (v) {
                            final n = (v ?? '').trim();
                            return n.length >= 2 && n.length <= 80 ? null : 'Ingresa un nombre (2 a 80 caracteres).';
                          },
                        ),
                      ),
                      SizedBox(
                        width: 240,
                        child: DropdownButtonFormField<String>(
                          initialValue: _categoryCode,
                          decoration: InputDecoration(labelText: 'Categoría', errorText: _err('categoryCode')),
                          items: [
                            for (final c in widget.categories) DropdownMenuItem(value: c.code, child: Text(c.name)),
                          ],
                          onChanged: _busy ? null : (v) => setState(() {
                                _categoryCode = v;
                                _touch();
                              }),
                          validator: (v) => v == null ? 'Elige una categoría.' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.xs,
                    children: [
                      const Text('Tarifa de IVA'),
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: [
                          for (final v in widget.vatRates)
                            ButtonSegment(value: v.code, label: Text(formatPercent(v.ratePercent))),
                        ],
                        selected: {_vatCode},
                        onSelectionChanged: _busy ? null : (s) => setState(() {
                              _vatCode = s.first;
                              _touch();
                            }),
                      ),
                      if (_vatError != null)
                        Text(_vatError!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_isNew)
                    Wrap(
                      spacing: AppSpacing.md,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 200,
                          child: TextFormField(
                            controller: _stock,
                            enabled: !_busy,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(labelText: 'Stock inicial', errorText: _err('stock')),
                            validator: (v) => int.tryParse((v ?? '').trim()) == null
                                ? 'El stock debe ser un número entero mayor o igual a 0.'
                                : null,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(value: _active, onChanged: _busy ? null : (v) => setState(() => _active = v ?? true)),
                            const Text('Activo'),
                          ],
                        ),
                      ],
                    )
                  else
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Stock: ${widget.initial!.stock}', style: theme.textTheme.titleMedium),
                                const SizedBox(width: AppSpacing.md),
                                OutlinedButton(onPressed: _adjustStock, child: const Text('Ajustar stock')),
                              ],
                            ),
                          ),
                        ),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Estado: '),
                                Semantics(
                                  label: 'Ingrediente activo',
                                  child: Switch(value: widget.initial!.active, onChanged: _toggleActive),
                                ),
                                Text(widget.initial!.active ? 'Activo' : 'Inactivo'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _Section(
              title: 'VALORES POR TAMAÑO (precio sin IVA por porción)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var idx = 0; idx < widget.sizes.length; idx++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _sizeRow(widget.sizes[idx], idx, theme),
                    ),
                  Text('Cada tamaño tiene su propio precio y calorías.',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(onPressed: _busy ? null : _leave, child: const Text('Cancelar')),
                const SizedBox(width: AppSpacing.sm),
                Tooltip(
                  message: 'Guardar ingrediente (Ctrl+S)',
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(_busy ? 'Guardando…' : 'Guardar ingrediente'),
                  ),
                ),
              ],
            ),
          ],
        )),
      ),
    );
  }

  Widget _sizeRow(SizeOption size, int idx, ThemeData theme) {
    final missing = _missingSizes.contains(size.code);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.start,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        SizedBox(width: 120, child: Padding(padding: const EdgeInsets.only(top: 14), child: Text(size.name, style: theme.textTheme.titleSmall))),
        SizedBox(
          width: 200,
          child: TextFormField(
            controller: _price[size.code],
            enabled: !_busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Precio (USD) ${size.name}',
              errorText: _err('sizeValues.$idx.price'),
            ),
            validator: validatePriceText,
          ),
        ),
        SizedBox(
          width: 200,
          child: TextFormField(
            controller: _calories[size.code],
            enabled: !_busy,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Calorías (kcal) ${size.name}',
              errorText: _err('sizeValues.$idx.calories'),
            ),
            validator: (v) => int.tryParse((v ?? '').trim()) == null
                ? 'Las calorías deben ser un número entero mayor o igual a 0.'
                : null,
          ),
        ),
        if (missing)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text('Falta el valor de este tamaño.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.secondary)),
            ),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}
