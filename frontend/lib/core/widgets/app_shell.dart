import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/session_provider.dart';
import '../../features/cart/presentation/cart_provider.dart';
import '../layout/breakpoints.dart';
import '../theme/app_colors.dart';
import 'dialogs.dart';
import 'good_pizza_logo.dart';
import 'page_widgets.dart';

/// Destino del menu lateral.
class ShellDestination {
  const ShellDestination({
    required this.route,
    required this.label,
    required this.icon,
    this.matchPrefixes = const [],
  });
  final String route;
  final String label;
  final IconData icon;

  /// Prefijos de ruta que mantienen este destino seleccionado (detalle, formularios).
  final List<String> matchPrefixes;

  bool matches(String location) =>
      location == route || [route, ...matchPrefixes].any((p) => location.startsWith('$p/') || location == p);
}

const List<ShellDestination> clientDestinations = [
  ShellDestination(route: '/presets', label: 'Pizzas predefinidas', icon: Icons.local_pizza),
  ShellDestination(route: '/builder', label: 'Personalizar pizza', icon: Icons.tune),
  ShellDestination(route: '/cart', label: 'Mi pedido', icon: Icons.shopping_cart),
  ShellDestination(route: '/orders', label: 'Mis pedidos', icon: Icons.receipt_long),
];

const List<ShellDestination> adminDestinations = [
  ShellDestination(route: '/admin/ingredients', label: 'Ingredientes', icon: Icons.inventory_2),
  ShellDestination(route: '/admin/presets', label: 'Pizzas predefinidas', icon: Icons.local_pizza),
  ShellDestination(route: '/admin/orders', label: 'Pedidos', icon: Icons.receipt_long),
];

List<ShellDestination> destinationsFor(UserRole role) =>
    role == UserRole.admin ? adminDestinations : clientDestinations;

/// Estructura comun: `NavigationRail` por rol + contenido. Rail extendido desde 1280 px,
/// compacto (icono + etiqueta) entre 1024 y 1279 px. Nunca hay barra inferior.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    if (session == null) return child;
    final user = session.user;
    final destinations = destinationsFor(user.role);
    final selected = destinations.indexWhere((d) => d.matches(location));
    final cartCount = user.isAdmin ? 0 : ref.watch(cartProvider.select((c) => c.pizzaCount));

    void goTo(int index) {
      if (index >= 0 && index < destinations.length) context.go(destinations[index].route);
    }

    Future<void> logout() async {
      final cartHasItems = !user.isAdmin && ref.read(cartProvider).pizzaCount > 0;
      final ok = await showConfirmDialog(
        context,
        title: 'Cerrar sesión',
        message: cartHasItems
            ? 'Tu pedido tiene pizzas sin confirmar. Si cierras sesión se perderán. ¿Cerrar sesión?'
            : '¿Quieres cerrar sesión?',
        confirmLabel: 'Cerrar sesión',
      );
      if (ok) await ref.read(sessionProvider.notifier).logout();
    }

    final bindings = <ShortcutActivator, VoidCallback>{
      for (var i = 0; i < destinations.length; i++)
        SingleActivator(
          [LogicalKeyboardKey.digit1, LogicalKeyboardKey.digit2, LogicalKeyboardKey.digit3, LogicalKeyboardKey.digit4][i],
          control: true,
        ): () => goTo(i),
      const SingleActivator(LogicalKeyboardKey.f5): () => ref.read(refreshTickProvider.notifier).bump(),
      const SingleActivator(LogicalKeyboardKey.keyR, control: true): () =>
          ref.read(refreshTickProvider.notifier).bump(),
      const SingleActivator(LogicalKeyboardKey.f1): () =>
          showDialog<void>(context: context, builder: (_) => ShortcutsHelpDialog(isAdmin: user.isAdmin)),
      const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () {
        if (context.canPop()) context.pop();
      },
      const SingleActivator(LogicalKeyboardKey.keyQ, control: true, shift: true): logout,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final extended = Breakpoints.railExtended(constraints.maxWidth);
        final theme = Theme.of(context);
        final semantic = context.semantic;
        return CallbackShortcuts(
          bindings: bindings,
          child: Focus(
            autofocus: true,
            skipTraversal: true,
            child: Scaffold(
              body: Row(
                children: [
                  Theme(
                    // Foco visible sobre el azul marino del rail.
                    data: theme.copyWith(focusColor: semantic.focusRingOnDark.withValues(alpha: 0.35)),
                    child: NavigationRail(
                      extended: extended,
                      labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                      selectedIndex: selected < 0 ? null : selected,
                      onDestinationSelected: goTo,
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: GoodPizzaLogo(
                          variant: extended ? LogoVariant.rail : LogoVariant.railCompact,
                          showText: extended,
                          textColor: theme.colorScheme.onPrimary,
                        ),
                      ),
                      destinations: [
                        for (final d in destinations)
                          NavigationRailDestination(
                            // 44 px por defecto + 4 px: objetivo de toque de 48 px (accesibilidad.md)
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            icon: _icon(d, cartCount, theme),
                            selectedIcon: _icon(d, cartCount, theme),
                            label: Text(d.label),
                          ),
                      ],
                      trailing: Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: _UserFooter(user: user, extended: extended, onLogout: logout),
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _icon(ShellDestination d, int cartCount, ThemeData theme) {
    final icon = Icon(d.icon);
    if (d.route == '/cart' && cartCount > 0) {
      return Badge(
        label: Text('$cartCount'),
        backgroundColor: theme.colorScheme.tertiary,
        textColor: theme.colorScheme.onTertiary,
        child: icon,
      );
    }
    return icon;
  }
}

class _UserFooter extends StatelessWidget {
  const _UserFooter({required this.user, required this.extended, required this.onLogout});
  final AppUser user;
  final bool extended;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onPrimary;
    final muted = context.semantic.railUnselected;
    if (!extended) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: '${user.fullName} (${user.role.label})',
              child: Icon(Icons.account_circle, color: muted, size: 28),
            ),
            TextButton.icon(
              onPressed: onLogout,
              icon: Icon(Icons.logout, color: fg, size: 18),
              label: Text('Salir', style: TextStyle(color: fg)),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SizedBox(
        width: 208,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.fullName,
                style: theme.textTheme.titleSmall?.copyWith(color: fg), overflow: TextOverflow.ellipsis),
            Text(user.role.label, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            const SizedBox(height: AppSpacing.xs),
            TextButton.icon(
              onPressed: onLogout,
              icon: Icon(Icons.logout, color: fg, size: 18),
              label: Text('Cerrar sesión', style: TextStyle(color: fg)),
            ),
          ],
        ),
      ),
    );
  }
}
