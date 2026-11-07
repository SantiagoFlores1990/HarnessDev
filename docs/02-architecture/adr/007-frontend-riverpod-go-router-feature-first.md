# ADR-007: Frontend feature-first con Riverpod, go_router, dio y flutter_secure_storage

- **Estado:** Aceptado · **Fecha:** 2026-11-06

## Contexto

App Flutter solo Windows (RNF-07), Material 3, NavigationRail, pantallas de cliente y admin (RF-28), cálculo en vivo vía API (ADR-002), pruebas de widget y de flujo (criterio 4). Skills `flutter-state-management` y `flutter-multiplatform`.

## Decisión

- Estructura `lib/core/{config,api,storage,router,theme,widgets,utils}` + `lib/features/<feature>/{data,domain,presentation}`.
- Estado con **Riverpod** (`flutter_riverpod`): `AsyncNotifier`/`FutureProvider` para datos remotos; `Notifier` para el armado (`pizzaBuilderProvider`) y el carrito (`cartProvider`, en memoria).
- Navegación con **go_router**: `ShellRoute` con `NavigationRail` y `redirect` por sesión y rol.
- HTTP con **dio** e interceptor de autenticación/refresh; mapeo del error uniforme a `ApiException(code, message, details)`.
- Tokens en **flutter_secure_storage** (Credential Manager en Windows).
- Modelos inmutables escritos a mano (sin `build_runner`), importes como `String`/`Decimal` (paquete `decimal`) solo para mostrar; nunca se calculan totales en Dart.
- Pruebas con `ProviderScope(overrides: …)` y repositorios falsos (`mocktail`).

## Alternativas

- **Bloc/Cubit:** robusto pero más verboso; Riverpod es la convención de las skills del harness.
- **Provider + ChangeNotifier:** menos seguro en tipos y pruebas.
- **Navigator 2.0 manual / auto_route:** go_router cubre redirecciones por rol con menos código y sin generación.
- **http en lugar de dio:** sin interceptores ni cancelación (necesaria para el debounce de cotización).
- **freezed + json_serializable:** menos código manual, pero añade `build_runner`; se puede adoptar más adelante.

## Consecuencias

- (+) Features aisladas y testeables; la UI no conoce HTTP.
- (+) Cancelación de cotizaciones obsoletas con `CancelToken`.
- (−) Más archivos por feature; el carrito se pierde al cerrar la app (aceptable: no se pidió persistencia).
