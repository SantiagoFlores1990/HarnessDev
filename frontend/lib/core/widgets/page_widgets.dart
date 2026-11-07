import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../layout/breakpoints.dart';
import '../theme/app_colors.dart';

/// Contador que sube con F5 / Ctrl+R / boton Actualizar. Las pantallas lo escuchan
/// con `ref.listen(refreshTickProvider, ...)` para recargar sus datos.
class RefreshTick extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final refreshTickProvider = NotifierProvider<RefreshTick, int>(RefreshTick.new);

/// Atajos de pantalla: `CallbackShortcuts` + foco automatico para que funcionen sin
/// haber tocado ningun control.
class PageShortcuts extends StatelessWidget {
  const PageShortcuts({super.key, required this.bindings, required this.child});
  final Map<ShortcutActivator, VoidCallback> bindings;
  final Widget child;

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
        bindings: bindings,
        child: Focus(autofocus: true, skipTraversal: true, child: child),
      );
}

/// Marco de pagina: titulo (encabezado semantico), acciones y contenido centrado
/// con ancho maximo 1440 px y margen segun el ancho de ventana.
class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.leading,
    this.maxWidth = Breakpoints.maxContentWidth,
  });

  final String title;
  final List<Widget> actions;
  final Widget? leading;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final margin = Breakpoints.pageMargin(width);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(margin, AppSpacing.lg, margin, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.xs)],
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(title,
                          style: Theme.of(context).textTheme.headlineSmall,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  ...actions.expand((a) => [const SizedBox(width: AppSpacing.xs), a]),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Boton "Actualizar" con tooltip y F5.
class RefreshButton extends StatelessWidget {
  const RefreshButton({super.key, required this.onPressed, this.loading = false});
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: const Icon(Icons.refresh, size: 20),
        label: const Text('Actualizar'),
      );
}

/// Controles "Anterior / Siguiente" y "Pagina X de Y".
class PaginationBar extends StatelessWidget {
  const PaginationBar({super.key, required this.page, required this.totalPages, required this.onPage});
  final int page;
  final int totalPages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Página anterior',
              onPressed: page > 1 ? () => onPage(page - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('Página $page de $totalPages'),
            IconButton(
              tooltip: 'Página siguiente',
              onPressed: page < totalPages ? () => onPage(page + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      );
}

/// Fila de tabla clicable con hover (`surfaceContainerHigh`), foco visible y Enter.
class HoverRow extends StatelessWidget {
  const HoverRow({super.key, required this.child, this.onTap, this.semanticsLabel, this.height = 52});
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticsLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        hoverColor: c.surfaceContainerHigh,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: child,
          ),
        ),
      ),
    );
  }
}

