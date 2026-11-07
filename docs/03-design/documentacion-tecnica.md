# Documentación técnica — Fase 3 (Diseño UX/UI)

Guía para `flutter-dev` (fase 5) sobre cómo implementar el diseño. Cubre solo lo que añade el diseño; la arquitectura general está en `docs/02-architecture/architecture.md`.

## 1. Visión técnica

App Flutter de escritorio **solo Windows** (`--platforms=windows`), Material 3, locale `es`, tema claro azul marino, `NavigationRail` por rol, feature-first con Riverpod y go_router (ADR-007). La UI **no calcula** precios, calorías, IVA ni reglas de armado: los toma de `POST /orders/quote` (`valid`, `violations`, `items`, `totals`, `stock`) y de `OrderDetail` (snapshots). Móvil, web, Linux y macOS fuera de alcance.

## 2. Arquitectura y componentes

| Capa                      | Piezas de diseño                                                                                                                                                                                                                                                                                                |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `core/theme/`             | `app_colors.dart` (`AppColors.lightScheme`, `AppSemanticColors`), `app_theme.dart` (`buildLightTheme()`), `app_spacing.dart` (tokens 4/8/12/16/24/32/48). Código de referencia en `design-system.md` §5.                                                                                                        |
| `core/layout/`            | `breakpoints.dart`: `desktopCompact` (1024–1279), `desktopStandard` (1280–1599), `desktopWide` (≥ 1600); `ResponsiveShell` elige rail compacto/extendido.                                                                                                                                                       |
| `core/widgets/`           | `AppShell`, `GoodPizzaLogo`, `AsyncValueView`, `ErrorBanner`, `EmptyState`, `MoneyText`, `OrderStatusChip`, `AvailabilityChip`, `StockBadge`, `PortionStepper`, `QuantityStepper`, `IngredientCheckRow`, `PizzaSummaryPanel`, `TotalsCard`, `ReceiptView`, `ConfirmDialog`, `ShortcutsHelpDialog`, `FocusRing`. |
| `core/errors/`            | `ApiException(code, message, details)` y `ErrorMessages.forCode(code, details)` con la tabla de `screens.md` §6.1; `ViolationMessages` con §6.2.                                                                                                                                                                |
| `core/shortcuts/`         | `AppShortcuts` (`Shortcuts`/`Actions`, `Intent`s) según `responsive.md` §5.                                                                                                                                                                                                                                     |
| `features/*/presentation` | Una página por pantalla S-01..S-12; S-13 = `OrderDetailPage` con `ReceiptView` (reutilizada en S-12).                                                                                                                                                                                                           |

Reglas de implementación:

1. Toda pantalla remota usa `AsyncValueView` con tres estados (cargando, vacío, error + reintentar).
2. La UI decide por `ApiException.code`, nunca por `message`; para códigos de negocio muestra `message` del servidor y usa el texto del diseño como respaldo.
3. Cotización en vivo: `PizzaBuilderController` mantiene estado local inmediato y llama a `quote` con debounce 150 ms y `CancelToken`; mientras responde muestra el último valor con "Calculando…".
4. Límite local de porciones (entrada, no regla de cálculo): `min(3 − porcionesDeReceta, stockDisponible)`; cantidad 1..20. La validación definitiva es del servidor.
5. Predefinida personalizada: se envía `extras[].portions = porciones − porcionesDeReceta` (solo > 0); masa y salsa bloqueadas.
6. Confirmar: `POST /orders` con `expectedTotal = totals.total`; manejar `INSUFFICIENT_STOCK`, `PRICE_CHANGED` y `PIZZA_RULES_VIOLATED` como en `screens.md` S-05.
7. Importes: strings decimales del API; `MoneyText` solo formatea (`"7.50"` → `$ 7.50`); no usar `double` para dinero. Formato centralizado en `money_format.dart` (PA-UX-01).
8. El comprobante no incluye ninguna acción de imprimir/exportar (S-22) y usa `SelectableText`.

## 3. Tecnologías y versiones

| Componente                          | Tecnología                                            | Versión                                                                                                                    |
| ----------------------------------- | ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| UI                                  | Flutter (Material 3, solo Windows)                    | La instalada por el equipo (estable); `CardTheme`/`DialogTheme` pueden ser `CardThemeData`/`DialogThemeData` según versión |
| Estado                              | `flutter_riverpod`                                    | según `pubspec` de la fase 5                                                                                               |
| Navegación                          | `go_router`                                           | idem                                                                                                                       |
| HTTP                                | `dio`                                                 | idem                                                                                                                       |
| Logo                                | `flutter_svg`                                         | idem (no renderiza `<text>`)                                                                                               |
| i18n y formato                      | `flutter_localizations`, `intl`                       | idem                                                                                                                       |
| Tipografía                          | Segoe UI (sistema Windows)                            | —                                                                                                                          |
| Pruebas                             | `flutter_test`, `mocktail`                            | idem                                                                                                                       |
| Ventana mínima (opcional, PA-UX-02) | runner nativo (`WM_GETMINMAXINFO`) o `window_manager` | por decidir                                                                                                                |

Las versiones exactas las fija la fase 5; no se añaden dependencias a las de `architecture.md` §3.1 sin aprobación (ver PA-UX-02).

## 4. Estructura de carpetas y activos

```
frontend/
├── assets/brand/
│   ├── good_pizza_logo.svg          # copia de docs/03-design/assets/logo-good-pizza.svg
│   └── good_pizza_logo_mono.svg     # copia de logo-good-pizza-mono.svg (opcional)
├── pubspec.yaml                     # flutter: assets: [assets/brand/]
└── lib/core/{theme,layout,widgets,errors,shortcuts}/
```

`logo-good-pizza-horizontal.svg` **no** se copia a la app (usa `<text>`).

## 5. Configuración y variables de entorno

Sin cambios en esta fase. Frontend: `API_URL` por `--dart-define` (por defecto `http://localhost:3000/api/v1`). Sin secretos en el frontend ni en estos documentos; `backend/.env.local` no se lee.

## 6. API / Interfaces consumidas por la UI

| Método             | Ruta                                   | Auth    | Pantallas              | Errores que la UI debe tratar                                                                                         |
| ------------------ | -------------------------------------- | ------- | ---------------------- | --------------------------------------------------------------------------------------------------------------------- |
| POST               | `/auth/login`                          | Pública | S-01                   | `INVALID_CREDENTIALS`, `FORBIDDEN`, `RATE_LIMITED`, `VALIDATION_ERROR`                                                |
| POST               | `/auth/register`                       | Pública | S-02                   | `EMAIL_ALREADY_EXISTS`, `VALIDATION_ERROR`, `RATE_LIMITED`                                                            |
| GET                | `/auth/me`                             | Auth    | arranque               | `UNAUTHENTICATED`, `TOKEN_EXPIRED`                                                                                    |
| GET                | `/sizes`, `/ingredient-categories`     | Auth    | S-03, S-04, S-07, S-08 | genéricos                                                                                                             |
| GET                | `/vat-rates`                           | ADMIN   | S-08                   | `FORBIDDEN`                                                                                                           |
| GET                | `/ingredients`                         | Auth    | S-04, S-07, S-10       | `VALIDATION_ERROR`                                                                                                    |
| POST / PUT         | `/ingredients`, `/ingredients/:id`     | ADMIN   | S-08                   | `INGREDIENT_CODE_EXISTS`, `MISSING_SIZE_VALUES`, `INVALID_VAT_RATE`, `INGREDIENT_CATEGORY_LOCKED`, `VALIDATION_ERROR` |
| PATCH              | `/ingredients/:id/stock`, `/status`    | ADMIN   | S-07                   | `STOCK_WOULD_BE_NEGATIVE`, `MISSING_SIZE_VALUES`                                                                      |
| GET                | `/preset-pizzas`, `/preset-pizzas/:id` | Auth    | S-03, S-04, S-09, S-10 | `NOT_FOUND`                                                                                                           |
| POST / PUT / PATCH | `/preset-pizzas…`                      | ADMIN   | S-10, S-09             | `PRESET_CODE_EXISTS`, `PRESET_NAME_EXISTS`, `INVALID_RECIPE`                                                          |
| POST               | `/orders/quote`                        | Auth    | S-04, S-05, S-10       | `VALIDATION_ERROR` (el resto va en `violations`)                                                                      |
| POST               | `/orders`                              | CLIENT  | S-05                   | `INSUFFICIENT_STOCK`, `PRICE_CHANGED`, `PIZZA_RULES_VIOLATED`, `FORBIDDEN`                                            |
| GET                | `/orders`, `/orders/:id`               | Auth    | S-06, S-11, S-12, S-13 | `NOT_FOUND`                                                                                                           |
| PATCH              | `/orders/:id/status`                   | ADMIN   | S-12                   | `INVALID_STATUS_TRANSITION`, `NOT_FOUND`, `FORBIDDEN`                                                                 |

Contrato completo: `docs/02-architecture/api-contract.md`. No se solicitan cambios al contrato.

## 7. Base de datos

Sin cambios. Ver `diagrama-er.md` (ER de la fase 2 y trazabilidad pantalla–entidad).

## 8. Instalación y ejecución

Para el equipo de la fase 5 (comandos del prompt del proyecto):

```
cd frontend
flutter create --org com.pizzeria --project-name good_pizza --platforms=windows .
flutter run -d windows
```

Nombre visible "Good Pizza" (título de ventana en `windows/runner/main.cpp` y `MaterialApp.title`). En esta fase de diseño no se ejecutó ningún comando.

## 9. Pruebas

Ver `pruebas-unitarias.md`: 38 verificaciones de consistencia (por revisión y cálculo manual) y 30 casos de widget/funcionalidad (WT-01..WT-30) para automatizar, incluido el flujo "personalizar pizza hasta generar la orden". Criterio de la skill: no se inventan resultados; se ejecuta `flutter test` y se reporta la salida real.

## 10. Seguridad

- Tokens solo en `flutter_secure_storage`; nunca en logs ni en estado visible.
- La UI no oculta como mecanismo de seguridad: aunque el rail cambie por rol, la autorización real es del backend (403/404).
- Pedido ajeno: `404 NOT_FOUND` se muestra como "No encontramos este pedido." sin revelar existencia.
- Mensajes de login genéricos (US-02).
- Sin contraseñas ni valores de `.env.local` en la documentación o el código.

## 11. Despliegue y operación

Fuera de alcance (sin DevOps/Docker). Ejecución local en el PC del local con `flutter run -d windows` o compilación Windows (`flutter build windows`) a decidir en fases posteriores.

## 12. Decisiones (ADR) y deuda técnica

- Respeta ADR-002 (motor único y cotización), ADR-007 (frontend), ADR-008 (dinero) y ADR-010 (baja lógica).
- Decisiones de diseño D-UX-01..09 en `entregable.md` §4; preguntas abiertas PA-UX-01..09 en §5.
- Deuda/pendientes: modo oscuro (fuera de alcance); tamaño mínimo de ventana (PA-UX-02); actualización automática del estado (PA-UX-07); capturas del manual (fase 5).
