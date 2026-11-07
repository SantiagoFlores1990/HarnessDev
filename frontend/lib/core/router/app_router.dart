import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_ingredients_page.dart';
import '../../features/admin/presentation/admin_order_detail_page.dart';
import '../../features/admin/presentation/admin_orders_page.dart';
import '../../features/admin/presentation/admin_presets_page.dart';
import '../../features/admin/presentation/ingredient_form_page.dart';
import '../../features/admin/presentation/preset_form_page.dart';
import '../../features/auth/domain/auth_models.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/auth/presentation/session_provider.dart';
import '../../features/cart/presentation/cart_page.dart';
import '../../features/orders/presentation/my_orders_page.dart';
import '../../features/orders/presentation/order_detail_page.dart';
import '../../features/pizza_builder/presentation/pizza_builder_page.dart';
import '../../features/preset_pizzas/presentation/presets_page.dart';
import '../widgets/app_shell.dart';
import '../widgets/good_pizza_logo.dart';

const String clientHome = '/presets';
const String adminHome = '/admin/ingredients';

/// Inicio segun el rol.
String homeFor(UserRole role) => role == UserRole.admin ? adminHome : clientHome;

/// Reglas de redireccion por sesion y rol (arquitectura §3.4). Funcion pura para poder probarla.
///
/// * cargando la sesion -> `/splash`
/// * sin sesion fuera de `/login` y `/register` -> `/login`
/// * con sesion en rutas publicas, `/splash` o `/` -> inicio del rol
/// * CLIENT en `/admin/*` -> `/presets`; ADMIN fuera de `/admin/*` -> `/admin/ingredients`
String? appRedirect(String location, {required bool loading, UserRole? role}) {
  if (loading) return location == '/splash' ? null : '/splash';
  final isPublic = location == '/login' || location == '/register';
  if (role == null) return isPublic ? null : '/login';
  if (isPublic || location == '/splash' || location == '/') return homeFor(role);
  final isAdminPath = location == '/admin' || location.startsWith('/admin/');
  if (role == UserRole.client && isAdminPath) return clientHome;
  if (role == UserRole.admin && !isAdminPath) return adminHome;
  return null;
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GoodPizzaLogo(vertical: true),
              SizedBox(height: 24),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
}

/// Cada pantalla vive en un Navigator anidado cuyo Overlay corta la busqueda de `Material`
/// (LookupBoundary); sin este ancestro, ChoiceChip, ListTile, InkWell, etc. fallan en tiempo
/// de ejecucion. El Material es transparente: el fondo lo sigue pintando el Scaffold del shell.
Page<void> _page(GoRouterState state, Widget child) => NoTransitionPage<void>(
      key: state.pageKey,
      child: Material(type: MaterialType.transparency, child: child),
    );

/// Router de la aplicacion con guards por sesion y rol.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      return appRedirect(
        state.uri.path,
        loading: session.isLoading && !session.hasValue,
        role: session.value?.user.role,
      );
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _Splash()),
      GoRoute(path: '/splash', builder: (_, _) => const _Splash()),
      GoRoute(path: '/login', pageBuilder: (_, s) => _page(s, const LoginPage())),
      GoRoute(path: '/register', pageBuilder: (_, s) => _page(s, const RegisterPage())),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/presets', pageBuilder: (_, s) => _page(s, const PresetsPage())),
          GoRoute(
            path: '/builder',
            pageBuilder: (_, s) => _page(
              s,
              PizzaBuilderPage(
                presetId: s.uri.queryParameters['presetId'],
                sizeCode: s.uri.queryParameters['size'],
              ),
            ),
          ),
          GoRoute(path: '/cart', pageBuilder: (_, s) => _page(s, const CartPage())),
          GoRoute(
            path: '/orders',
            pageBuilder: (_, s) => _page(s, const MyOrdersPage()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (_, s) => _page(
                  s,
                  OrderDetailPage(
                    key: ValueKey(s.pathParameters['id']),
                    orderId: s.pathParameters['id']!,
                    justConfirmed: s.uri.queryParameters['confirmed'] == '1',
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/admin/ingredients',
            pageBuilder: (_, s) => _page(s, const AdminIngredientsPage()),
            routes: [
              GoRoute(path: 'new', pageBuilder: (_, s) => _page(s, const IngredientFormPage())),
              GoRoute(
                path: ':id',
                pageBuilder: (_, s) => _page(
                  s,
                  IngredientFormPage(key: ValueKey(s.pathParameters['id']), ingredientId: s.pathParameters['id']),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/admin/presets',
            pageBuilder: (_, s) => _page(s, const AdminPresetsPage()),
            routes: [
              GoRoute(path: 'new', pageBuilder: (_, s) => _page(s, const PresetFormPage())),
              GoRoute(
                path: ':id',
                pageBuilder: (_, s) => _page(
                  s,
                  PresetFormPage(key: ValueKey(s.pathParameters['id']), presetId: s.pathParameters['id']),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/admin/orders',
            pageBuilder: (_, s) => _page(s, const AdminOrdersPage()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (_, s) => _page(
                  s,
                  AdminOrderDetailPage(key: ValueKey(s.pathParameters['id']), orderId: s.pathParameters['id']!),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
