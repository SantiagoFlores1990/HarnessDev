import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../theme/app_colors.dart';

/// Banner de error `errorContainer` con icono, mensaje y reintento opcional.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, this.onRetry, this.retryLabel = 'Reintentar'});

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: c.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: c.onErrorContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.onErrorContainer)),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: c.onErrorContainer),
                child: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Banner informativo / de exito / advertencia con icono y texto (nunca solo color).
enum NoticeKind { info, success, warning }

class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key, required this.message, this.kind = NoticeKind.info});
  final String message;
  final NoticeKind kind;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final s = context.semantic;
    final (bg, fg, icon) = switch (kind) {
      NoticeKind.info => (c.primaryContainer, c.onPrimaryContainer, Icons.info_outline),
      NoticeKind.success => (s.successContainer, s.onSuccessContainer, Icons.check_circle_outline),
      NoticeKind.warning => (s.warningContainer, s.onWarningContainer, Icons.warning_amber_outlined),
    };
    return Semantics(
      container: true,
      liveRegion: kind != NoticeKind.info,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, color: fg),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
                child: Text(message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg))),
          ],
        ),
      ),
    );
  }
}

/// Estado vacio: icono grande, titulo, texto y accion primaria opcional.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: theme.colorScheme.secondary),
              const SizedBox(height: AppSpacing.md),
              Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(message!,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center),
              ],
              if (actionLabel != null || secondaryLabel != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    if (actionLabel != null) FilledButton(onPressed: onAction, child: Text(actionLabel!)),
                    if (secondaryLabel != null)
                      OutlinedButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Indicador de carga accesible con region viva.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Cargando…'});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: Semantics(
          liveRegion: true,
          label: label,
          child: const CircularProgressIndicator(),
        ),
      );
}

/// Renderiza un `AsyncValue` con sus tres estados obligatorios: cargando, error con
/// "Reintentar" y datos (con estado vacio).
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.isEmpty,
    this.empty,
    this.onRetry,
    this.errorMessage,
    this.loadingLabel = 'Cargando…',
    this.loading,
    this.notFound,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  /// Si devuelve true se muestra [empty].
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final VoidCallback? onRetry;

  /// Mensaje de carga fallida (por pantalla); si es null se usa el del error.
  final String? errorMessage;
  final String loadingLabel;
  final Widget? loading;

  /// Vista especial cuando el error es 404 NOT_FOUND.
  final Widget? notFound;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => loading ?? LoadingView(label: loadingLabel),
      error: (error, _) {
        if (notFound != null && error is ApiException && error.isNotFound) return notFound!;
        final detail = error is ApiException && error.isNetwork ? error.userMessage : errorMessage;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ErrorBanner(message: detail ?? errorMessageOf(error), onRetry: onRetry),
            ),
          ),
        );
      },
      data: (d) {
        if (empty != null && (isEmpty?.call(d) ?? false)) return empty!;
        return data(d);
      },
    );
  }
}

/// Bloque gris de esqueleto (`surfaceContainerHighest`).
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({super.key, this.width, this.height = 20});
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
      );
}

/// Lista de filas de esqueleto para tablas mientras carga.
class SkeletonRows extends StatelessWidget {
  const SkeletonRows({super.key, this.count = 5, this.height = 52, this.label = 'Cargando…'});
  final int count;
  final double height;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        label: label,
        child: Column(
          children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: SkeletonBlock(height: height),
              ),
          ],
        ),
      );
}
