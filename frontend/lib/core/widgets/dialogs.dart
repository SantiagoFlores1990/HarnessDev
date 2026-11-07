import 'package:flutter/material.dart';

/// Dialogo de confirmacion. Foco inicial en "Cancelar"; `Esc` cancela.
/// Devuelve true si el usuario confirma.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    ),
  );
  return result ?? false;
}

class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirmar',
    this.cancelLabel = 'Cancelar',
    this.destructive = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Text(message),
      ),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: c.error, foregroundColor: c.onError)
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

/// Dialogo informativo con una sola accion.
Future<void> showInfoDialog(
  BuildContext context, {
  required String title,
  required Widget content,
  String actionLabel = 'Aceptar',
}) =>
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: content),
        actions: [
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

/// Ayuda de atajos de teclado (F1), responsive.md §5.
class ShortcutsHelpDialog extends StatelessWidget {
  const ShortcutsHelpDialog({super.key, required this.isAdmin});
  final bool isAdmin;

  static const _common = <(String, String)>[
    ('Ctrl+1 … Ctrl+4', 'Ir al destino del menú'),
    ('Alt+←', 'Volver'),
    ('F5 o Ctrl+R', 'Actualizar la pantalla'),
    ('F1', 'Mostrar esta ayuda'),
    ('Ctrl+Shift+Q', 'Cerrar sesión'),
    ('Esc', 'Cerrar diálogo o menú'),
    ('Tab / Mayús+Tab', 'Mover el foco'),
  ];
  static const _client = <(String, String)>[
    ('Ctrl+Enter', 'Agregar pizza (Personalizar) o confirmar pedido (Resumen)'),
    ('Espacio', 'Marcar o desmarcar la casilla enfocada'),
    ('↑ ↓ o + −', 'Cambiar cantidad con el selector enfocado'),
  ];
  static const _admin = <(String, String)>[
    ('Ctrl+N', 'Nuevo ingrediente o nueva pizza'),
    ('Ctrl+S', 'Guardar el formulario'),
    ('Ctrl+Enter', 'Avanzar el estado del pedido'),
    ('Ctrl+F', 'Buscar en la lista'),
  ];

  @override
  Widget build(BuildContext context) {
    final rows = [..._common, ...(isAdmin ? _admin : _client)];
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Atajos de teclado'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (keys, action) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 170,
                        child: Text(keys, style: theme.textTheme.labelLarge),
                      ),
                      Expanded(child: Text(action)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

/// Dialogo de sesion expirada.
Future<void> showSessionExpiredDialog(BuildContext context) => showInfoDialog(
      context,
      title: 'Sesión expirada',
      content: const Text('Tu sesión expiró. Inicia sesión de nuevo.'),
      actionLabel: 'Iniciar sesión',
    );

/// Muestra un snackbar breve (3 s) con accion opcional.
void showAppSnack(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction, Duration? duration}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration ?? const Duration(seconds: 3),
      action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
    ),
  );
}
