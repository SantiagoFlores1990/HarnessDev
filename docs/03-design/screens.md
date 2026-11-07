# Pantallas — Good Pizza

- **Fase:** 3 (Diseño UX/UI) · **Versión:** 1.0 · **Fecha:** 2026-11-06
- App de escritorio Windows, español, Material 3, USD con 2 decimales. Tokens y componentes: `design-system.md`. Flujos: `user-flows.md`. Atajos/ventana: `responsive.md`. Accesibilidad: `accesibilidad.md`.
- Las maquetas ASCII son esquemáticas (ventana de referencia 1280×800). `[ ]` casilla, `(•)` selección, `[ - 2 + ]` stepper, `{Chip}` chip de estado, `▼` desplegable.
- Importes: `$ 9.50` (PA-UX-01). Todo importe, calorías, IVA y total **proviene del API** (`/orders/quote`, `OrderDetail`); la UI solo formatea (ADR-002/007).

## 0. Índice

| ID   | Pantalla                             | Ruta                             | Rol             | Endpoints principales                                                                   |
| ---- | ------------------------------------ | -------------------------------- | --------------- | --------------------------------------------------------------------------------------- |
| S-01 | Iniciar sesión                       | `/login`                         | Público         | `POST /auth/login`, `GET /auth/me`                                                      |
| S-02 | Registro                             | `/register`                      | Público         | `POST /auth/register`                                                                   |
| S-03 | Pizzas predefinidas                  | `/presets`                       | Cliente         | `GET /preset-pizzas`, `GET /sizes`                                                      |
| S-04 | Personalizar pizza                   | `/builder?presetId=&size=`       | Cliente         | `GET /ingredients`, `GET /sizes`, `GET /preset-pizzas/:id`, `POST /orders/quote`        |
| S-05 | Resumen del pedido (carrito)         | `/cart`                          | Cliente         | `POST /orders/quote`, `POST /orders`                                                    |
| S-06 | Mis pedidos                          | `/orders`                        | Cliente         | `GET /orders`                                                                           |
| S-13 | Detalle y comprobante                | `/orders/:id`                    | Cliente (dueño) | `GET /orders/:id`                                                                       |
| S-07 | Ingredientes (lista)                 | `/admin/ingredients`             | Admin           | `GET /ingredients?includeInactive`, `PATCH …/status`, `PATCH …/stock`                   |
| S-08 | Ingrediente (nuevo/editar)           | `/admin/ingredients/new`, `/:id` | Admin           | `GET /ingredient-categories`, `GET /vat-rates`, `GET /sizes`, `POST`/`PUT /ingredients` |
| S-09 | Pizzas predefinidas (admin, lista)   | `/admin/presets`                 | Admin           | `GET /preset-pizzas?includeInactive`, `PATCH …/status`                                  |
| S-10 | Pizza predefinida (nueva/editar)     | `/admin/presets/new`, `/:id`     | Admin           | `POST`/`PUT /preset-pizzas`, `POST /orders/quote` (vista previa)                        |
| S-11 | Gestión de pedidos (lista)           | `/admin/orders`                  | Admin           | `GET /orders`                                                                           |
| S-12 | Pedido (admin): comprobante y estado | `/admin/orders/:id`              | Admin           | `GET /orders/:id`, `PATCH /orders/:id/status`                                           |

Estructura común (excepto S-01/S-02): `AppShell` = `NavigationRail` a la izquierda + contenido. Todas las pantallas con datos remotos usan `AsyncValueView` con tres estados: **cargando**, **vacío** y **error con "Reintentar"**.

```
+--------+------------------------------------------------------------------+
| [logo] |  Título de la página (headlineSmall)          [acciones: Actualizar]|
| Good   |------------------------------------------------------------------|
| Pizza  |                                                                  |
|        |                    Contenido (máx. 1440 px)                      |
| ▣ Pizz.|                                                                  |
| ▣ Pers.|                                                                  |
| ▣ Pedid|                                                                  |
| ▣ Mis p|                                                                  |
|        |                                                                  |
| Ana P. |                                                                  |
| ⎋ Salir|                                                                  |
+--------+------------------------------------------------------------------+
```

NavigationRail por rol (orden y atajo, ver `responsive.md`):

| Rol           | Destinos                                                                                            |
| ------------- | --------------------------------------------------------------------------------------------------- |
| Cliente       | 1 Pizzas predefinidas · 2 Personalizar pizza · 3 Mi pedido (badge con nº de pizzas) · 4 Mis pedidos |
| Administrador | 1 Ingredientes · 2 Pizzas predefinidas · 3 Pedidos                                                  |

---

## 1. Convenciones transversales

### 1.1 Estados genéricos (usar en toda pantalla)

| Estado            | Presentación                                                                                                                                                                                                  |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Cargando          | Esqueleto de la estructura (filas/tarjetas grises `surfaceContainerHighest`) o `CircularProgressIndicator` centrado; `Semantics(liveRegion, label: "Cargando <sección>")`. No bloquea la navegación del rail. |
| Vacío             | `EmptyState` (icono, título, texto, acción). Textos por pantalla más abajo.                                                                                                                                   |
| Error de carga    | `ErrorBanner` + botón "Reintentar" (también `F5`). Mensaje según §6.1.                                                                                                                                        |
| Error de acción   | Snackbar (errores globales, 4 s, con acción "Reintentar" si aplica), o error en campo (validación), o diálogo (409 con decisión del usuario).                                                                 |
| Éxito de acción   | Snackbar breve (3 s): "Guardado", "Estado actualizado", "Pizza agregada".                                                                                                                                     |
| Procesando acción | El botón se deshabilita y muestra `CircularProgressIndicator` pequeño con el texto "Guardando…"/"Confirmando…"; previene doble envío.                                                                         |

### 1.2 Formato de números

`$ 9.50` · `15 %` · `820 kcal` · `Stock: 12` · fechas `dd/MM/yyyy HH:mm` (hora local del equipo).

---

## S-01 Iniciar sesión

- **Ruta/rol:** `/login`, público. **API:** `POST /auth/login` → tokens a secure storage → `GET /auth/me` (o `user` de la respuesta).
- **Objetivo:** acceder a la app. Redirige por rol: CLIENT → `/presets`; ADMIN → `/admin/ingredients`.

```
+--------------------------------------------------------------+
|                         (ventana completa, fondo surface)      |
|                 +--------------------------------+            |
|                 |        [LOGO 96 px]            |            |
|                 |        Good Pizza              |            |
|                 |  Iniciar sesión                |            |
|                 |  +--------------------------+  |            |
|                 |  | Email                    |  |            |
|                 |  +--------------------------+  |            |
|                 |  +--------------------------+  |            |
|                 |  | Contraseña           (👁) |  |            |
|                 |  +--------------------------+  |            |
|                 |  [ ! Banner de error ]         |            |
|                 |  [      Iniciar sesión       ] |            |
|                 |  ¿No tienes cuenta? Crear cuenta            |
|                 +--------------------------------+            |
+--------------------------------------------------------------+
```

| Componente             | Detalle                                                                                                               |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Tarjeta centrada       | Ancho 420 px, padding 32.                                                                                             |
| Campo Email            | `TextField` `keyboardType: emailAddress`, `autofillHints: [username, email]`, foco inicial.                           |
| Campo Contraseña       | Oculto por defecto; icono "Mostrar/Ocultar contraseña" con tooltip y `Semantics(label)`. `autofillHints: [password]`. |
| Botón "Iniciar sesión" | `FilledButton` ancho completo; `Enter` en cualquier campo lo activa.                                                  |
| Enlace "Crear cuenta"  | `TextButton` → `/register`.                                                                                           |
| Banner de error        | `ErrorBanner` sobre el botón, `liveRegion`.                                                                           |

Estados:

| Estado           | Comportamiento                                                                                                                                                                                                                                                                                                                                                                        |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Inicial          | Botón activo; campos vacíos.                                                                                                                                                                                                                                                                                                                                                          |
| Validación local | Email vacío/inválido: "Ingresa un email válido."; contraseña vacía: "Ingresa tu contraseña." (no se envía).                                                                                                                                                                                                                                                                           |
| Cargando         | Botón con indicador y "Ingresando…"; campos deshabilitados.                                                                                                                                                                                                                                                                                                                           |
| Error            | `INVALID_CREDENTIALS`: "Email o contraseña incorrectos." (mismo mensaje para ambos casos; el campo contraseña se limpia y recibe el foco). `FORBIDDEN`: "Tu cuenta está desactivada. Consulta con el local." `RATE_LIMITED`: "Demasiados intentos. Espera unos minutos e inténtalo de nuevo." Red: "No se pudo conectar con el servidor. Verifica que el servicio esté en ejecución." |
| Vacío            | No aplica.                                                                                                                                                                                                                                                                                                                                                                            |

---

## S-02 Registro

- **Ruta/rol:** `/register`, público. **API:** `POST /auth/register` (siempre rol Cliente; devuelve tokens → sesión iniciada, PA-UX-04).

```
+--------------------------------------------------+
|        [LOGO]  Good Pizza                         |
|        Crear cuenta                               |
|  Nombre completo  [_____________________]         |
|  Email            [_____________________]         |
|  Contraseña       [_____________________] (👁)    |
|                   Mínimo 8 caracteres              |
|  Repetir contraseña [___________________] (👁)    |
|  [ ! error ]                                      |
|  [            Crear cuenta            ]           |
|  ¿Ya tienes cuenta? Iniciar sesión                |
+--------------------------------------------------+
```

| Campo              | Regla local (espejo del contrato) | Mensaje                                                                                            |
| ------------------ | --------------------------------- | -------------------------------------------------------------------------------------------------- |
| Nombre completo    | 2 a 120 caracteres                | "Ingresa tu nombre completo (mínimo 2 caracteres)."                                                |
| Email              | formato válido, ≤ 254             | "Ingresa un email válido."                                                                         |
| Contraseña         | 8 a 72 caracteres                 | "La contraseña debe tener al menos 8 caracteres." (también ayuda permanente "Mínimo 8 caracteres") |
| Repetir contraseña | igual a la contraseña (solo UI)   | "Las contraseñas no coinciden."                                                                    |

Estados: **cargando** ("Creando cuenta…"); **error** `EMAIL_ALREADY_EXISTS` → error bajo el campo Email: "Este email ya está registrado." con enlace "Iniciar sesión"; `VALIDATION_ERROR` → cada `details[].path` (`fullName`, `email`, `password`) se muestra en su campo con el `message` del servidor; `RATE_LIMITED` y red como en S-01. **Éxito**: sesión iniciada y redirección a `/presets` con snackbar "¡Bienvenido, <nombre>!". No hay campo de rol.

---

## S-03 Pizzas predefinidas (cliente, inicio)

- **Ruta/rol:** `/presets`, Cliente. **API:** `GET /preset-pizzas` (solo activas; incluye no disponibles con `available:false`), `GET /sizes`.
- **Objetivo:** ver las 5 recetas con precio y calorías por tamaño y agregarlas al pedido o personalizarlas.

```
+--------+---------------------------------------------------------------------------+
| rail   | Pizzas predefinidas                                      [Actualizar ⟳]     |
|        | Tamaño para ver precios:  [ Individual | (•)Mediana | Familiar ]            |
|        |                                                                           |
|        | +-----------------------+ +-----------------------+ +--------------------+|
|        | | Margarita {Disponible}| | Pepperoni {Disponible}| | Hawaiana {No dispo-||
|        | | Tomate, mozzarella... | | ...                   | |  nible}            ||
|        | | Receta:               | | Receta:               | | Falta: Piña        ||
|        | |  Masa tradicional x1  | |  Masa tradicional x1  | |  (sin stock)       ||
|        | |  Salsa de tomate x1   | |  Salsa de tomate x1   | | ...                ||
|        | |  Mozzarella x2        | |  Mozzarella x2        | |                    ||
|        | |  Albahaca x1          | |  Pepperoni x3         | |                    ||
|        | | $ 7.50   690 kcal     | | $ 9.80  920 kcal      | | $ --   -- kcal     ||
|        | | (sin IVA)             | | (sin IVA)             | |                    ||
|        | | [Personalizar][Agregar| | [Personalizar][Agregar| | [Personalizar][Agr]||
|        | |  al pedido]           | |  al pedido]           | |  (deshabilitados)  ||
|        | +-----------------------+ +-----------------------+ +--------------------+|
+--------+---------------------------------------------------------------------------+
```

(Los importes de la maqueta son ilustrativos; vienen de `pricesBySize` según el tamaño elegido.)

| Componente                  | Detalle                                                                                                                                                                                                                             |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SegmentedButton` de tamaño | Individual / Mediana / Familiar (valores de `GET /sizes`). Tamaño por defecto: Mediana. Cambiarlo actualiza precio y calorías de todas las tarjetas sin nueva petición (`pricesBySize` ya trae los 3).                              |
| Tarjeta de predefinida      | Nombre (`titleLarge`), `AvailabilityChip`, descripción, receta (nombre × porciones), precio y calorías del tamaño elegido, nota "Precio sin IVA". Cuadrícula adaptable: 2 columnas a 1024–1279 px, 3 a 1280–1599 px, 4 a ≥ 1600 px. |
| "Agregar al pedido"         | Agrega al carrito una línea `PRESET` sin extras, cantidad 1, tamaño elegido. Snackbar "Pizza agregada" + acción "Ver pedido". Si ya existe la misma línea (misma predefinida, tamaño y sin extras) incrementa su cantidad hasta 20. |
| "Personalizar"              | Navega a `/builder?presetId=<id>&size=<code>`.                                                                                                                                                                                      |
| Pie                         | Texto "Las pizzas predefinidas solo permiten agregar ingredientes, no quitarlos."                                                                                                                                                   |

Estados:

| Estado                            | Comportamiento                                                                                                                                                                            |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Cargando                          | 5 tarjetas esqueleto.                                                                                                                                                                     |
| Vacío                             | Icono `local_pizza`; "Todavía no hay pizzas predefinidas." / "Puedes armar la tuya desde cero." Botón "Personalizar pizza" → `/builder`.                                                  |
| Error                             | `ErrorBanner` + "Reintentar" ("No se pudieron cargar las pizzas predefinidas.").                                                                                                          |
| No disponible (`available:false`) | Tarjeta con `errorContainer` en el chip; texto `unavailableReasons[].message` ("La pizza Hawaiana no está disponible: falta Piña."); ambos botones deshabilitados con tooltip del motivo. |

---

## S-04 Personalizar pizza (cliente) — con checkboxes y cálculo en vivo

- **Ruta/rol:** `/builder` (desde cero) o `/builder?presetId=&size=` (personalizando una predefinida), Cliente.
- **API:** `GET /sizes`, `GET /ingredients` (lista completa, activos, con `stock`), `GET /preset-pizzas/:id` (si hay `presetId`), `POST /orders/quote` con un ítem (debounce 150 ms, cancelación de la anterior, ADR-002/007).
- **Sin render visual de la pizza:** la selección se hace solo con casillas, cantidades y un panel de texto/cifras.

Maqueta (desde cero):

```
+--------+-------------------------------------------------------+-----------------------------+
| rail   | Personalizar pizza                                    | TU PIZZA                    |
|        |                                                       |                             |
|        | 1. Tamaño                                             | Tamaño: Mediana             |
|        |  [ Individual | (•)Mediana | Familiar ]               | Masa: Masa tradicional      |
|        |                                                       | Salsa: Salsa de tomate      |
|        | 2. Masa (elige 1)                                     | Ingredientes (3 distintos): |
|        |  [x] Masa tradicional   Stock: 40   +$ 2.00  300 kcal |  · Queso mozzarella  x3     |
|        |  [ ] Masa delgada       Stock: 25   +$ 1.80  240 kcal |  · Jamón             x1     |
|        |  [ ] Masa integral      Agotado                       |  · Piña              x1     |
|        |                                                       | ---------------------------- |
|        | 3. Salsa base (elige 1)                               | Calorías totales  820 kcal  |
|        |  [x] Salsa de tomate    Stock: 60   +$ 1.00   60 kcal | Precio de la pizza  $ 9.50  |
|        |  [ ] Salsa BBQ ...                                    | (sin IVA)         ⟳ Calculando|
|        |                                                       |                             |
|        | 4. Ingredientes (mín. 3 distintos, máx. 3 porciones)  | Cantidad de pizzas          |
|        |  Queso                                                |  [ - 1 + ]                  |
|        |  [x] Queso mozzarella  Stock: 120 +$1.50 110 kcal     |                             |
|        |       Porciones: [ - 3 + ]                            | ! Elige al menos 3          |
|        |  [ ] Queso cheddar     Stock: 3    +$1.60 120 kcal    |   ingredientes distintos.   |
|        |  Carne                                                |                             |
|        |  [x] Jamón             Stock: 80 ...  [ - 1 + ]       | [  Agregar al pedido  ]     |
|        |  Vegetal   ...                                        | [      Cancelar       ]     |
|        |  Otros                                                |                             |
|        |  [x] Piña              Stock: 0  -> Agotado (deshab.) |                             |
+--------+-------------------------------------------------------+-----------------------------+
```

Maqueta de la fila de ingrediente (`IngredientCheckRow`, alto 56 px; foco con anillo):

```
[x] Queso mozzarella   {Stock: 120}   +$ 1.50 · 110 kcal por porción     Porciones [ - 3 + ]
                                                                         (Máx. 3)
```

### Componentes y reglas

| Elemento            | Comportamiento                                                                                                                                                                                                                                                                                                                                                                                                                       |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Tamaño              | `SegmentedButton` (3 opciones). Cambiar tamaño recalcula (precio y calorías por porción de cada fila se muestran para el tamaño elegido, tomados de `sizeValues`).                                                                                                                                                                                                                                                                   |
| Masa y salsa        | `Checkbox` con comportamiento **exclusivo** dentro del grupo (marcar otra desmarca la anterior; US-04). Semántica: `Semantics(inMutuallyExclusiveGroup: true, checked, label: "Masa tradicional, stock 40, 2 dólares")`. Se puede desmarcar la seleccionada; entonces el panel muestra "Elige una masa." (`DOUGH_REQUIRED`). Sin stepper (porción fija 1). Ingredientes de categoría `DOUGH`/`SAUCE` nunca aparecen en la sección 4. |
| Ingredientes        | Agrupados por categoría (`ingredient-categories`: Queso, Carne, Vegetal, Otros; orden por `sortOrder`). Cada fila: `Checkbox`, nombre, `StockBadge` ("Stock: N"), precio y calorías por porción del tamaño elegido y `PortionStepper`.                                                                                                                                                                                               |
| Marcar/desmarcar    | Marcar activa el stepper con 1 porción. Desmarcar quita el ingrediente (excepto los de receta, ver abajo).                                                                                                                                                                                                                                                                                                                           |
| `PortionStepper`    | Rango 1..**m**, con `m = min(3 − porcionesDeReceta, stock)` (límite de entrada, RF-10/RF-12; ADR-002 §2.4). Al llegar al tope el botón "+" se deshabilita y aparece tooltip/texto auxiliar: "Máximo 3 porciones por ingrediente" o "Stock disponible: N" (el que aplique). Teclado: `↑`/`↓` o `+`/`−` con foco en el stepper.                                                                                                        |
| Stock 0             | Fila deshabilitada con chip "Agotado" (texto de contraste completo, no solo opacidad); no se puede marcar (US-06).                                                                                                                                                                                                                                                                                                                   |
| Stock bajo          | Si `stock` < porciones × cantidad de pizzas, aparece el mensaje de violación `INSUFFICIENT_STOCK` del servidor (ver §6.2).                                                                                                                                                                                                                                                                                                           |
| Cantidad de pizzas  | `QuantityStepper` 1..20; tooltip en el tope: "Máximo 20 pizzas por línea".                                                                                                                                                                                                                                                                                                                                                           |
| Panel "Tu pizza"    | Resumen en texto de la selección, **calorías totales** y **precio de la pizza** (sin IVA) provenientes de `items[0].unitCalories` y `items[0].unitPrice` (y `lineSubtotal` si cantidad > 1: "Subtotal de la línea $ 19.00"). Sticky a la derecha; en 1024–1279 px baja a una barra inferior fija (ver `responsive.md`). Nota: "El IVA se muestra en el resumen del pedido."                                                          |
| Mensajes            | Lista de `items[0].violations` + `violations` raíz, cada una con icono y texto, en `Semantics(liveRegion: true)`. Mientras haya violaciones "Agregar al pedido" está deshabilitado y debajo se explica el motivo principal.                                                                                                                                                                                                          |
| "Agregar al pedido" | `FilledButton`; `Ctrl+Enter`. Habilitado solo con `valid == true`. Añade la línea al carrito, snackbar "Pizza agregada" (acción "Ver pedido") y reinicia el armado (o vuelve a `/presets` si venía de una predefinida).                                                                                                                                                                                                              |
| "Cancelar"          | `TextButton` → vuelve a la pantalla anterior; si hay selección pide confirmación ("¿Descartar esta pizza?").                                                                                                                                                                                                                                                                                                                         |

### Variante: personalizando una predefinida (`presetId`)

```
|  Personalizando: Margarita   (solo puedes agregar ingredientes)           |
|  [x] Queso mozzarella  (receta: 2)  Stock: 120   Porciones [ - 2 + ]      |
|       mínimo 2 por la receta; hasta 1 porción extra                       |
|  [x] Albahaca (receta: 1) 🔒        Porciones [ - 1 + ]  (no se puede quitar) |
|  [ ] Champiñones                    ... al marcar se agrega como extra    |
```

- Banner informativo fijo: "Personalizando Margarita. Puedes agregar ingredientes o porciones, pero no quitar los de la receta."
- Masa y salsa de la receta aparecen marcadas y **bloqueadas** (`🔒`, deshabilitadas, texto "Parte de la receta"); no se puede cambiar masa ni salsa (PA-03 de arquitectura).
- Ingredientes de receta: casilla marcada y deshabilitada; el stepper empieza en `porcionesDeReceta` y su mínimo es ese valor; el máximo es `min(3, stock)`. Se envían como `extras[].portions = porciones − porcionesDeReceta` (solo cuando > 0).
- No se muestra el aviso de mínimo 3 ingredientes (RF-14/S-17); el servidor no devuelve `MIN_TOPPINGS_NOT_MET` en PRESET.
- Cambiar el tamaño está permitido (la receta se recalcula en servidor).

### Estados

| Estado                                    | Comportamiento                                                                                                                                                              |
| ----------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Cargando catálogo                         | Esqueleto de las 4 secciones; panel "Tu pizza" con "—".                                                                                                                     |
| Vacío (catálogo sin ingredientes activos) | `EmptyState`: "No hay ingredientes disponibles por ahora." / "Consulta con el local." Sin acción de agregar.                                                                |
| Error de catálogo                         | `ErrorBanner` + Reintentar: "No se pudo cargar el catálogo de ingredientes."                                                                                                |
| Calculando                                | Texto "Calculando…" con indicador junto al precio; se mantiene el último valor visible (RNF-01); "Agregar" deshabilitado hasta recibir la respuesta.                        |
| Error de cotización                       | Aviso bajo el panel: "No se pudo calcular el precio. Reintentar" (botón); `VALIDATION_ERROR` (400) no debería ocurrir (la UI limita rangos) y se trata como error genérico. |
| Selección incompleta                      | Mensajes de violación (§6.2); calorías y precio parciales visibles.                                                                                                         |
| Pizza inválida por stock                  | `INSUFFICIENT_STOCK` en raíz: "No hay stock suficiente de <nombre>: solicitado N, disponible M."                                                                            |
| Éxito                                     | "Pizza agregada".                                                                                                                                                           |

---

## S-05 Resumen del pedido (carrito)

- **Ruta/rol:** `/cart`, Cliente. **API:** `POST /orders/quote` (todas las líneas) para totales, IVA y stock agregado; `POST /orders` para confirmar. El carrito vive en memoria (no persistido) y se vacía al confirmar o al cerrar sesión.

```
+--------+--------------------------------------------------------+-----------------------------+
| rail   | Resumen del pedido                                     | RESUMEN                     |
|        |                                                        |                             |
|        | +----------------------------------------------------+ | Calorías totales 1640 kcal  |
|        | | Pizza 1 · Personalizada · Mediana       [ - 2 + ]  [🗑]| | Subtotal 15 %      $ 15.40  |
|        | | Masa tradicional, Salsa de tomate,                  | | Subtotal 0 %       $  3.60  |
|        | | Queso mozzarella x3, Jamón x1, Piña x1              | | IVA 15 %           $  2.31  |
|        | | $ 9.50 c/u · 820 kcal c/u   Línea: $ 19.00 (1640)   | | ----------------------------|
|        | +----------------------------------------------------+ | TOTAL (USD)        $ 21.31  |
|        | | Pizza 2 · Margarita · Familiar          [ - 1 + ]  [🗑]| |                             |
|        | | Receta + extras: Albahaca x1 (extra)                | | ! No hay stock suficiente   |
|        | | ...                                                 | |   de Piña: solicitado 4,    |
|        | +----------------------------------------------------+ |   disponible 2.             |
|        |  [ Seguir agregando pizzas ]                           | [   Confirmar pedido   ]    |
|        |                                                        | Precios sin IVA; IVA 15 %   |
|        |                                                        | calculado sobre el subtotal |
+--------+--------------------------------------------------------+-----------------------------+
```

| Componente                | Detalle                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Tarjeta de línea          | Título "Pizza N · Personalizada/<predefinida> · <tamaño>"; lista de componentes de `items[i].components` (masa, salsa, ingredientes con cantidad; extras marcados "(extra)"); precio unitario, calorías por pizza y subtotal de línea (`lineSubtotal`, `lineCalories`); `QuantityStepper` 1..20 ("Máximo 20 pizzas por línea"); botón "Quitar" (icono papelera con tooltip "Quitar del pedido"; `Supr` con foco en la línea) con snackbar "Pizza quitada · Deshacer". |
| `TotalsCard`              | **Calorías totales**, **Subtotal 15 %**, **Subtotal 0 %**, **IVA 15 %**, **TOTAL (USD)** exactamente de `totals`. El total en `bodyLarge` 600.                                                                                                                                                                                                                                                                                                                        |
| "Confirmar pedido"        | `FilledButton` ancho completo; `Ctrl+Enter`. Deshabilitado si el carrito está vacío, `valid == false` o mientras se cotiza. Abre `ConfirmDialog`: "¿Confirmar el pedido por $ 21.31? Al confirmar se reserva el stock y no se puede cancelar." [Cancelar] [Confirmar].                                                                                                                                                                                                |
| "Seguir agregando pizzas" | `OutlinedButton` → `/presets`.                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| Aviso de errores de stock | Banner con la lista de `violations` (raíz) e `items[i].violations`; cada una enlaza a la línea afectada.                                                                                                                                                                                                                                                                                                                                                              |

Estados:

| Estado              | Comportamiento                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Cargando cotización | Totales con esqueleto/"Calculando…"; se muestra el último total; "Confirmar" deshabilitado.                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Vacío               | Icono `shopping_cart`; "Tu pedido está vacío." / "Agrega una pizza predefinida o arma la tuya." Botones "Ver pizzas predefinidas" y "Personalizar pizza".                                                                                                                                                                                                                                                                                                                                                                                                                 |
| Error de cotización | `ErrorBanner` "No se pudo calcular el pedido." + Reintentar; "Confirmar" deshabilitado.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| Con violaciones     | Banner `errorContainer`; "Confirmar" deshabilitado; la causa visible (p. ej. stock agregado insuficiente).                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| Confirmando         | Botón con "Confirmando…" e indicador; diálogo cerrado; no se puede editar el carrito.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Error al confirmar  | `INSUFFICIENT_STOCK` (409): diálogo "Stock insuficiente" con lista (ingrediente: solicitado N, disponible M) y botón "Ajustar pedido"; se recotiza. `PRICE_CHANGED` (409): diálogo "El precio cambió" — "El total ahora es $ X (antes $ Y)." [Revisar pedido] [Aceptar y confirmar] (reenvía con el nuevo `expectedTotal`). `PIZZA_RULES_VIOLATED` (422): banner con las violaciones por línea. `FORBIDDEN` (403): "Tu cuenta no puede crear pedidos." Red/500/503: banner "No se pudo confirmar el pedido. Inténtalo de nuevo." con Reintentar (el carrito se conserva). |
| Éxito               | Se vacía el carrito, se abre S-13 con banner de éxito "Pedido GP-… confirmado. Estado: Pendiente."                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |

---

## S-06 Mis pedidos (cliente)

- **Ruta/rol:** `/orders`, Cliente. **API:** `GET /orders` (solo propios, orden `createdAt` desc., `page`, `pageSize` 20).

```
+--------+----------------------------------------------------------------------------------+
| rail   | Mis pedidos                                                    [Actualizar ⟳ F5] |
|        | Estado: [Todos][Pendiente][En preparación][Entregado]                            |
|        | +-----------------------------------------------------------------------------+ |
|        | | Nº de orden        | Fecha             | Pizzas | Total     | Estado            | |
|        | | GP-20261106-0003   | 06/11/2026 12:15  |   3    | $ 25.44   | {Pendiente}   [>] | |
|        | | GP-20261106-0001   | 06/11/2026 10:04  |   2    | $ 21.31   | {En preparación}[>]| |
|        | | GP-20261105-0007   | 05/11/2026 19:30  |   1    | $  9.80   | {Entregado}   [>] | |
|        | +-----------------------------------------------------------------------------+ |
|        |                                       Página 1 de 2   [<] [>]                    |
+--------+----------------------------------------------------------------------------------+
```

| Componente        | Detalle                                                                                                                                                                                                         |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Filtro por estado | Chips de filtro (`status` del API); "Todos" por defecto.                                                                                                                                                        |
| Tabla             | `DataTable`/lista con filas de 52 px: Nº de orden, Fecha, Pizzas (`pizzaCount`), Total (`total`), Estado (`OrderStatusChip`), flecha. Clic o `Enter` abre S-13. Hover resalta la fila (`surfaceContainerHigh`). |
| Paginación        | Controles "Anterior/Siguiente" y "Página X de Y".                                                                                                                                                               |
| "Actualizar"      | Recarga (`F5`); el cliente ve así los cambios de estado hechos por el administrador.                                                                                                                            |
| Aviso             | "Los pedidos no se pueden cancelar desde la aplicación." (texto de ayuda, `bodySmall`). No existe acción de cancelar (S-20).                                                                                    |

Estados:

| Estado   | Comportamiento                                                                                                                                                                                                                |
| -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Cargando | 5 filas esqueleto.                                                                                                                                                                                                            |
| Vacío    | Icono `receipt_long`; "Aún no tienes pedidos." / "Cuando confirmes uno, aparecerá aquí con su estado." Botón "Ver pizzas predefinidas". Con filtro activo sin resultados: "No hay pedidos con ese estado." + "Quitar filtro". |
| Error    | `ErrorBanner` "No se pudieron cargar tus pedidos." + Reintentar.                                                                                                                                                              |

---

## S-13 Detalle del pedido y comprobante (cliente; también incrustado en S-12)

- **Ruta/rol:** `/orders/:id`, Cliente dueño (un pedido ajeno devuelve `404 NOT_FOUND` → pantalla "Pedido no encontrado"). **API:** `GET /orders/:id` → `OrderDetail` (todo desde snapshots: nunca cambia si cambian los precios, RF-19).
- **Solo pantalla:** no hay botones de imprimir, PDF, exportar ni compartir (S-22). El texto es seleccionable (`SelectableText`) para poder copiar.

Pantalla: barra superior con "← Mis pedidos" y "Actualizar"; banner de éxito opcional (al venir de confirmar); el comprobante (`ReceiptView`) centrado en una hoja de 720 px de ancho (`surfaceContainerLowest`, borde `outlineVariant`, radio 12), con scroll vertical.

### Diseño exacto del comprobante (`ReceiptView`)

```
+------------------------------------------------------------------------------+
|  [LOGO 56 px]  Good Pizza                          Orden  GP-20261106-0001    |
|                                                    Fecha  06/11/2026 10:04    |
|==============================================================================|
|  CLIENTE                                                                     |
|  Ana Pérez                                                                   |
|  ana@ejemplo.com                                                             |
|------------------------------------------------------------------------------|
|  PIZZA 1 · Personalizada                                          Cantidad x2|
|  Tamaño: Mediana    Masa: Masa tradicional    Salsa: Salsa de tomate         |
|                                                                              |
|  Ingrediente                 Cant.      Calorías        Precio (sin IVA)     |
|  ---------------------------------------------------------------------------  |
|  Masa tradicional              1        300 kcal               $ 2.00        |
|  Salsa de tomate               1         60 kcal               $ 1.00        |
|  Queso mozzarella              3        330 kcal               $ 4.50        |
|  Jamón                         1         90 kcal               $ 1.20        |
|  Piña                          1         40 kcal               $ 0.80        |
|  ---------------------------------------------------------------------------  |
|  Por pizza                              820 kcal               $ 9.50        |
|  Línea (x2)                           1640 kcal               $ 19.00        |
|------------------------------------------------------------------------------|
|  (PIZZA 2 · Margarita (predefinida) ... mismo formato; extras marcados       |
|   "Albahaca  2  (1 receta + 1 extra)")                                       |
|==============================================================================|
|  RESUMEN                                                                     |
|  Calorías totales                                              1640 kcal     |
|  Subtotal 15 %                                                  $ 15.40      |
|  Subtotal 0 %                                                   $  3.60      |
|  IVA 15 %                                                       $  2.31      |
|  ---------------------------------------------------------------------------  |
|  TOTAL (USD)                                                    $ 21.31      |
|==============================================================================|
|  ESTADO ACTUAL                                                               |
|  {schedule  Pendiente}      Actualizado: 06/11/2026 10:04                    |
|  Pendiente ─────● En preparación ─────○ Entregado   (línea de tiempo)        |
|------------------------------------------------------------------------------|
|  Documento informativo del pedido. No es una factura electrónica.            |
+------------------------------------------------------------------------------+
```

Especificación de contenido (campo del contrato → elemento):

| Bloque        | Contenido                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | Fuente (`OrderDetail`)                                                                                        |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Encabezado    | Logotipo (`GoodPizzaLogo` variante `receipt`, 56 px) + "Good Pizza" (`headlineSmall`, `primary`). A la derecha: "Orden" + número `GP-AAAAMMDD-0001` (`titleMedium`, cifras tabulares) y "Fecha" `dd/MM/yyyy HH:mm` (hora local del equipo).                                                                                                                                                                                                                                                          | `orderNumber`, `createdAt`                                                                                    |
| Cliente       | Nombre completo y email.                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | `customer.fullName`, `customer.email`                                                                         |
| Por pizza     | Título "PIZZA N · Personalizada" o "PIZZA N · <nombre> (predefinida)"; "Cantidad xN". Línea "Tamaño: … Masa: … Salsa: …". Tabla: Ingrediente, Cant. (porciones), Calorías (`lineCalories` del componente), Precio (`lineAmount`); la masa y la salsa figuran como filas (cantidad 1). En ingredientes de predefinida con extras: "(R receta + E extra)" con `recipePortions`. Pie de tabla: "Por pizza" (`unitCalories`, `unitPrice`) y "Línea (xN)" (`lineCalories`, `lineSubtotal`) solo si N > 1. | `pizzas[].size.name`, `components[]`, `unitPrice`, `unitCalories`, `lineSubtotal`, `lineCalories`, `quantity` |
| Resumen       | Calorías totales; **Subtotal 15 %**; **Subtotal 0 %**; **IVA 15 %**; **TOTAL (USD)**. Etiquetas exactas del prompt.                                                                                                                                                                                                                                                                                                                                                                                  | `totals.totalCalories`, `subtotalVat15`, `subtotalVat0`, `vat15`, `total`                                     |
| Estado actual | `OrderStatusChip` (color + icono + texto), fecha del último cambio y línea de tiempo de 3 pasos (paso actual relleno; texto "Paso 2 de 3: En preparación" para lector de pantalla).                                                                                                                                                                                                                                                                                                                  | `status`, `statusChangedAt`, `statusHistory`                                                                  |
| Pie           | "Documento informativo del pedido. No es una factura electrónica." (PA-UX-09)                                                                                                                                                                                                                                                                                                                                                                                                                        | —                                                                                                             |

Reglas del comprobante: orden de bloques fijo tal cual; importes con 2 decimales; "TOTAL" en `titleLarge` 700 con línea superior; todos los textos con contraste AA; la hoja tiene `Semantics(container: true, label: "Comprobante del pedido GP-20261106-0001")` y cada fila de tabla se lee como "Queso mozzarella, cantidad 3, 330 calorías, 4 dólares con 50 centavos".

Estados de S-13:

| Estado                          | Comportamiento                                                                                                                          |
| ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Cargando                        | Hoja con esqueleto de bloques.                                                                                                          |
| Vacío                           | No aplica (siempre hay al menos una pizza).                                                                                             |
| Error                           | `ErrorBanner` + Reintentar: "No se pudo cargar el pedido."                                                                              |
| No encontrado (`404 NOT_FOUND`) | `EmptyState` icono `search_off`: "No encontramos este pedido." / "Puede que no exista o que no sea tuyo." Botón "Volver a Mis pedidos". |
| Éxito tras confirmar            | Banner `successContainer` arriba: "Pedido GP-… confirmado. Lo estamos preparando; el estado cambiará aquí."                             |
| Actualizar                      | `F5`/botón recarga y anuncia el estado ("Estado actual: En preparación").                                                               |

---

## S-07 Ingredientes (admin, lista)

- **Ruta/rol:** `/admin/ingredients`, Administrador (inicio del admin). **API:** `GET /ingredients?includeInactive=true` (+ `category`, `search`), `PATCH /ingredients/:id/status`, `PATCH /ingredients/:id/stock`.

```
+--------+------------------------------------------------------------------------------------------+
| rail   | Ingredientes                                              [+ Nuevo ingrediente  Ctrl+N]  |
|        | [🔍 Buscar por código o nombre   ] Categoría [Todas ▼]  [ ] Mostrar inactivos            |
|        | +--------------------------------------------------------------------------------------+ |
|        | |Código  |Nombre        |Categoría|IVA   |Stock|Individual   |Mediana      |Familiar    |Activo|⋮| |
|        | |        |              |         |      |     |$ / kcal     |$ / kcal     |$ / kcal    |      | | |
|        | |QUE-MOZ |Mozzarella    |Queso    |15 %  | 120 |1.00 · 80    |1.50 · 110   |2.20 · 160  | [on] |✎| |
|        | |SAL-TOM |Salsa tomate  |Salsa    | 0 %  |  60 |0.60 · 40    |1.00 · 60    |1.50 · 90   | [on] |✎| |
|        | |CAR-PEP |Pepperoni     |Carne    |15 %  |   0 |...          |...          |...         |[off] |✎| |
|        | +--------------------------------------------------------------------------------------+ |
|        |                                                  Página 1 de 1                           |
+--------+------------------------------------------------------------------------------------------+
```

| Componente             | Detalle                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Barra de herramientas  | Campo de búsqueda (`search`, `Ctrl+F` enfoca), filtro de categoría (`GET /ingredient-categories`), interruptor "Mostrar inactivos" (`includeInactive`), botón "Nuevo ingrediente" (`Ctrl+N`).                                                                                                                                                                                                                                                                                                                                       |
| Tabla                  | Columnas: Código, Nombre, Categoría, IVA (chip "IVA 15 %"/"IVA 0 %"), Stock (cifra tabulada; chip "Agotado" si 0), valores por tamaño `precio · kcal` (Individual, Mediana, Familiar; precio sin IVA), Activo (`Switch`), Acciones. Filas inactivas con texto atenuado y chip "Inactivo" (el texto sigue cumpliendo AA). Clic en la fila o icono ✎ (tooltip "Editar") abre S-08.                                                                                                                                                    |
| Acción "Ajustar stock" | Menú ⋮ de la fila o clic en la cifra de stock: abre `StockDialog`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `StockDialog`          | Título "Stock de <nombre>"; stock actual; `SegmentedButton` [Fijar valor                                                                                                                                                                                                                                                                                                                                                                                                                                                            | Sumar o restar]; campo numérico entero (Fijar ≥ 0; Ajustar ≠ 0, admite negativo); vista previa "Nuevo stock: N". Botones Cancelar / Guardar. Errores: `STOCK_WOULD_BE_NEGATIVE`: "El ajuste dejaría el stock por debajo de 0."; `VALIDATION_ERROR`: "Ingresa un número entero válido." |
| `Switch` Activo        | Al desactivar: `ConfirmDialog` "¿Desactivar <nombre>? Dejará de ofrecerse a los clientes y las pizzas predefinidas que lo usan quedarán no disponibles. Los pedidos anteriores no cambian." (acción destructiva en `error`). Al activar: se envía directamente; si falta algún tamaño → `MISSING_SIZE_VALUES`: "No se puede activar: faltan precio y calorías de algún tamaño." con acción "Editar". **No existe "Eliminar"** (S-23); un tooltip del interruptor lo explica: "Los ingredientes no se eliminan, solo se desactivan." |

Estados: **cargando** (filas esqueleto); **vacío** (sin ingredientes: "Aún no hay ingredientes." + "Crear ingrediente"; con filtros: "Ningún ingrediente coincide con la búsqueda." + "Limpiar filtros"); **error** (`ErrorBanner` "No se pudo cargar el catálogo." + Reintentar); **guardando** (interruptor/botón deshabilitado con indicador); **éxito** (snackbar "Stock actualizado" / "Ingrediente desactivado").

---

## S-08 Ingrediente (admin, nuevo / editar)

- **Ruta/rol:** `/admin/ingredients/new` y `/admin/ingredients/:id`, Administrador. **API:** `GET /ingredient-categories`, `GET /vat-rates`, `GET /sizes`, `POST /ingredients` (alta), `PUT /ingredients/:id` (datos, IVA y valores por tamaño), `PATCH …/stock`, `PATCH …/status`.

```
+--------+---------------------------------------------------------------------+
| rail   | ← Ingredientes / Nuevo ingrediente                                   |
|        | +--------------------------------------------------------------+    |
|        | | DATOS                                                         |    |
|        | |  Código [QUE-MOZ____]   Nombre [Queso mozzarella__________]  |    |
|        | |  Categoría [Queso ▼]    Tarifa de IVA [ (•)15 %  ( )0 % ]    |    |
|        | |  Stock inicial [120]      [x] Activo   (solo al crear)       |    |
|        | +--------------------------------------------------------------+    |
|        | | VALORES POR TAMAÑO (precio sin IVA por porción)               |    |
|        | |  Tamaño      | Precio (USD)   | Calorías (kcal)               |    |
|        | |  Individual  | [ 1.00 ]       | [ 80 ]                        |    |
|        | |  Mediana     | [ 1.50 ]       | [ 110 ]                       |    |
|        | |  Familiar    | [ 2.20 ]       | [ 160 ]                       |    |
|        | |  Cada tamaño tiene su propio precio y calorías.              |    |
|        | +--------------------------------------------------------------+    |
|        |                               [Cancelar]  [Guardar ingrediente Ctrl+S]|
+--------+---------------------------------------------------------------------+
```

En modo **editar**, "Stock inicial" y "Activo" se reemplazan por dos tarjetas: "Stock" (valor actual + botón "Ajustar stock" → `StockDialog`) y "Estado" (interruptor Activo con el mismo diálogo de desactivación), porque `PUT` no admite esos campos.

| Campo               | Regla                                                         | Mensaje                                                             |
| ------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------- |
| Código              | 2 a 20 caracteres, `A-Z 0-9 -`, se muestra en mayúsculas      | "Usa 2 a 20 caracteres: letras mayúsculas, números y guion."        |
| Nombre              | 2 a 80                                                        | "Ingresa un nombre (2 a 80 caracteres)."                            |
| Categoría           | Obligatoria (Masa, Salsa, Queso, Carne, Vegetal, Otros)       | "Elige una categoría."                                              |
| Tarifa de IVA       | `SegmentedButton`/radio "15 %" (por defecto) o "0 %"          | "Elige una tarifa de IVA válida (15 % o 0 %)." (`INVALID_VAT_RATE`) |
| Stock               | entero ≥ 0                                                    | "El stock debe ser un número entero mayor o igual a 0."             |
| Precio por tamaño   | decimal ≥ 0, máx. 2 decimales (se envía como string `"1.50"`) | "El precio no puede ser negativo." / "Usa como máximo 2 decimales." |
| Calorías por tamaño | entero ≥ 0                                                    | "Las calorías deben ser un número entero mayor o igual a 0."        |

Estados y errores: **cargando** (catálogos y, en edición, el ingrediente); **error de carga** (`ErrorBanner` + Reintentar; `404 NOT_FOUND`: "Este ingrediente no existe."); **guardando** ("Guardando…"); `INGREDIENT_CODE_EXISTS` → error en Código: "Ya existe un ingrediente con ese código."; `MISSING_SIZE_VALUES` → se resaltan las filas de `details[].missing` con "Falta el valor de este tamaño." y banner "Define precio y calorías para los tres tamaños."; `INGREDIENT_CATEGORY_LOCKED` → banner "No se puede cambiar la categoría: el ingrediente se usa en las pizzas predefinidas: <lista de details[].presetPizzas>."; `VALIDATION_ERROR` → mensaje por campo según `details[].path`. Salir con cambios sin guardar pide confirmación ("¿Descartar los cambios?"). Éxito: snackbar "Ingrediente guardado" y vuelta a S-07. Aviso en edición: "Los cambios de precio, calorías e IVA aplican a nuevos pedidos; los pedidos anteriores conservan sus valores."

---

## S-09 Pizzas predefinidas (admin, lista)

- **Ruta/rol:** `/admin/presets`, Administrador. **API:** `GET /preset-pizzas?includeInactive=true`, `PATCH /preset-pizzas/:id/status`.

```
+--------+--------------------------------------------------------------------------------+
| rail   | Pizzas predefinidas                                [+ Nueva pizza    Ctrl+N]     |
|        | [ ] Mostrar inactivas                                                          |
|        | +----------------------------------------------------------------------------+ |
|        | | Orden|Nombre     |Código    |Receta                     |Individual|Mediana|Familiar|Estado|Activa|✎|
|        | |  1   |Margarita  |MARGHERITA|Masa trad., Salsa tomate…  |$5.10·610 |...    |...     |{Disponible}|[on]|✎|
|        | |  3   |Hawaiana   |HAWAIIAN  |...                        |...       |...    |...     |{No disp.: falta Piña}|[on]|✎|
|        | +----------------------------------------------------------------------------+ |
+--------+--------------------------------------------------------------------------------+
```

- Columnas: Orden (`sortOrder`), Nombre, Código, Receta (resumen), precio · kcal por tamaño (calculados por el motor, `pricesBySize`; **no hay campo de precio fijo**, S-18), disponibilidad (`AvailabilityChip` + `unavailableReasons`), `Switch` Activa (con `ConfirmDialog` al desactivar: "¿Desactivar <nombre>? Dejará de mostrarse a los clientes. Los pedidos anteriores no cambian."), editar. No existe "Eliminar" (baja lógica, ADR-010).
- Estados: cargando (filas esqueleto); vacío ("Aún no hay pizzas predefinidas." + "Nueva pizza"); error ("No se pudieron cargar las pizzas predefinidas." + Reintentar).

---

## S-10 Pizza predefinida (admin, nueva / editar)

- **Ruta/rol:** `/admin/presets/new`, `/admin/presets/:id`. **API:** `GET /ingredients?includeInactive=true` (para elegir), `GET /preset-pizzas/:id`, `POST`/`PUT /preset-pizzas`, `POST /orders/quote` para la vista previa de precio.

```
+--------+---------------------------------------------------------------------------+
| rail   | ← Pizzas predefinidas / Margarita                                          |
|        | DATOS   Código [MARGHERITA]  Nombre [Margarita]  Orden [1]                 |
|        |         Descripción [Tomate, mozzarella y albahaca_______________]         |
|        | RECETA                                                                     |
|        |  Masa  [Masa tradicional ▼]   (porción fija: 1)                            |
|        |  Salsa [Salsa de tomate  ▼]   (porción fija: 1)                            |
|        |  Ingredientes (porciones 1 a 3 por ingrediente, sin repetir):              |
|        |  [x] Queso mozzarella      Porciones [ - 2 + ]                             |
|        |  [x] Albahaca              Porciones [ - 1 + ]                             |
|        |  [ ] Pepperoni  ...                                                        |
|        | VISTA PREVIA (calculada, sin IVA)                                          |
|        |  Individual $ 5.10 · 610 kcal | Mediana $ 7.50 · 690 kcal | Familiar $ ...|
|        |                                  [Cancelar]  [Guardar pizza   Ctrl+S]      |
+--------+---------------------------------------------------------------------------+
```

| Elemento     | Detalle                                                                                                                                                                                                                                                                          |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Masa / Salsa | Desplegables con ingredientes de categoría Masa / Salsa (incluye inactivos con la marca "(inactivo)"; el contrato lo permite y la pizza quedará no disponible).                                                                                                                  |
| Toppings     | Mismas filas con casilla + `PortionStepper` 1..3 (sin límite de stock en el admin; muestra `StockBadge` informativo). Los de categoría masa/salsa no aparecen. **Sin mínimo de 3 ingredientes** (S-17); texto de ayuda: "Las predefinidas pueden tener menos de 3 ingredientes." |
| Vista previa | Una sola llamada `POST /orders/quote` con 3 ítems `CUSTOM` (uno por tamaño) con la receta en edición; se muestran `items[i].unitPrice` y `unitCalories`; se ignora `MIN_TOPPINGS_NOT_MET`. Sin campo de precio.                                                                  |
| Validaciones | Código (2 a 30, mayúsculas/guion bajo), Nombre (2 a 80), Descripción (máx. 300), Orden (entero). Receta: exactamente 1 masa y 1 salsa.                                                                                                                                           |

Errores: `PRESET_CODE_EXISTS` → "Ya existe una pizza con ese código." (campo Código); `PRESET_NAME_EXISTS` → "Ya existe una pizza con ese nombre." (campo Nombre); `INVALID_RECIPE` → lista por `details[].code` (§6.2) junto a la sección Receta ("Elige una masa.", "Máximo 3 porciones por ingrediente (…).", "Un ingrediente aparece repetido; usa la cantidad.", "La masa y la salsa no se agregan como ingredientes adicionales."); `NOT_FOUND` → "Esta pizza ya no existe." Estados: cargando, error con Reintentar, guardando, éxito ("Pizza guardada"). Aviso: "Los cambios de receta afectan solo a pedidos nuevos."

---

## S-11 Gestión de pedidos (admin, lista)

- **Ruta/rol:** `/admin/orders`, Administrador. **API:** `GET /orders` (todos; `status`, `from`, `to`, `search`, `page`, `pageSize`).

```
+--------+------------------------------------------------------------------------------------+
| rail   | Pedidos                                                         [Actualizar ⟳ F5] |
|        | [🔍 Nº de orden o email] Estado [Todos ▼] Desde [dd/mm/aaaa] Hasta [dd/mm/aaaa]    |
|        | +------------------------------------------------------------------------------+   |
|        | |Nº de orden      |Fecha            |Cliente           |Pizzas|Total   |Estado    |   |
|        | |GP-20261106-0003 |06/11/2026 12:15 |Ana Pérez         |  3   |$ 25.44 |{Pendiente}|  |
|        | |GP-20261106-0001 |06/11/2026 10:04 |Luis Mora         |  2   |$ 21.31 |{En prepar.}| |
|        | +------------------------------------------------------------------------------+   |
|        |                                         Página 1 de 5   [<] [>]                     |
+--------+------------------------------------------------------------------------------------+
```

- Por defecto: todos los estados, más recientes primero. Chips rápidos de estado con contador opcional (no obligatorio). Clic/`Enter` abre S-12. Hover resalta la fila.
- Estados: cargando (filas esqueleto); vacío ("No hay pedidos todavía." / con filtros: "Ningún pedido coincide con los filtros." + "Limpiar filtros"); error ("No se pudieron cargar los pedidos." + Reintentar).

---

## S-12 Pedido (admin): comprobante y cambio de estado

- **Ruta/rol:** `/admin/orders/:id`. **API:** `GET /orders/:id`, `PATCH /orders/:id/status`.

```
+--------+---------------------------------------------------+------------------------------+
| rail   |  ← Pedidos      Pedido GP-20261106-0001           | GESTIÓN DEL ESTADO           |
|        |  [ ReceiptView completo (ver S-13) ]              | Estado actual: {Pendiente}   |
|        |                                                   |                              |
|        |                                                   | [ Pasar a En preparación ]   |
|        |                                                   |                              |
|        |                                                   | Historial                    |
|        |                                                   | · Pendiente — 10:04 (Ana P.) |
|        |                                                   | · En preparación — 10:20     |
+--------+---------------------------------------------------+------------------------------+
```

| Estado actual  | Acción disponible                                                       |
| -------------- | ----------------------------------------------------------------------- |
| Pendiente      | Botón "Pasar a En preparación" (`FilledButton`).                        |
| En preparación | Botón "Marcar como Entregado".                                          |
| Entregado      | Sin botón; texto "Este pedido ya fue entregado. No admite más cambios." |

- El botón abre `ConfirmDialog`: "¿Pasar el pedido GP-… a En preparación? Esta acción no se puede deshacer." [Cancelar] [Confirmar]. No hay retroceso ni salto de estados ni cancelación (el panel no ofrece otras opciones).
- Historial desde `statusHistory` (estado, fecha, `changedBy.fullName`).
- Errores: `INVALID_STATUS_TRANSITION` (422) → diálogo "El pedido ya cambió de estado" con "Actualizar"; `NOT_FOUND` → "El pedido ya no está disponible." y vuelve a la lista; `FORBIDDEN` → "No tienes permiso para esta acción." Estados: cargando, error + Reintentar, procesando ("Actualizando…"), éxito (snackbar "Estado actualizado: En preparación" y `Semantics` anuncia el cambio).

---

## 2. Diálogos compartidos

| Diálogo                  | Contenido                                                                                                                        | Foco inicial      |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------- | ----------------- |
| `ConfirmDialog` genérico | Título, mensaje, [Cancelar] y acción principal (en `error` si es destructiva). `Esc` cancela; `Enter` activa la acción enfocada. | "Cancelar"        |
| Confirmar pedido         | Ver S-05.                                                                                                                        | "Cancelar"        |
| Stock insuficiente       | Lista "<nombre>: solicitado N, disponible M" de `details`; [Ajustar pedido].                                                     | Botón             |
| El precio cambió         | Total nuevo vs anterior; [Revisar pedido] [Aceptar y confirmar].                                                                 | "Revisar pedido"  |
| Descartar cambios        | "¿Descartar los cambios? Se perderán los datos no guardados." [Seguir editando] [Descartar].                                     | "Seguir editando" |
| Sesión expirada          | "Tu sesión expiró. Inicia sesión de nuevo." [Iniciar sesión].                                                                    | Botón             |
| Atajos (F1)              | Tabla de atajos (`responsive.md` §5).                                                                                            | Botón Cerrar      |

---

## 6. Mapeo de errores del contrato a mensajes de la interfaz

El `message` del servidor ya está en español y es apto para mostrar. Regla: la UI decide por `code` (nunca por texto); para códigos de negocio muestra el `message` del servidor (con `details` para enriquecer) y usa los textos de abajo como **respaldo** o cuando el mensaje debe ser genérico.

### 6.1 Errores generales y de HTTP

| HTTP | `code`                                               | Mensaje en la UI                                                                                                               | Presentación                     |
| ---- | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ | -------------------------------- |
| —    | (sin respuesta, timeout, `DioException` de conexión) | "No se pudo conectar con el servidor. Verifica que el servicio esté en ejecución e inténtalo de nuevo."                        | `ErrorBanner` + Reintentar       |
| 400  | `VALIDATION_ERROR`                                   | Mensaje de cada `details[].message` en el campo `details[].path`; si no hay campo: "Revisa los datos ingresados."              | Error en campo / banner          |
| 401  | `UNAUTHENTICATED`                                    | "Inicia sesión para continuar."                                                                                                | Redirige a `/login`              |
| 401  | `TOKEN_EXPIRED`                                      | (sin mensaje) refresco silencioso y reintento                                                                                  | Interceptor                      |
| 401  | `INVALID_CREDENTIALS`                                | "Email o contraseña incorrectos."                                                                                              | Banner en S-01                   |
| 401  | `INVALID_REFRESH_TOKEN`                              | "Tu sesión expiró. Inicia sesión de nuevo."                                                                                    | Diálogo + `/login`               |
| 403  | `FORBIDDEN`                                          | "No tienes permiso para realizar esta acción." (en S-01: "Tu cuenta está desactivada. Consulta con el local.")                 | Snackbar / banner                |
| 404  | `NOT_FOUND`                                          | "No encontramos lo que buscas. Puede que ya no esté disponible."                                                               | `EmptyState` / snackbar          |
| 404  | `ROUTE_NOT_FOUND`                                    | "Ocurrió un problema interno de la aplicación. Actualiza e inténtalo de nuevo."                                                | Snackbar (error de programación) |
| 409  | `EMAIL_ALREADY_EXISTS`                               | "Este email ya está registrado."                                                                                               | Campo Email (S-02)               |
| 409  | `INGREDIENT_CODE_EXISTS`                             | "Ya existe un ingrediente con ese código."                                                                                     | Campo Código (S-08)              |
| 409  | `PRESET_CODE_EXISTS`                                 | "Ya existe una pizza con ese código."                                                                                          | Campo Código (S-10)              |
| 409  | `PRESET_NAME_EXISTS`                                 | "Ya existe una pizza con ese nombre."                                                                                          | Campo Nombre (S-10)              |
| 409  | `INSUFFICIENT_STOCK`                                 | Mensaje del servidor: "No hay stock suficiente de <nombre>: solicitado N, disponible M." (una línea por elemento de `details`) | Diálogo en S-05                  |
| 409  | `PRICE_CHANGED`                                      | "El precio cambió. El total ahora es $ X (antes $ Y)." (`details[0].quote.totals.total`)                                       | Diálogo en S-05                  |
| 422  | `PIZZA_RULES_VIOLATED`                               | Una línea por violación de `details` (§6.2), indicando la pizza (`itemIndex + 1`)                                              | Banner en S-05                   |
| 422  | `MISSING_SIZE_VALUES`                                | "Define precio y calorías para los tres tamaños." (+ tamaños de `details[].missing`)                                           | Banner + filas resaltadas (S-08) |
| 422  | `INVALID_RECIPE`                                     | Una línea por violación de `details` (§6.2)                                                                                    | Sección Receta (S-10)            |
| 422  | `INGREDIENT_CATEGORY_LOCKED`                         | "No se puede cambiar la categoría: el ingrediente se usa en: <details[].presetPizzas>."                                        | Banner (S-08)                    |
| 422  | `INVALID_STATUS_TRANSITION`                          | "El pedido ya cambió de estado. Actualiza para ver el estado actual."                                                          | Diálogo (S-12)                   |
| 422  | `INVALID_VAT_RATE`                                   | "Elige una tarifa de IVA válida (15 % o 0 %)."                                                                                 | Campo IVA (S-08)                 |
| 422  | `STOCK_WOULD_BE_NEGATIVE`                            | "El ajuste dejaría el stock por debajo de 0."                                                                                  | `StockDialog`                    |
| 429  | `RATE_LIMITED`                                       | "Demasiadas solicitudes. Espera unos minutos e inténtalo de nuevo."                                                            | Banner / snackbar                |
| 500  | `INTERNAL_ERROR`                                     | "Ocurrió un error inesperado. Inténtalo de nuevo."                                                                             | Snackbar + Reintentar            |
| 503  | `SERVICE_UNAVAILABLE`                                | "El servicio no está disponible en este momento. Inténtalo de nuevo en unos minutos."                                          | `ErrorBanner`                    |

Cualquier `code` desconocido: "Ocurrió un error inesperado. Inténtalo de nuevo." (nunca se muestra el código ni el stack).

### 6.2 Violaciones de reglas de armado (`/orders/quote`, `PIZZA_RULES_VIOLATED`, `INVALID_RECIPE`)

| `code` de violación                    | Texto mostrado (mensaje del servidor o respaldo)                          | Dónde aparece                                                                                                                         |
| -------------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `DOUGH_REQUIRED`                       | "Elige una masa."                                                         | Sección Masa (error) y panel "Tu pizza"                                                                                               |
| `SAUCE_REQUIRED`                       | "Elige una salsa base."                                                   | Sección Salsa y panel                                                                                                                 |
| `INVALID_DOUGH` / `INVALID_SAUCE`      | "El ingrediente elegido no es una masa / salsa."                          | Panel (no debería ocurrir: la UI filtra por categoría)                                                                                |
| `INGREDIENT_CATEGORY_NOT_ALLOWED`      | "La masa y la salsa no se agregan como ingredientes adicionales."         | Panel (la UI no las ofrece como ingredientes)                                                                                         |
| `DUPLICATE_INGREDIENT`                 | "Un ingrediente aparece repetido; usa la cantidad."                       | Panel (la UI usa cantidad, no filas repetidas)                                                                                        |
| `MAX_PORTIONS_EXCEEDED`                | "Máximo 3 porciones por ingrediente (<nombre>: N)."                       | Fila del ingrediente (`ingredientId`) y panel                                                                                         |
| `MIN_TOPPINGS_NOT_MET`                 | "Elige al menos 3 ingredientes distintos." (`meta.current` de `meta.min`) | Panel, contador "Ingredientes: 1 de 3 mínimos" junto al título de la sección 4. Solo en pizzas desde cero (no aplica a predefinidas). |
| `INGREDIENT_NOT_FOUND`                 | "Ingrediente inexistente."                                                | Panel; recargar catálogo                                                                                                              |
| `INGREDIENT_INACTIVE`                  | "El ingrediente <nombre> no está disponible."                             | Fila (deshabilitada tras recargar) y panel                                                                                            |
| `MISSING_SIZE_VALUES`                  | "El ingrediente <nombre> no tiene precio para el tamaño elegido."         | Fila y panel                                                                                                                          |
| `PRESET_NOT_FOUND` / `PRESET_INACTIVE` | "La pizza predefinida no existe / no está disponible."                    | Banner en S-04/S-05                                                                                                                   |
| `PRESET_UNAVAILABLE`                   | "La pizza <nombre> no está disponible: falta <ingrediente>."              | Tarjeta (S-03), banner (S-04/S-05)                                                                                                    |
| `INSUFFICIENT_STOCK`                   | "No hay stock suficiente de <nombre>: solicitado N, disponible M."        | Panel/banner; fila del ingrediente                                                                                                    |

Reglas de presentación: cada violación se muestra como icono (`error_outline`) + texto (nunca solo color); el contenedor de mensajes es una región `liveRegion` para que el lector de pantalla las anuncie al cambiar; los mensajes de campo conservan el foco lógico (al fallar el envío, el foco va al primer campo con error).

---

## 7. Resumen de cobertura de requisitos

| Requisito                  | Pantallas                                         |
| -------------------------- | ------------------------------------------------- |
| RF-01, RF-02               | S-01, S-02                                        |
| RF-04, RF-05, RF-06, RF-29 | S-07, S-08                                        |
| RF-07, RF-08               | S-09, S-10, S-03                                  |
| RF-09..RF-14               | S-04                                              |
| RF-15, RF-16, RF-17, RF-18 | S-05 (y S-04 en vivo)                             |
| RF-21, RF-23               | S-11, S-12                                        |
| RF-22                      | S-06, S-13                                        |
| RF-24, RF-25               | S-13 (comprobante) y logotipo en S-01, S-02, rail |
| RF-28                      | Rail y las 13 pantallas                           |
