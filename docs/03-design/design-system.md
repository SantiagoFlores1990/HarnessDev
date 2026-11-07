# Sistema de diseño — Good Pizza

- **Fase:** 3 (Diseño UX/UI) · **Versión:** 1.0 · **Fecha:** 2026-11-06
- **Plataforma:** app de escritorio **solo Windows** (Flutter, Material 3, español, USD con 2 decimales). Móvil, web, Linux y macOS están fuera de alcance (RNF-07).
- **Modo:** **solo claro** (RNF-05, "modo claro"). El modo oscuro queda fuera de alcance; `MaterialApp.themeMode = ThemeMode.light` y la estructura de tokens permite agregarlo después sin cambiar los widgets.

> Metodología de contraste: todas las razones se calcularon con la fórmula WCAG 2.1 (luminancia relativa con linealización sRGB; razón = (L1 + 0,05) / (L2 + 0,05)) **a mano**, porque en esta fase no hay entorno de ejecución. Se redondean a 2 decimales. Se recomienda que `flutter-dev` agregue la prueba `contrast_test.dart` (ver `pruebas-unitarias.md`, WT-01) que recalcule estas razones desde `AppColors` y falle si bajan del umbral. Umbrales: texto normal ≥ 4,5:1 (AA); texto grande (≥ 18,66 px negrita o ≥ 24 px) y componentes de interfaz/foco ≥ 3:1.

## 1. Logotipo

| Archivo                                 | Uso                                                                                                                                                                                                                                                                                                                                       |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `assets/logo-good-pizza.svg`            | Emblema a color (porción de pizza con pepperoni sobre círculo azul marino). Para la app (`flutter_svg`): pantalla de login/registro (128 px), cabecera del NavigationRail (40 px extendido / 32 px compacto) y encabezado del comprobante (56 px). Copiar a `frontend/assets/brand/good_pizza_logo.svg` (ruta de `architecture.md` §3.2). |
| `assets/logo-good-pizza-mono.svg`       | Variante monocroma `#0A2A5E` con fondo transparente. Para fondos claros de un solo color o si se necesita una versión de una tinta.                                                                                                                                                                                                       |
| `assets/logo-good-pizza-horizontal.svg` | Logotipo horizontal con la palabra "Good Pizza". **Solo documentación/vista previa**: usa `<text>`, que `flutter_svg` no renderiza.                                                                                                                                                                                                       |

Reglas:

- `flutter_svg` no renderiza `<text>`: en la app el logotipo se compone con el widget `GoodPizzaLogo` = emblema SVG + `Text("Good Pizza")` (estilo `titleLarge`, peso 700, color `primary`). Así el texto es real, seleccionable por el lector de pantalla y respeta la fuente.
- Zona de respeto: margen libre mínimo = 1/4 del diámetro del emblema. Tamaño mínimo: 24 px de alto.
- Semántica: `Semantics(label: 'Good Pizza', image: true)` en el emblema cuando va solo; si va junto al texto "Good Pizza", el emblema se marca como decorativo (`excludeSemantics: true`) para no leer dos veces.
- Colores del emblema (decorativos, el logotipo está exento de contraste mínimo, pero el texto asociado cumple AA): azul marino `#0A2A5E`, anillo `#D6E3FF`, corteza `#E8A33A`, queso `#FFD36B`, pepperoni `#D64530`.

## 2. Paleta (modo claro)

Azul marino como color de marca. Todos los pares texto/fondo usados por la UI figuran en la tabla de contraste (§2.4).

### 2.1 Roles de color (Material 3 `ColorScheme`)

| Rol                       | Hex       | Uso                                                                     |
| ------------------------- | --------- | ----------------------------------------------------------------------- |
| `primary`                 | `#0A2A5E` | Botones principales, NavigationRail, enlaces, énfasis de marca.         |
| `onPrimary`               | `#FFFFFF` | Texto/iconos sobre `primary`.                                           |
| `primaryContainer`        | `#D6E3FF` | Indicador seleccionado del rail, chips "En preparación", resaltados.    |
| `onPrimaryContainer`      | `#001B3F` | Texto sobre `primaryContainer`.                                         |
| `secondary`               | `#3B5A8C` | Acentos secundarios, botones tonales, encabezados de sección.           |
| `onSecondary`             | `#FFFFFF` | Sobre `secondary`.                                                      |
| `secondaryContainer`      | `#DCE6F5` | Botones tonales, filtros seleccionados, fila seleccionada.              |
| `onSecondaryContainer`    | `#0E1D33` | Sobre `secondaryContainer`.                                             |
| `tertiary`                | `#8C4A00` | Acento cálido (ámbar oscuro): avisos de stock bajo/precio, insignias.   |
| `onTertiary`              | `#FFFFFF` | Sobre `tertiary`.                                                       |
| `tertiaryContainer`       | `#FFDCC0` | Fondo de avisos cálidos.                                                |
| `onTertiaryContainer`     | `#2E1500` | Sobre `tertiaryContainer`.                                              |
| `error`                   | `#B3261E` | Errores, acciones destructivas (desactivar).                            |
| `onError`                 | `#FFFFFF` | Sobre `error`.                                                          |
| `errorContainer`          | `#F9DEDC` | Fondo de banners de error.                                              |
| `onErrorContainer`        | `#410E0B` | Texto sobre `errorContainer`.                                           |
| `surface`                 | `#F8F9FD` | Fondo de la aplicación.                                                 |
| `onSurface`               | `#1A1C20` | Texto principal.                                                        |
| `onSurfaceVariant`        | `#43474F` | Texto secundario, etiquetas, placeholders.                              |
| `surfaceDim`              | `#D8DAE0` | Fondos atenuados (no usado en contenido).                               |
| `surfaceBright`           | `#F8F9FD` | Igual a `surface`.                                                      |
| `surfaceContainerLowest`  | `#FFFFFF` | Tarjetas, campos de texto, comprobante.                                 |
| `surfaceContainerLow`     | `#F2F3F9` | Paneles laterales (resumen), cabeceras de tabla.                        |
| `surfaceContainer`        | `#ECEEF4` | Barras, zonas agrupadas.                                                |
| `surfaceContainerHigh`    | `#E6E8EE` | Hover de filas.                                                         |
| `surfaceContainerHighest` | `#E0E3EB` | Chips neutros, campos deshabilitados.                                   |
| `outline`                 | `#6B707B` | Bordes de campos y checkboxes (componente de interfaz, ≥ 3:1).          |
| `outlineVariant`          | `#C3C6CF` | Separadores y bordes decorativos (nunca único indicador de un control). |
| `inverseSurface`          | `#2E3036` | Snackbars.                                                              |
| `onInverseSurface`        | `#F0F0F7` | Texto de snackbars.                                                     |
| `inversePrimary`          | `#AAC7FF` | Acción de snackbar.                                                     |
| `scrim` / `shadow`        | `#000000` | Capas modales / sombras.                                                |
| `surfaceTint`             | `#0A2A5E` | Tinte de elevación.                                                     |

### 2.2 Colores semánticos de estado (extensión de tema)

M3 no define éxito ni advertencia; se añaden vía `ThemeExtension<AppSemanticColors>`.

| Rol                  | Hex       | Uso                                              |
| -------------------- | --------- | ------------------------------------------------ |
| `success`            | `#1B6B3A` | Texto/iconos de éxito, "Disponible".             |
| `onSuccess`          | `#FFFFFF` | Sobre `success`.                                 |
| `successContainer`   | `#C8F0D4` | Chip "Entregado", banner de éxito.               |
| `onSuccessContainer` | `#00210E` | Sobre `successContainer`.                        |
| `warning`            | `#8A5A00` | Texto/iconos de advertencia, "Pendiente".        |
| `onWarning`          | `#FFFFFF` | Sobre `warning`.                                 |
| `warningContainer`   | `#FFE8B8` | Chip "Pendiente", banner de advertencia.         |
| `onWarningContainer` | `#2B1B00` | Sobre `warningContainer`.                        |
| `focusRing`          | `#1F5FD0` | Anillo de foco de teclado (sobre fondos claros). |
| `focusRingOnDark`    | `#FFD166` | Anillo de foco sobre el rail azul marino.        |
| `railUnselected`     | `#C9D6EE` | Iconos/etiquetas no seleccionados del rail.      |

Estado del pedido (color + icono + texto; el color nunca es el único indicador):

| Estado (API)     | Etiqueta       | Fondo / texto                             | Icono                                      |
| ---------------- | -------------- | ----------------------------------------- | ------------------------------------------ |
| `PENDING`        | Pendiente      | `warningContainer` / `onWarningContainer` | `schedule`                                 |
| `IN_PREPARATION` | En preparación | `primaryContainer` / `onPrimaryContainer` | `soup_kitchen` (o `local_fire_department`) |
| `DELIVERED`      | Entregado      | `successContainer` / `onSuccessContainer` | `check_circle`                             |

### 2.3 Pizza: disponibilidad e IVA

| Elemento                | Representación                                                                          |
| ----------------------- | --------------------------------------------------------------------------------------- |
| Disponible              | Chip `successContainer` con icono `check_circle` y texto "Disponible".                  |
| No disponible / Agotado | Chip `errorContainer` con icono `block` y texto "No disponible" / "Agotado".            |
| IVA 15 % / IVA 0 %      | Chip neutro (`surfaceContainerHighest` / `onSurface`) con texto "IVA 15 %" o "IVA 0 %". |

### 2.4 Tabla de contraste verificada (WCAG 2.1 AA)

| #   | Combinación (texto / fondo)                                    | Hex                   | Razón | Umbral | Resultado |
| --- | -------------------------------------------------------------- | --------------------- | ----- | ------ | --------- |
| 1   | `onPrimary` / `primary`                                        | `#FFFFFF` / `#0A2A5E` | 13,94 | 4,5    | AA y AAA  |
| 2   | `onPrimaryContainer` / `primaryContainer`                      | `#001B3F` / `#D6E3FF` | 13,26 | 4,5    | AA y AAA  |
| 3   | `primary` / `surface` (enlaces, títulos)                       | `#0A2A5E` / `#F8F9FD` | 13,25 | 4,5    | AA y AAA  |
| 4   | `primary` / `surfaceContainerLowest`                           | `#0A2A5E` / `#FFFFFF` | 13,94 | 4,5    | AA y AAA  |
| 5   | `primary` / `primaryContainer`                                 | `#0A2A5E` / `#D6E3FF` | 10,82 | 4,5    | AA y AAA  |
| 6   | `onSecondary` / `secondary`                                    | `#FFFFFF` / `#3B5A8C` | 6,94  | 4,5    | AA        |
| 7   | `secondary` / `surface`                                        | `#3B5A8C` / `#F8F9FD` | 6,59  | 4,5    | AA        |
| 8   | `onSecondaryContainer` / `secondaryContainer`                  | `#0E1D33` / `#DCE6F5` | 13,42 | 4,5    | AA y AAA  |
| 9   | `onTertiary` / `tertiary`                                      | `#FFFFFF` / `#8C4A00` | 6,79  | 4,5    | AA        |
| 10  | `onTertiaryContainer` / `tertiaryContainer`                    | `#2E1500` / `#FFDCC0` | 13,28 | 4,5    | AA y AAA  |
| 11  | `onSurface` / `surface`                                        | `#1A1C20` / `#F8F9FD` | 16,22 | 4,5    | AA y AAA  |
| 12  | `onSurface` / `surfaceContainerLowest`                         | `#1A1C20` / `#FFFFFF` | 17,06 | 4,5    | AA y AAA  |
| 13  | `onSurface` / `surfaceContainerLow`                            | `#1A1C20` / `#F2F3F9` | 15,41 | 4,5    | AA y AAA  |
| 14  | `onSurface` / `surfaceContainer`                               | `#1A1C20` / `#ECEEF4` | 14,71 | 4,5    | AA y AAA  |
| 15  | `onSurface` / `surfaceContainerHigh`                           | `#1A1C20` / `#E6E8EE` | 13,93 | 4,5    | AA y AAA  |
| 16  | `onSurfaceVariant` / `surface`                                 | `#43474F` / `#F8F9FD` | 8,86  | 4,5    | AA y AAA  |
| 17  | `onSurfaceVariant` / `surfaceContainerLowest`                  | `#43474F` / `#FFFFFF` | 9,32  | 4,5    | AA y AAA  |
| 18  | `onSurfaceVariant` / `surfaceContainerLow`                     | `#43474F` / `#F2F3F9` | 8,42  | 4,5    | AA y AAA  |
| 19  | `onSurfaceVariant` / `surfaceContainer`                        | `#43474F` / `#ECEEF4` | 8,04  | 4,5    | AA y AAA  |
| 20  | `onSurfaceVariant` / `surfaceContainerHighest`                 | `#43474F` / `#E0E3EB` | 7,26  | 4,5    | AA y AAA  |
| 21  | `onError` / `error`                                            | `#FFFFFF` / `#B3261E` | 6,53  | 4,5    | AA        |
| 22  | `error` / `surface` (texto de error en campo)                  | `#B3261E` / `#F8F9FD` | 6,21  | 4,5    | AA        |
| 23  | `error` / `surfaceContainerLowest`                             | `#B3261E` / `#FFFFFF` | 6,54  | 4,5    | AA        |
| 24  | `onErrorContainer` / `errorContainer`                          | `#410E0B` / `#F9DEDC` | 12,77 | 4,5    | AA y AAA  |
| 25  | `error` / `errorContainer`                                     | `#B3261E` / `#F9DEDC` | 5,14  | 4,5    | AA        |
| 26  | `onSuccess` / `success`                                        | `#FFFFFF` / `#1B6B3A` | 6,54  | 4,5    | AA        |
| 27  | `success` / `surface`                                          | `#1B6B3A` / `#F8F9FD` | 6,22  | 4,5    | AA        |
| 28  | `onSuccessContainer` / `successContainer`                      | `#00210E` / `#C8F0D4` | 13,78 | 4,5    | AA y AAA  |
| 29  | `success` / `successContainer`                                 | `#1B6B3A` / `#C8F0D4` | 5,26  | 4,5    | AA        |
| 30  | `onWarning` / `warning`                                        | `#FFFFFF` / `#8A5A00` | 5,93  | 4,5    | AA        |
| 31  | `warning` / `surface`                                          | `#8A5A00` / `#F8F9FD` | 5,63  | 4,5    | AA        |
| 32  | `onWarningContainer` / `warningContainer`                      | `#2B1B00` / `#FFE8B8` | 13,88 | 4,5    | AA y AAA  |
| 33  | `warning` / `warningContainer`                                 | `#8A5A00` / `#FFE8B8` | 4,94  | 4,5    | AA        |
| 34  | `railUnselected` / `primary` (rail)                            | `#C9D6EE` / `#0A2A5E` | 9,52  | 4,5    | AA y AAA  |
| 35  | `onInverseSurface` / `inverseSurface` (snackbar)               | `#F0F0F7` / `#2E3036` | 11,63 | 4,5    | AA y AAA  |
| 36  | `inversePrimary` / `inverseSurface` (acción snackbar)          | `#AAC7FF` / `#2E3036` | 7,74  | 4,5    | AA y AAA  |
| 37  | `outline` / `surface` (borde de campo, checkbox)               | `#6B707B` / `#F8F9FD` | 4,72  | 3 (UI) | AA        |
| 38  | `outline` / `surfaceContainerLowest` (campo blanco)            | `#6B707B` / `#FFFFFF` | 4,97  | 3 (UI) | AA        |
| 39  | `outline` / `surfaceContainerLow`                              | `#6B707B` / `#F2F3F9` | 4,49  | 3 (UI) | AA        |
| 40  | `focusRing` / `surface`                                        | `#1F5FD0` / `#F8F9FD` | 5,53  | 3 (UI) | AA        |
| 41  | `focusRing` / `surfaceContainerLowest`                         | `#1F5FD0` / `#FFFFFF` | 5,82  | 3 (UI) | AA        |
| 42  | `focusRing` / `primaryContainer`                               | `#1F5FD0` / `#D6E3FF` | 4,52  | 3 (UI) | AA        |
| 43  | `focusRing` / `surfaceContainerHighest`                        | `#1F5FD0` / `#E0E3EB` | 4,53  | 3 (UI) | AA        |
| 44  | `focusRingOnDark` / `primary` (foco en rail)                   | `#FFD166` / `#0A2A5E` | 9,67  | 3 (UI) | AA        |
| 45  | Indicador seleccionado del rail `primaryContainer` / `primary` | `#D6E3FF` / `#0A2A5E` | 10,82 | 3 (UI) | AA        |

Reglas derivadas:

- `outlineVariant` (`#C3C6CF`) es decorativo (separadores); un control nunca depende solo de él para ser reconocible: los campos y checkboxes usan `outline`.
- Los controles deshabilitados están exentos de contraste (WCAG 1.4.3), pero el motivo se comunica siempre con texto de contraste completo ("Agotado", "No disponible", "Parte de la receta").
- Prohibido usar `tertiary`, `warning` o `success` como único indicador: siempre con icono y texto.

## 3. Tipografía

Fuente: **Segoe UI** (fuente del sistema en Windows; no se empaqueta, sin licencias adicionales). Fallback: `Roboto`, `Arial`, `sans-serif`. Cifras: usar `FontFeature.tabularFigures()` en importes, calorías, stock y tablas para alinear columnas.

Escala (px lógicos; base de escritorio 14 px):

| Estilo M3        | Tamaño / interlineado | Peso | Uso                                                              |
| ---------------- | --------------------- | ---- | ---------------------------------------------------------------- |
| `displaySmall`   | 32 / 40               | 600  | Número TOTAL del comprobante en pantallas amplias (opcional).    |
| `headlineMedium` | 28 / 36               | 600  | Título de pantalla de acceso ("Iniciar sesión").                 |
| `headlineSmall`  | 24 / 32               | 600  | Título de página.                                                |
| `titleLarge`     | 20 / 28               | 600  | Título de tarjeta, "Good Pizza" del logotipo.                    |
| `titleMedium`    | 16 / 24               | 600  | Subtítulos, nombres de ingrediente en tablas.                    |
| `titleSmall`     | 14 / 20               | 600  | Cabeceras de tabla.                                              |
| `bodyLarge`      | 16 / 24               | 400  | Texto destacado, TOTAL del resumen.                              |
| `bodyMedium`     | 14 / 20               | 400  | Texto base.                                                      |
| `bodySmall`      | 12 / 16               | 400  | Notas, ayudas, pie del comprobante. Mínimo absoluto del sistema. |
| `labelLarge`     | 14 / 20               | 600  | Botones, chips.                                                  |
| `labelMedium`    | 12 / 16               | 600  | Etiquetas de campo, insignias.                                   |

Reglas: nunca por debajo de 12 px; el texto respeta el factor de escala de texto de Windows (`MediaQuery.textScaler`) hasta 200 % sin truncar información esencial (los contenedores crecen; usar `Flexible`/`Wrap`, no alturas fijas en texto).

## 4. Espaciado, forma y elevación

Rejilla base de 4 px. Tokens (`AppSpacing`):

| Token | Valor | Uso                                           |
| ----- | ----- | --------------------------------------------- |
| `xxs` | 4     | Separación icono–texto.                       |
| `xs`  | 8     | Entre elementos relacionados.                 |
| `sm`  | 12    | Padding interno de chips/filas densas.        |
| `md`  | 16    | Padding de tarjetas, separación entre campos. |
| `lg`  | 24    | Padding de página, entre tarjetas.            |
| `xl`  | 32    | Entre secciones.                              |
| `xxl` | 48    | Márgenes de pantallas de acceso.              |

- **Márgenes de página:** 24 px (≥ 1280 px: 32 px). Ancho máximo de contenido 1440 px, centrado.
- **Radios:** botones y campos 8; tarjetas y diálogos 12; chips 8 (`StadiumBorder` no se usa para mantener densidad de escritorio); logotipo circular.
- **Elevación:** tarjetas planas (nivel 0) con borde `outlineVariant` 1 px sobre `surfaceContainerLowest`; diálogos nivel 3; menús nivel 2. Sin sombras decorativas.
- **Densidad:** `VisualDensity.standard`; altura de botones 40; campos de texto 48 (alto de fila de tabla 52; fila de ingrediente del armado 56).
- **Iconos:** Material Symbols/`Icons` redondeados, 20 px en botones, 24 px en navegación.

## 5. ThemeData Material 3 (esquema sugerido)

`frontend/lib/core/theme/app_colors.dart` y `app_theme.dart`. Código de referencia para `flutter-dev` (se puede ajustar a la versión de Flutter instalada; los campos `surfaceContainer*` existen desde Flutter 3.22).

```dart
// app_colors.dart
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const navy = Color(0xFF0A2A5E);
  static const lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF0A2A5E),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD6E3FF),
    onPrimaryContainer: Color(0xFF001B3F),
    secondary: Color(0xFF3B5A8C),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFDCE6F5),
    onSecondaryContainer: Color(0xFF0E1D33),
    tertiary: Color(0xFF8C4A00),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFFDCC0),
    onTertiaryContainer: Color(0xFF2E1500),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surface: Color(0xFFF8F9FD),
    onSurface: Color(0xFF1A1C20),
    onSurfaceVariant: Color(0xFF43474F),
    surfaceDim: Color(0xFFD8DAE0),
    surfaceBright: Color(0xFFF8F9FD),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF2F3F9),
    surfaceContainer: Color(0xFFECEEF4),
    surfaceContainerHigh: Color(0xFFE6E8EE),
    surfaceContainerHighest: Color(0xFFE0E3EB),
    outline: Color(0xFF6B707B),
    outlineVariant: Color(0xFFC3C6CF),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF2E3036),
    onInverseSurface: Color(0xFFF0F0F7),
    inversePrimary: Color(0xFFAAC7FF),
    surfaceTint: Color(0xFF0A2A5E),
  );
}

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success, required this.onSuccess,
    required this.successContainer, required this.onSuccessContainer,
    required this.warning, required this.onWarning,
    required this.warningContainer, required this.onWarningContainer,
    required this.focusRing, required this.focusRingOnDark,
    required this.railUnselected,
  });

  final Color success, onSuccess, successContainer, onSuccessContainer;
  final Color warning, onWarning, warningContainer, onWarningContainer;
  final Color focusRing, focusRingOnDark, railUnselected;

  static const light = AppSemanticColors(
    success: Color(0xFF1B6B3A), onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFC8F0D4), onSuccessContainer: Color(0xFF00210E),
    warning: Color(0xFF8A5A00), onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFFE8B8), onWarningContainer: Color(0xFF2B1B00),
    focusRing: Color(0xFF1F5FD0), focusRingOnDark: Color(0xFFFFD166),
    railUnselected: Color(0xFFC9D6EE),
  );

  @override
  AppSemanticColors copyWith({Color? success}) => this; // implementar el resto
  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) => this;
}
```

```dart
// app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

ThemeData buildLightTheme() {
  const scheme = AppColors.lightScheme;
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Segoe UI',
    fontFamilyFallback: const ['Roboto', 'Arial'],
    scaffoldBackgroundColor: scheme.surface,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded, // objetivo >= 48
    extensions: const [AppSemanticColors.light],
  );
  final textTheme = base.textTheme.copyWith(
    displaySmall: base.textTheme.displaySmall?.copyWith(fontSize: 32, height: 40 / 32, fontWeight: FontWeight.w600),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(fontSize: 28, height: 36 / 28, fontWeight: FontWeight.w600),
    headlineSmall: base.textTheme.headlineSmall?.copyWith(fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w600),
    titleLarge: base.textTheme.titleLarge?.copyWith(fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w600),
    titleMedium: base.textTheme.titleMedium?.copyWith(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w600),
    titleSmall: base.textTheme.titleSmall?.copyWith(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 16, height: 24 / 16),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 14, height: 20 / 14),
    bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 12, height: 16 / 12),
    labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600),
    labelMedium: base.textTheme.labelMedium?.copyWith(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600),
  ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

  final focusRing = AppSemanticColors.light.focusRing;

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.headlineSmall,
    ),
    cardTheme: CardTheme(
      color: scheme.surfaceContainerLowest,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.primary,
      indicatorColor: scheme.primaryContainer,
      selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer, size: 24),
      unselectedIconTheme: const IconThemeData(color: Color(0xFFC9D6EE), size: 24),
      selectedLabelTextStyle: textTheme.labelLarge?.copyWith(color: scheme.onPrimary),
      unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(color: const Color(0xFFC9D6EE)),
      useIndicator: true,
      minWidth: 80,
      minExtendedWidth: 240,
      groupAlignment: -1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: scheme.outline)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: scheme.outline)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: focusRing, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: scheme.error)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: scheme.error, width: 2)),
      labelStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      helperStyle: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(88, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(88, 40),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(64, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      side: BorderSide(color: scheme.outline, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHighest,
      labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.secondaryContainer,
        selectedForegroundColor: scheme.onSecondaryContainer,
        side: BorderSide(color: scheme.outline),
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(scheme.surfaceContainerLow),
      dataRowMinHeight: 52,
      dataRowMaxHeight: 64,
      headingTextStyle: textTheme.titleSmall,
      dividerThickness: 1,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      actionTextColor: scheme.inversePrimary,
      width: 480,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(color: scheme.inverseSurface, borderRadius: BorderRadius.circular(6)),
      textStyle: textTheme.bodySmall?.copyWith(color: scheme.onInverseSurface),
    ),
    focusColor: focusRing.withValues(alpha: 0.16),
    hoverColor: scheme.primary.withValues(alpha: 0.08),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
  );
}
```

Notas para `flutter-dev`:

- Según la versión del SDK, `CardTheme`/`DialogTheme` pueden llamarse `CardThemeData`/`DialogThemeData`; ajustar sin cambiar valores.
- El anillo de foco global se implementa con `FocusableActionDetector`/`Focus` + `DecoratedBox` (borde 2 px `focusRing`, separación 2 px) en componentes personalizados (`FocusRing`), y con `focusedBorder` o `side` en los widgets Material. En el rail se usa `focusRingOnDark`.
- Locale: `MaterialApp(locale: Locale('es'), supportedLocales: [Locale('es')], localizationsDelegates: GlobalMaterialLocalizations.delegates)`; formato monetario `"$ 7.50"` (ver Preguntas abiertas PA-UX-01).

## 6. Componentes del sistema (catálogo)

Widgets reutilizables en `frontend/lib/core/widgets/` (nombres de `architecture.md` §3.2 y los nuevos de diseño).

| Componente            | Descripción                                                                                                                                                                        | Estados / notas                                                                                                                     |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `AppShell`            | `Scaffold` + `NavigationRail` (por rol) + área de contenido con ancho máximo 1440. Cabecera del rail: logotipo; pie: nombre del usuario, rol y "Cerrar sesión".                    | Rail extendido ≥ 1280 px, compacto con etiquetas 1024–1279 px.                                                                      |
| `GoodPizzaLogo`       | Emblema SVG + texto "Good Pizza".                                                                                                                                                  | Variantes `full` (login), `rail`, `receipt`.                                                                                        |
| `AsyncValueView<T>`   | Renderiza `AsyncValue`: loading (skeleton/`CircularProgressIndicator` con `Semantics(liveRegion)` "Cargando…"), error (`ErrorBanner` + "Reintentar"), data (vacío → `EmptyState`). | Obligatorio en toda pantalla con datos remotos.                                                                                     |
| `ErrorBanner`         | Banner `errorContainer` con icono, mensaje en español y botón de reintento opcional.                                                                                               | `Semantics(liveRegion: true)`.                                                                                                      |
| `EmptyState`          | Icono grande + título + texto + acción primaria.                                                                                                                                   | Un texto por pantalla (ver `screens.md`).                                                                                           |
| `MoneyText`           | Importe `"$ 0.00"` a partir de string decimal; cifras tabulares; variante `total` (bodyLarge 600).                                                                                 | Nunca calcula; solo formatea.                                                                                                       |
| `OrderStatusChip`     | Chip de estado (color + icono + texto, §2.2).                                                                                                                                      | `Semantics(label: 'Estado: En preparación')`.                                                                                       |
| `AvailabilityChip`    | Disponible / No disponible / Agotado.                                                                                                                                              |                                                                                                                                     |
| `StockBadge`          | "Stock: N" junto al ingrediente; "Agotado" si 0.                                                                                                                                   | Cifras tabulares.                                                                                                                   |
| `PortionStepper`      | − [n] + con límites 1..3 (o `min`..`max`); mantiene foco; anuncia cambios.                                                                                                         | Deshabilitado si el ingrediente no está marcado; tooltip del límite ("Máximo 3 porciones por ingrediente" / "Stock disponible: N"). |
| `QuantityStepper`     | Igual, rango 1..20 (cantidad de pizzas).                                                                                                                                           | Tooltip "Máximo 20 pizzas por línea".                                                                                               |
| `IngredientCheckRow`  | Fila del armado: checkbox, nombre, `StockBadge`, precio/kcal por porción, `PortionStepper`.                                                                                        | Estados: normal, marcado, agotado (deshabilitado), bloqueado por receta (marcado, no desmarcable).                                  |
| `PizzaSummaryPanel`   | Panel "Tu pizza": selección, calorías, precio, mensajes de violación, acción.                                                                                                      | Indicador "Calculando…" durante la cotización (muestra el último valor).                                                            |
| `TotalsCard`          | Calorías totales, Subtotal 15 %, Subtotal 0 %, IVA 15 %, TOTAL.                                                                                                                    | Reutilizado en carrito y comprobante.                                                                                               |
| `ReceiptView`         | Comprobante (ver `screens.md` §S-13). Solo pantalla, sin imprimir/exportar.                                                                                                        |                                                                                                                                     |
| `ConfirmDialog`       | Diálogo de confirmación con acción primaria/destructiva y foco inicial en "Cancelar".                                                                                              |                                                                                                                                     |
| `ShortcutsHelpDialog` | Lista de atajos (F1).                                                                                                                                                              | Ver `responsive.md`.                                                                                                                |
| `FocusRing`           | Decorador de foco visible.                                                                                                                                                         | Ver accesibilidad.                                                                                                                  |

## 7. Iconografía y microcopia

- Iconos del rail: Cliente — `local_pizza` (Pizzas predefinidas), `tune` (Personalizar pizza), `shopping_cart` + `Badge` con nº de pizzas (Mi pedido), `receipt_long` (Mis pedidos). Admin — `inventory_2` (Ingredientes), `local_pizza` (Pizzas predefinidas), `receipt_long` (Pedidos).
- Importes: `$ 9.50` (símbolo, espacio, importe con 2 decimales, punto decimal — PA-UX-01). Porcentajes: `15 %` (espacio antes de `%`). Calorías: `820 kcal`. Fechas: `06/11/2026 10:04` (`dd/MM/yyyy HH:mm`, hora local del equipo).
- Tono: segunda persona informal ("Elige", "Tu pedido"), frases cortas, sin jerga técnica; los errores dicen qué pasó y qué hacer.
