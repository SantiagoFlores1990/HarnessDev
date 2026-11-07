# Accesibilidad — Good Pizza

- **Fase:** 3 (Diseño UX/UI) · **Versión:** 1.0 · **Fecha:** 2026-11-06
- **Objetivo:** WCAG 2.1 nivel AA en la medida aplicable a una app de escritorio (RNF-05). Plataforma: Windows (Narrador y otros lectores usan UI Automation, alimentada por el árbol de `Semantics` de Flutter).

## 1. Contraste

- Paleta verificada en `design-system.md` §2.4 (45 combinaciones; el menor valor de texto normal es 4,94:1 de `warning` sobre `warningContainer`; el de componentes de interfaz 4,49:1 de `outline` sobre `surfaceContainerLow`). Umbrales: texto ≥ 4,5:1; texto grande y componentes de interfaz/foco ≥ 3:1.
- Reglas: usar solo pares de la tabla; ningún texto sobre imágenes; los estados (pedido, disponibilidad, error) se comunican con **color + icono + texto**; los enlaces y botones de texto en `primary` (13,25:1).
- Elementos deshabilitados: exentos de WCAG, pero la razón se muestra con texto legible ("Agotado", "No disponible: falta Piña", "Parte de la receta").
- Prueba obligatoria: `contrast_test.dart` recalcula las razones desde `AppColors` (ver `pruebas-unitarias.md`, WT-01).
- Nota: los ratios de esta fase se calcularon a mano; la prueba automática de `flutter-dev` es la verificación independiente.

## 2. Tamaños de objetivo e interacción

| Elemento                              | Tamaño mínimo                                                                                                                 |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Botones                               | Alto 40 px visual; área interactiva 48 × 48 px (`MaterialTapTargetSize.padded`).                                              |
| Casillas (`Checkbox`)                 | Cuadro 18 px; área interactiva 48 × 48 px; toda la fila de ingrediente (56 px de alto) es clicable (`CheckboxListTile`-like). |
| `PortionStepper` / `QuantityStepper`  | Botones − y + de 40 × 40 px con área de 48 × 48 px; separación ≥ 8 px.                                                        |
| Filas de tabla                        | Alto ≥ 52 px.                                                                                                                 |
| Iconos de solo icono                  | Área 48 × 48 px con tooltip.                                                                                                  |
| Separación entre objetivos adyacentes | ≥ 8 px.                                                                                                                       |

La app es de escritorio (ratón y teclado) y admite pantallas táctiles de Windows como entrada secundaria; no se diseñan gestos táctiles.

## 3. Semántica (árbol de `Semantics`)

| Elemento                             | Semántica                                                                                                                                                                                                     |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Títulos de página                    | `Semantics(header: true)`; un único título por pantalla; foco inicial lógico en él.                                                                                                                           |
| Logotipo                             | Solo emblema: `Semantics(label: 'Good Pizza', image: true)`. Emblema junto al texto: decorativo (`excludeSemantics`).                                                                                         |
| Checkbox de ingrediente              | `Semantics(checked, label: '<nombre>, stock <N>, <precio> dólares por porción, <kcal> calorías')`; deshabilitado por receta: `hint: 'Parte de la receta, no se puede quitar'`; agotado: `hint: 'Agotado'`.    |
| Masa y salsa (selección exclusiva)   | `Semantics(inMutuallyExclusiveGroup: true, checked: …)` con etiqueta del grupo "Masa (elige una)".                                                                                                            |
| Steppers                             | `Semantics(label: 'Porciones de <nombre>', value: '3', increasedValue: '4', decreasedValue: '2', onIncrease, onDecrease)`; al llegar al tope el hint indica el motivo ("Máximo 3 porciones por ingrediente"). |
| Panel "Tu pizza" (calorías y precio) | `Semantics(liveRegion: true, label: 'Calorías totales 820. Precio 9 dólares con 50 centavos, sin IVA.')`; se actualiza cuando termina el cálculo (no en cada tecla) para no saturar al lector.                |
| Mensajes de violación y errores      | `liveRegion: true`; texto completo; el icono se excluye (`excludeSemantics`).                                                                                                                                 |
| Estado de carga                      | `Semantics(liveRegion: true, label: 'Cargando <sección>')`; al terminar se anuncia "Listo" o el error.                                                                                                        |
| Chips de estado                      | `Semantics(label: 'Estado del pedido: En preparación')`.                                                                                                                                                      |
| Importes                             | Etiqueta hablada: `9.50` → "9 dólares con 50 centavos"; calorías "820 calorías". La cifra visual `$ 9.50` se mantiene.                                                                                        |
| Tablas                               | Fila como un nodo único con etiqueta compuesta (p. ej. "Pedido GP-20261106-0001, 6 de noviembre, 3 pizzas, total 25 dólares con 44 centavos, estado Pendiente"); cabeceras con `header: true`.                |
| Comprobante                          | Contenedor `Semantics(container: true, label: 'Comprobante del pedido <número>')`; orden de lectura = orden visual; cada bloque con encabezado.                                                               |
| Interruptores (`Switch`)             | `Semantics(toggled, label: 'Activo, <nombre>')`.                                                                                                                                                              |
| Campos de formulario                 | `label` visible (no solo placeholder), `hint` de ayuda, `error` anunciado al aparecer; `Semantics(obscured)` en contraseñas; botón mostrar/ocultar con etiqueta "Mostrar contraseña"/"Ocultar contraseña".    |
| Diálogos                             | `showDialog` con `Semantics(scopesRoute, namesRoute)`: título anunciado al abrir; foco atrapado hasta cerrar.                                                                                                 |
| Snackbars                            | Anunciados como `liveRegion`; con acción accesible por teclado (`Tab`) mientras estén visibles; duración mínima 4 s si traen acción.                                                                          |
| Línea de tiempo de estado            | Texto equivalente: "Paso 2 de 3: En preparación".                                                                                                                                                             |

## 4. Navegación por teclado

- **Todo es operable solo con teclado**: login, registro, armado de pizza (marcar con `Espacio`, porciones con `+`/`−` o `↑`/`↓`), carrito, confirmación, administración y cambio de estado.
- Orden de foco: rail → contenido principal → panel de resumen; `F6` salta entre regiones (ver `responsive.md` §5).
- No hay trampas de foco: los diálogos se cierran con `Esc`; el foco regresa al disparador.
- Foco visible siempre (`responsive.md` §7). Contraste del anillo ≥ 4,5:1.
- Atajos documentados y descubribles (`F1`, tooltips); ningún atajo es el único camino a una acción.
- Sin acciones dependientes de tiempo ni de movimiento; el debounce de la cotización no limita al usuario.

## 5. Contenido, idioma y lectura

- Idioma de la app `es` (`Locale('es')`) para que el lector use voz en español.
- Textos de error: dicen qué pasó y qué hacer; no usan solo color ni códigos técnicos.
- Estados vacíos y de error con instrucciones claras.
- Cifras: formato consistente; los importes y calorías usan cifras tabulares solo visualmente.
- Texto escalable: soporta escala de Windows hasta 200 % sin pérdida de contenido (contenedores flexibles; verificar a 125 %, 150 % y 200 %).
- Sin parpadeos; animaciones breves (≤ 200 ms) y respetan "Mostrar animaciones" desactivado de Windows (`MediaQuery.disableAnimations`).

## 6. Lista de verificación para flutter-dev (criterios de aceptación de accesibilidad)

| ID   | Criterio                                                                                                                                                                              |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A-01 | Todos los pares de color del tema cumplen §1 (prueba automática).                                                                                                                     |
| A-02 | Todo control interactivo tiene área ≥ 48 × 48 px y etiqueta semántica (prueba con `tester.getSemantics` / `meetsGuideline(androidTapTargetGuideline)` y `labeledTapTargetGuideline`). |
| A-03 | `meetsGuideline(textContrastGuideline)` pasa en S-01, S-04, S-05 y S-13.                                                                                                              |
| A-04 | Recorrido solo con `Tab`, `Espacio`, `Enter` y `Esc`: login → armar pizza → confirmar → ver comprobante.                                                                              |
| A-05 | Los errores del contrato aparecen en `liveRegion` y con icono + texto.                                                                                                                |
| A-06 | Sin controles que dependan solo de color (estado, disponibilidad, error).                                                                                                             |
| A-07 | Foco visible en todos los controles, incluido el rail (`focusRingOnDark`).                                                                                                            |
| A-08 | Sin opción de imprimir/exportar en el comprobante (verifica S-22).                                                                                                                    |
