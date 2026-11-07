# Adaptación de ventana y escritorio Windows — Good Pizza

- **Fase:** 3 (Diseño UX/UI) · **Versión:** 1.0 · **Fecha:** 2026-11-06

## 1. Alcance de plataforma

- La aplicación es **solo de escritorio Windows** (RNF-07, prompt del proyecto).
- **Móvil (Android/iOS), tableta, web, Linux y macOS quedan explícitamente fuera de alcance.** No se diseñan ni se prueban BottomNavigationBar, gestos táctiles específicos ni diseños para ventanas menores a 1024 px. La navegación es siempre `NavigationRail`.
- Lo que sí se diseña: **redimensionado de la ventana de escritorio**, con tres rangos de ancho, entrada por teclado y ratón, y compatibilidad con pantallas táctiles de Windows como entrada secundaria (objetivos de 48 px, ver `accesibilidad.md`).

## 2. Ventana

| Parámetro                      | Valor                                                         | Nota                                                                                 |
| ------------------------------ | ------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Tamaño inicial recomendado     | 1280 × 800 px                                                 | Cabe en pantallas de 1366 × 768 con la barra de tareas (se acepta 1280 × 720).       |
| **Tamaño mínimo recomendado**  | **1024 × 680 px**                                             | Por debajo, el diseño no está garantizado.                                           |
| Tamaño máximo                  | Sin límite; el contenido se centra con ancho máx. **1440 px** | Los fondos ocupan toda la ventana.                                                   |
| Maximizar / pantalla completa  | Soportado (`F11` opcional, no obligatorio)                    |                                                                                      |
| Alto mínimo                    | 680 px                                                        | Los paneles laterales (resumen) son sticky; con menos alto se activa scroll interno. |
| Título de ventana              | "Good Pizza"                                                  | `windows/runner/main.cpp` y `MaterialApp.title`.                                     |
| Escala de texto/DPI de Windows | 100 % a 200 %                                                 | El layout usa `Flexible`, `Wrap` y alturas mínimas, no alturas fijas en texto.       |

Aplicar el tamaño mínimo requiere una decisión de implementación (ver Preguntas abiertas PA-UX-02): modificar el runner de Windows (`WM_GETMINMAXINFO`) o añadir el paquete `window_manager`, que **no** figura en las dependencias de `architecture.md` §3.1. Hasta aprobar, el diseño se valida a 1024 × 680 como mínimo y se tolera un comportamiento degradado (scroll) por debajo.

## 3. Rangos de ancho (breakpoints de escritorio)

Se usan sobre el ancho de la ventana (`LayoutBuilder`/`MediaQuery`), no sobre el tipo de dispositivo. Archivo sugerido: `lib/core/layout/breakpoints.dart`.

| Rango           | Ancho          | Nombre            | NavigationRail                                                                                                                        | Contenido                                                                                                                                                                                                                                                                                          |
| --------------- | -------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Compacto        | 1024 – 1279 px | `desktopCompact`  | **Compacto**: 80 px, icono + etiqueta debajo (labelType: all). Logotipo 32 px sin texto. Pie: icono de usuario con tooltip y "Salir". | Márgenes 24 px. Cuadrícula de predefinidas de 2 columnas. En S-04 y S-05 el panel de resumen pasa de columna lateral a **barra inferior fija** (calorías, precio y botón); tablas de admin ocultan la columna "Código" y muestran los valores por tamaño en una sola celda `$ · kcal` en 3 líneas. |
| Estándar        | 1280 – 1599 px | `desktopStandard` | **Extendido**: 240 px, icono + etiqueta a la derecha, logotipo + "Good Pizza" en la cabecera, nombre y rol del usuario al pie.        | Márgenes 32 px. 3 columnas de predefinidas. S-04, S-05, S-12: panel de resumen lateral de 320 px (sticky).                                                                                                                                                                                         |
| Amplio          | ≥ 1600 px      | `desktopWide`     | Extendido.                                                                                                                            | Contenido centrado, máx. 1440 px. 4 columnas de predefinidas. Comprobante a 720 px centrado.                                                                                                                                                                                                       |
| Menor al mínimo | < 1024 px      | no soportado      | Rail compacto                                                                                                                         | Sin garantía: se permite scroll vertical; no hay modo móvil.                                                                                                                                                                                                                                       |

Reglas de reflujo:

- El rail nunca se convierte en barra inferior ni en `Drawer`. Entre 1024 y 1279 px puede alternarse a extendido con un botón de menú (icono ☰) en la parte superior del rail (opcional; recomendado), manteniendo la preferencia en memoria de la sesión.
- Los diálogos tienen ancho fijo 480 px (formularios cortos) o 640 px (listas); nunca ocupan toda la ventana.
- Las tablas usan scroll horizontal solo como último recurso; primero se ocultan columnas secundarias (Código, Categoría) y se muestran en el detalle.
- Redimensionar no pierde estado: la selección del armado, el contenido de formularios y el carrito se conservan (están en providers, no en el estado del widget de layout).

## 4. Navegación

| Aspecto                      | Diseño                                                                                                                                                                                       |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Componente                   | `NavigationRail` Material 3 con indicador de selección, dentro de `AppShell` (`ShellRoute`).                                                                                                 |
| Destinos                     | Cliente: Pizzas predefinidas, Personalizar pizza, Mi pedido (con `Badge` = total de pizzas), Mis pedidos. Admin: Ingredientes, Pizzas predefinidas, Pedidos.                                 |
| Cabecera                     | Logotipo (`GoodPizzaLogo`); en compacto solo el emblema.                                                                                                                                     |
| Pie                          | Nombre, rol y "Cerrar sesión" (extendido); icono con tooltip (compacto). Cerrar sesión pide confirmación si el carrito tiene pizzas.                                                         |
| Pantallas sin rail           | `/login` y `/register`.                                                                                                                                                                      |
| Rutas de detalle/formularios | Mantienen el rail y el destino padre seleccionado; incluyen botón "← Volver" y soportan `Alt+←`.                                                                                             |
| Redirecciones                | Según `go_router.redirect` (sesión y rol), ver `user-flows.md` §1.                                                                                                                           |
| Estilos del rail             | Fondo `primary` (azul marino), icono seleccionado `onPrimaryContainer` sobre indicador `primaryContainer`, no seleccionados `railUnselected` (contraste 9,52:1), etiquetas siempre visibles. |

## 5. Atajos de teclado (Windows)

Implementación: `Shortcuts` + `Actions` globales en `AppShell` (o `CallbackShortcuts`), con `Intent` por acción; los atajos con letra no se activan mientras el foco está en un campo de texto, salvo los que usan `Ctrl`. Todos se listan en el diálogo de ayuda (`F1`).

### 5.1 Globales (sesión iniciada)

| Atajo               | Acción                                                                                                                                            |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Ctrl+1` … `Ctrl+4` | Ir al destino N del rail (Cliente: 1 Predefinidas, 2 Personalizar, 3 Mi pedido, 4 Mis pedidos. Admin: 1 Ingredientes, 2 Predefinidas, 3 Pedidos). |
| `Alt+←`             | Volver (pantalla anterior).                                                                                                                       |
| `F5` o `Ctrl+R`     | Actualizar/recargar los datos de la pantalla actual.                                                                                              |
| `F1`                | Mostrar ayuda de atajos.                                                                                                                          |
| `Ctrl+Shift+Q`      | Cerrar sesión (con confirmación).                                                                                                                 |
| `Esc`               | Cerrar diálogo/menú; si no hay, quitar foco de un campo de búsqueda.                                                                              |
| `Tab` / `Mayús+Tab` | Mover el foco adelante / atrás en orden visual (izquierda a derecha, arriba a abajo; rail → contenido → panel lateral).                           |
| `F6` / `Mayús+F6`   | Saltar entre regiones: rail, contenido, panel de resumen.                                                                                         |

### 5.2 Por pantalla

| Pantalla               | Atajo                                                                                                      | Acción                                                                               |
| ---------------------- | ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| S-01, S-02             | `Enter`                                                                                                    | Enviar el formulario.                                                                |
| S-03                   | `←` `→` `↑` `↓`                                                                                            | Mover el foco entre tarjetas. `Enter`/`Espacio` activan el botón enfocado.           |
| S-04                   | `Espacio`                                                                                                  | Marcar/desmarcar la casilla enfocada.                                                |
| S-04                   | `+` / `−` (o `↑` / `↓`) con el stepper enfocado                                                            | Subir/bajar porciones o cantidad (respetando límites).                               |
| S-04                   | `Ctrl+Enter`                                                                                               | Agregar al pedido (si es válido).                                                    |
| S-04                   | `Ctrl+1/2/3` **no** se reutilizan para tamaño; el tamaño se cambia con `←`/`→` sobre el `SegmentedButton`. |                                                                                      |
| S-05                   | `Ctrl+Enter`                                                                                               | Confirmar pedido (abre el diálogo de confirmación; en el diálogo, `Enter` confirma). |
| S-05                   | `Supr` con una línea enfocada                                                                              | Quitar la línea (con "Deshacer").                                                    |
| S-06, S-07, S-09, S-11 | `↑` `↓`                                                                                                    | Mover entre filas; `Enter` abre; `Ctrl+F` enfoca la búsqueda (donde exista).         |
| S-07, S-09             | `Ctrl+N`                                                                                                   | Nuevo ingrediente / nueva pizza.                                                     |
| S-08, S-10             | `Ctrl+S`                                                                                                   | Guardar.                                                                             |
| S-12                   | `Ctrl+Enter`                                                                                               | Avanzar al siguiente estado (con confirmación).                                      |
| Diálogos               | `Enter` / `Esc`                                                                                            | Aceptar la acción enfocada / cancelar.                                               |

Reglas: ningún atajo es la única vía de una acción (siempre existe control visible); no se reasignan atajos reservados de Windows (`Alt+F4`, `Win+…`, `Ctrl+C/V/X/A/Z` en campos); los atajos con modificador se muestran en tooltips (p. ej. "Nuevo ingrediente (Ctrl+N)").

## 6. Ratón y puntero

| Elemento                       | Comportamiento                                                                                                                                                                                                                                                     |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Cursor                         | `SystemMouseCursors.click` en botones, filas clicables, tarjetas y casillas; `text` en campos; `forbidden` en elementos deshabilitados que explican su motivo (tooltip).                                                                                           |
| Hover                          | Superposición de estado: filas de tabla `surfaceContainerHigh`; tarjetas con borde `primary` y elevación sutil; botones con capa de estado M3 de 8 %; items del rail con capa de 8 %. Siempre acompañado de un cambio no cromático (borde o subrayado en enlaces). |
| Tooltips                       | A los 500 ms de hover o al enfocar con teclado; en todos los botones de solo icono (Quitar, Editar, Mostrar contraseña, Actualizar), en límites (porciones máximas, stock) y en atajos.                                                                            |
| Clic / doble clic              | Clic en la fila abre el detalle (no hace falta doble clic). Clic en el valor de stock abre el `StockDialog`.                                                                                                                                                       |
| Menú contextual (clic derecho) | En filas de S-07, S-09, S-11: "Abrir/Editar", "Actualizar" y, en S-07/S-09, "Activar/Desactivar" (misma confirmación). Opcional; no sustituye a los controles visibles.                                                                                            |
| Rueda del ratón                | Desplaza el contenido; en steppers solo con foco y `Ctrl` (evita cambios accidentales).                                                                                                                                                                            |
| Selección de texto             | `SelectableText` en comprobante, números de orden y mensajes de error (copiar con `Ctrl+C`).                                                                                                                                                                       |
| Arrastrar                      | No se usa arrastrar y soltar.                                                                                                                                                                                                                                      |

## 7. Foco visible

- Todos los controles interactivos muestran un **anillo de foco** de 2 px `focusRing` (`#1F5FD0`) con separación de 2 px (contraste ≥ 4,5:1 sobre las superficies, ver `design-system.md` §2.4) en navegación por teclado; sobre el rail azul marino se usa `focusRingOnDark` (`#FFD166`, 9,67:1).
- El foco se muestra con `FocusHighlightMode.traditional` para teclado y no aparece con clics de ratón (comportamiento de `FocusableActionDetector`).
- Orden de tabulación lógico; al abrir un diálogo el foco entra en él y vuelve al elemento que lo abrió al cerrarlo; al navegar a una pantalla, el foco va al título de la página (`Semantics(header: true)`) o al primer campo del formulario.
- Al fallar un envío, el foco va al primer campo con error y se anuncia el resumen de errores.

## 8. Resumen de comportamiento por ancho

| Elemento                | 1024–1279                                       | 1280–1599          | ≥ 1600                             |
| ----------------------- | ----------------------------------------------- | ------------------ | ---------------------------------- |
| Rail                    | Compacto (80 px)                                | Extendido (240 px) | Extendido                          |
| Predefinidas (columnas) | 2                                               | 3                  | 4                                  |
| Resumen S-04/S-05/S-12  | Barra inferior fija / panel colapsable          | Lateral 320 px     | Lateral 320 px, contenido centrado |
| Tablas admin            | Sin columna Código; valores por tamaño apilados | Completas          | Completas                          |
| Márgenes                | 24                                              | 32                 | 32 (contenido máx. 1440 centrado)  |
