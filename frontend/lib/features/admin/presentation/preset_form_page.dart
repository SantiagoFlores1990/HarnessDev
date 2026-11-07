import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/money_format.dart';
import '../../../core/widgets/display_widgets.dart';
import '../../../core/widgets/feedback_widgets.dart';
import '../../../core/widgets/page_widgets.dart';
import '../../../core/widgets/steppers.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/domain/order_models.dart';
import '../../orders/domain/violation_text.dart';
import '../../preset_pizzas/data/preset_repository.dart';
import '../../preset_pizzas/domain/preset_models.dart';
import 'admin_ingredients_page.dart';
import 'admin_presets_page.dart';

const IngredientFilter _allIngredients = (search: '', category: null, includeInactive: true);

final _presetDetailProvider = FutureProvider.autoDispose.family<PresetPizza, String>(
    (ref, id) => ref.watch(presetRepositoryProvider).get(id));

/// S-10 Pizza predefinida (nueva / editar). Sin campo de precio: se muestra una vista
/// previa calculada por el servidor con `POST /orders/quote`.
class PresetFormPage extends ConsumerWidget {
  const PresetFormPage({super.key, this.presetId});
  final String? presetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ingredients = ref.watch(adminIngredientsProvider(_allIngredients));
    final sizes = ref.watch(sizesProvider);
    final detail = presetId == null ? null : ref.watch(_presetDetailProvider(presetId!));

    void reload() {
      ref.invalidate(adminIngredientsProvider);
      ref.invalidate(sizesProvider);
      if (presetId != null) ref.invalidate(_presetDetailProvider(presetId!));
    }

    ref.listen(refreshTickProvider, (_, _) => reload());
    final all = <AsyncValue<Object?>>[ingredients, sizes, ?detail];
    final failed = all.where((v) => v.hasError && !v.isLoading).firstOrNull;
    final ready = ingredients.hasValue && sizes.hasValue && (detail == null || detail.hasValue);

    return PageFrame(
      title: presetId == null ? 'Nueva pizza predefinida' : 'Editar pizza predefinida',
      leading: TextButton.icon(
        onPressed: () => context.go('/admin/presets'),
        icon: const Icon(Icons.arrow_back),
        label: const Text('Pizzas predefinidas'),
      ),
      maxWidth: 960,
      child: failed != null
          ? AsyncValueView<Object?>(
              value: failed,
              data: (_) => const SizedBox.shrink(),
              errorMessage: 'No se pudo cargar el formulario.',
              onRetry: reload,
              notFound: EmptyState(
                icon: Icons.search_off,
                title: 'Esta pizza ya no existe.',
                actionLabel: 'Volver a Pizzas predefinidas',
                onAction: () => context.go('/admin/presets'),
              ),
            )
          : !ready
              ? const SkeletonRows(count: 6, height: 56, label: 'Cargando formulario')
              : _PresetForm(
                  key: ValueKey(presetId ?? 'new'),
                  initial: detail?.value,
                  ingredients: ingredients.requireValue,
                  sizes: sizes.requireValue,
                ),
    );
  }
}

class _PresetForm extends ConsumerStatefulWidget {
  const _PresetForm({super.key, required this.initial, required this.ingredients, required this.sizes});
  final PresetPizza? initial;
  final List<Ingredient> ingredients;
  final List<SizeOption> sizes;

  @override
  ConsumerState<_PresetForm> createState() => _PresetFormState();
}

class _PresetFormState extends ConsumerState<_PresetForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _order;
  String? _doughId;
  String? _sauceId;
  final Map<String, int> _toppings = {};
  bool _busy = false;
  List<String> _recipeErrors = const [];
  Map<String, String> _serverErrors = {};
  String? _banner;

  final _debouncer = Debouncer(const Duration(milliseconds: 300));
  CancelToken? _cancel;
  int _seq = 0;
  QuoteResult? _preview;
  bool _previewLoading = false;
  bool _previewFailed = false;

  bool get _isNew => widget.initial == null;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _code = TextEditingController(text: p?.code ?? '');
    _name = TextEditingController(text: p?.name ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _order = TextEditingController(text: '${p?.sortOrder ?? 0}');
    if (p != null) {
      for (final r in p.recipe) {
        if (r.categoryCode == CategoryCodes.dough) {
          _doughId = r.ingredientId;
        } else if (r.categoryCode == CategoryCodes.sauce) {
          _sauceId = r.ingredientId;
        } else {
          _toppings[r.ingredientId] = r.portions;
        }
      }
    }
    Future.microtask(_schedulePreview);
  }

  @override
  void dispose() {
    _debouncer.cancel();
    _cancel?.cancel();
    _code.dispose();
    _name.dispose();
    _description.dispose();
    _order.dispose();
    super.dispose();
  }

  void _schedulePreview() {
    if (!mounted) return;
    _cancel?.cancel();
    if (_doughId == null || _sauceId == null) {
      setState(() {
        _preview = null;
        _previewLoading = false;
        _previewFailed = false;
      });
      return;
    }
    setState(() {
      _previewLoading = true;
      _previewFailed = false;
    });
    _debouncer.run(_runPreview);
  }

  Future<void> _runPreview() async {
    final seq = ++_seq;
    final cancel = CancelToken();
    _cancel = cancel;
    final items = [
      for (final s in widget.sizes)
        PizzaItemInput(
          type: PizzaTypes.custom,
          sizeCode: s.code,
          doughId: _doughId,
          sauceId: _sauceId,
          toppings: [for (final e in _toppings.entries) PortionInput(ingredientId: e.key, portions: e.value)],
        ),
    ];
    try {
      final result = await ref.read(ordersRepositoryProvider).quote(items, cancelToken: cancel);
      if (!mounted || seq != _seq) return;
      setState(() {
        _preview = result;
        _previewLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || e.isCancelled || seq != _seq) return;
      setState(() {
        _previewLoading = false;
        _previewFailed = true;
      });
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _banner = null;
      _serverErrors = {};
      _recipeErrors = const [];
    });
    final formOk = _formKey.currentState!.validate();
    final errors = <String>[
      if (_doughId == null) 'Elige una masa.',
      if (_sauceId == null) 'Elige una salsa base.',
    ];
    if (errors.isNotEmpty) setState(() => _recipeErrors = errors);
    if (!formOk || errors.isNotEmpty) return;

    final draft = PresetDraft(
      code: _code.text.trim().toUpperCase(),
      name: _name.text.trim(),
      description: _description.text.trim(),
      sortOrder: int.parse(_order.text.trim()),
      recipe: [
        PortionInput(ingredientId: _doughId!, portions: 1),
        PortionInput(ingredientId: _sauceId!, portions: 1),
        for (final e in _toppings.entries) PortionInput(ingredientId: e.key, portions: e.value),
      ],
    );
    setState(() => _busy = true);
    final repo = ref.read(presetRepositoryProvider);
    try {
      if (_isNew) {
        await repo.create(draft);
      } else {
        await repo.update(widget.initial!.id, draft);
      }
      ref.invalidate(adminPresetsProvider);
      ref.invalidate(presetPizzasProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pizza guardada')));
      context.go('/admin/presets');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        switch (e.code) {
          case ErrorCodes.presetCodeExists:
            _serverErrors = {'code': 'Ya existe una pizza con ese código.'};
          case ErrorCodes.presetNameExists:
            _serverErrors = {'name': 'Ya existe una pizza con ese nombre.'};
          case ErrorCodes.invalidRecipe:
            _recipeErrors = [
              for (final d in e.detailMaps) violationText(Violation.fromJson(d)),
              if (e.detailMaps.isEmpty) e.userMessage,
            ];
          case ErrorCodes.notFound:
            _banner = 'Esta pizza ya no existe.';
          case ErrorCodes.validation:
            _serverErrors = e.fieldErrors;
            if (_serverErrors.isEmpty) _banner = e.userMessage;
          default:
            _banner = e.userMessage;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final doughs = widget.ingredients.where((i) => i.isDough).toList();
    final sauces = widget.ingredients.where((i) => i.isSauce).toList();
    final toppingList = widget.ingredients.where((i) => !i.isDough && !i.isSauce).toList();

    DropdownMenuItem<String> item(Ingredient i) =>
        DropdownMenuItem(value: i.id, child: Text(i.active ? i.name : '${i.name} (inactivo)'));

    return PageShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save},
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            if (_banner != null) ...[ErrorBanner(message: _banner!), const SizedBox(height: AppSpacing.md)],
            const NoticeBanner(message: 'Los cambios de receta afectan solo a pedidos nuevos.'),
            const SizedBox(height: AppSpacing.md),
            _card(
              theme,
              'DATOS',
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  SizedBox(
                    width: 240,
                    child: TextFormField(
                      controller: _code,
                      enabled: !_busy,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_]')),
                        TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toUpperCase())),
                      ],
                      decoration: InputDecoration(labelText: 'Código', errorText: _serverErrors['code']),
                      validator: (v) => RegExp(r'^[A-Z0-9_]{2,30}$').hasMatch((v ?? '').trim().toUpperCase())
                          ? null
                          : 'Usa 2 a 30 caracteres: mayúsculas, números y guion bajo.',
                    ),
                  ),
                  SizedBox(
                    width: 320,
                    child: TextFormField(
                      controller: _name,
                      enabled: !_busy,
                      decoration: InputDecoration(labelText: 'Nombre', errorText: _serverErrors['name']),
                      validator: (v) {
                        final n = (v ?? '').trim();
                        return n.length >= 2 && n.length <= 80 ? null : 'Ingresa un nombre (2 a 80 caracteres).';
                      },
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      controller: _order,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(labelText: 'Orden', errorText: _serverErrors['sortOrder']),
                      validator: (v) => int.tryParse((v ?? '').trim()) == null ? 'Ingresa un número entero.' : null,
                    ),
                  ),
                  SizedBox(
                    width: 700,
                    child: TextFormField(
                      controller: _description,
                      enabled: !_busy,
                      maxLines: 2,
                      decoration: InputDecoration(labelText: 'Descripción', errorText: _serverErrors['description']),
                      validator: (v) => (v ?? '').trim().length <= 300 ? null : 'La descripción admite máximo 300 caracteres.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _card(
              theme,
              'RECETA',
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_recipeErrors.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ErrorBanner(message: _recipeErrors.join('\n')),
                    ),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 300,
                        child: DropdownButtonFormField<String>(
                          initialValue: _doughId,
                          decoration: const InputDecoration(labelText: 'Masa'),
                          items: [for (final d in doughs) item(d)],
                          onChanged: _busy ? null : (v) {
                            setState(() => _doughId = v);
                            _schedulePreview();
                          },
                        ),
                      ),
                      Text('(porción fija: 1)', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                      SizedBox(
                        width: 300,
                        child: DropdownButtonFormField<String>(
                          initialValue: _sauceId,
                          decoration: const InputDecoration(labelText: 'Salsa'),
                          items: [for (final s in sauces) item(s)],
                          onChanged: _busy ? null : (v) {
                            setState(() => _sauceId = v);
                            _schedulePreview();
                          },
                        ),
                      ),
                      Text('(porción fija: 1)', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Ingredientes (porciones 1 a 3 por ingrediente, sin repetir):',
                      style: theme.textTheme.titleSmall),
                  Text('Las predefinidas pueden tener menos de 3 ingredientes.',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                  for (final i in toppingList) _toppingRow(i, theme),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _card(theme, 'VISTA PREVIA (calculada, sin IVA)', _previewBlock(theme)),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : () => context.go('/admin/presets'),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: AppSpacing.sm),
                Tooltip(
                  message: 'Guardar pizza (Ctrl+S)',
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(_busy ? 'Guardando…' : 'Guardar pizza'),
                  ),
                ),
              ],
            ),
          ],
        )),
      ),
    );
  }

  Widget _toppingRow(Ingredient i, ThemeData theme) {
    final portions = _toppings[i.id] ?? 0;
    final checked = portions > 0;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Row(
        children: [
          Semantics(
            label: '${i.name}, stock ${i.stock}',
            child: Checkbox(
              value: checked,
              onChanged: _busy ? null : (v) {
                setState(() {
                  if (v == true) {
                    _toppings[i.id] = 1;
                  } else {
                    _toppings.remove(i.id);
                  }
                });
                _schedulePreview();
              },
            ),
          ),
          Expanded(child: Text(i.active ? i.name : '${i.name} (inactivo)', style: theme.textTheme.bodyLarge)),
          StockBadge(i.stock),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 168,
            child: Align(
              alignment: Alignment.centerRight,
              child: checked
                  ? PortionStepper(
                      value: portions,
                      min: 1,
                      max: 3,
                      limitMessage: 'Máximo 3 porciones por ingrediente',
                      semanticsLabel: 'Porciones de ${i.name}',
                      onChanged: (n) {
                        setState(() => _toppings[i.id] = n);
                        _schedulePreview();
                      },
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewBlock(ThemeData theme) {
    if (_doughId == null || _sauceId == null) {
      return const Text('Elige masa y salsa para ver la vista previa.');
    }
    if (_previewFailed) {
      return ErrorBanner(message: 'No se pudo calcular la vista previa.', onRetry: _schedulePreview);
    }
    final preview = _preview;
    if (preview == null) {
      return _previewLoading ? const Text('Calculando…') : const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.xs,
          children: [
            for (var i = 0; i < widget.sizes.length && i < preview.items.length; i++)
              Text(
                '${widget.sizes[i].name} ${formatMoney(preview.items[i].unitPrice)} · ${formatKcal(preview.items[i].unitCalories)}',
                style: tabular(theme.textTheme.bodyLarge),
              ),
          ],
        ),
        if (_previewLoading)
          const Padding(padding: EdgeInsets.only(top: 4), child: Text('Calculando…')),
        // Se ignora MIN_TOPPINGS_NOT_MET: las predefinidas pueden tener menos de 3 ingredientes.
        for (final v in preview.allViolations.where((v) => v.code != 'MIN_TOPPINGS_NOT_MET'))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(violationText(v), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          ),
      ],
    );
  }

  Widget _card(ThemeData theme, String title, Widget child) => Card(
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
