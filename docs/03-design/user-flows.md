# Flujos de usuario — Good Pizza

- **Fase:** 3 (Diseño UX/UI) · **Versión:** 1.0 · **Fecha:** 2026-11-06
- Rutas de `docs/02-architecture/architecture.md` §3.4. Códigos de error del contrato `api-contract.md` §1.2/§1.3. Pantallas: ver `screens.md` (S-xx).

## 1. Mapa de navegación y redirecciones por sesión y rol

```mermaid
flowchart TD
    START([Abrir app]) --> TOK{¿Hay token válido\nen secure storage?}
    TOK -- No --> LOGIN[S-01 /login]
    TOK -- Sí --> ME[GET /auth/me]
    ME -- 401 / INVALID_REFRESH_TOKEN --> LOGIN
    ME -- rol CLIENT --> PRESETS[S-03 /presets]
    ME -- rol ADMIN --> AING[S-07 /admin/ingredients]
    LOGIN -- "Crear cuenta" --> REG[S-02 /register]
    REG -- "Ya tengo cuenta" --> LOGIN
    REG -- registro OK, sesión iniciada --> PRESETS
    LOGIN -- login CLIENT --> PRESETS
    LOGIN -- login ADMIN --> AING

    subgraph CLI["Cliente (NavigationRail)"]
        PRESETS <--> BUILDER[S-04 /builder]
        PRESETS --> CART[S-05 /cart]
        BUILDER --> CART
        CART --> MYORD[S-06 /orders]
        MYORD <--> DETAIL[S-13 /orders/:id comprobante]
        CART -- confirmar OK --> DETAIL
    end

    subgraph ADM["Administrador (NavigationRail)"]
        AING <--> AINGF[S-08 /admin/ingredients/new y /:id]
        APRE[S-09 /admin/presets] <--> APREF[S-10 /admin/presets/new y /:id]
        AORD[S-11 /admin/orders] <--> AORDD[S-12 /admin/orders/:id]
        AING <--> APRE
        APRE <--> AORD
    end

    CLI -- "ruta /admin/*" --> PRESETS
    ADM -- "ruta de cliente" --> AING
    CLI -- Cerrar sesión --> LOGIN
    ADM -- Cerrar sesión --> LOGIN
```

Regla: cualquier `401 TOKEN_EXPIRED` se resuelve en silencio con un único refresh (interceptor). Si falla (`INVALID_REFRESH_TOKEN`) se limpia la sesión, se muestra "Tu sesión expiró. Inicia sesión de nuevo." y se redirige a `/login`.

## 2. Registro e inicio de sesión

```mermaid
flowchart TD
    A[S-02 Registro] --> B[Escribe nombre, email,\ncontraseña, repetir contraseña]
    B --> C{Validación local:\nnombre 2 a 120, email válido,\ncontraseña 8 a 72 y coincide}
    C -- Falla --> B
    C -- OK --> D[POST /auth/register]
    D -- 201 --> E[Sesión iniciada: guarda tokens\ny redirige a /presets]
    D -- 409 EMAIL_ALREADY_EXISTS --> F["Error en el campo email:\n'Este email ya está registrado.'\nEnlace: Iniciar sesión"]
    D -- 400 VALIDATION_ERROR --> G[Mensajes por campo según details.path]
    D -- 429 RATE_LIMITED --> H[Banner: demasiados intentos]
    F --> B
    G --> B
    H --> B

    L[S-01 Login] --> M[Email + contraseña]
    M --> N[POST /auth/login]
    N -- 200 CLIENT --> E
    N -- 200 ADMIN --> O[Redirige a /admin/ingredients]
    N -- 401 INVALID_CREDENTIALS --> P["Banner: 'Email o contraseña incorrectos.'\n(sin indicar cuál falló)"]
    N -- 403 FORBIDDEN --> Q["Banner: cuenta desactivada"]
    N -- 429 --> H
    P --> M
```

## 3. Cliente: de pizzas predefinidas a comprobante

```mermaid
flowchart TD
    P[S-03 Pizzas predefinidas] --> P1{¿Qué hace el cliente?}
    P1 -- "Elige tamaño y pulsa Agregar al pedido\n(receta tal cual)" --> AVAIL{¿Disponible?}
    AVAIL -- No --> NOAV["Botones deshabilitados +\n'No disponible: falta Y'"]
    AVAIL -- Sí --> ADD1[Agrega línea PRESET sin extras\nal carrito, cantidad 1]
    P1 -- "Pulsa Personalizar" --> B1[S-04 /builder con presetId y size\nreceta marcada y bloqueada]
    P1 -- "Menú: Personalizar pizza" --> B2[S-04 /builder\npizza desde cero]
    B1 --> BUILD[Armado: ver flujo 4]
    B2 --> BUILD
    BUILD --> ADD2[Agregar al pedido]
    ADD1 --> C[S-05 Resumen del pedido]
    ADD2 --> SNACK["Snackbar 'Pizza agregada' con acción 'Ver pedido'"]
    SNACK --> C
    C --> Q[POST /orders/quote con todas las líneas]
    Q --> V{valid?}
    V -- No --> VB["Banner de violaciones\n(stock agregado o regla)"]
    VB --> FIX[Cambiar cantidades, quitar línea\no volver a personalizar]
    FIX --> Q
    V -- Sí --> CONF[Pulsa Confirmar pedido\ny acepta el diálogo]
    CONF --> POST[POST /orders con expectedTotal]
    POST -- 201 --> OK[S-13 Comprobante\nbanner 'Pedido GP-... confirmado'\ncarrito vacío]
    POST -- 409 INSUFFICIENT_STOCK --> E1[Diálogo: ingrediente, solicitado, disponible\ny botón Ajustar pedido]
    E1 --> FIX
    POST -- 409 PRICE_CHANGED --> E2["Diálogo 'El precio cambió'\ncon nuevo total"]
    E2 -- Aceptar y confirmar --> POST
    E2 -- Revisar --> Q
    POST -- 422 PIZZA_RULES_VIOLATED --> E3[Banner con violaciones por línea]
    E3 --> FIX
    POST -- 403 FORBIDDEN --> E4["'Tu cuenta no puede crear pedidos.'"]
    POST -- red, 500 o 503 --> E5[Banner con Reintentar;\nel carrito se conserva]
    OK --> MY[S-06 Mis pedidos]
```

## 4. Armado de la pizza con cálculo en vivo (S-04)

```mermaid
flowchart TD
    S([Entra a Personalizar pizza]) --> L[Carga GET /sizes y GET /ingredients\nsin page, lista completa con stock]
    L -- error --> LE[ErrorBanner + Reintentar]
    L -- OK --> INIT{¿Viene presetId?}
    INIT -- Sí --> PRE[GET /preset-pizzas/:id\nreceta marcada y bloqueada,\nporciones de receta = mínimo]
    INIT -- No --> EMPTY[Tamaño Mediana por defecto,\nnada marcado]
    PRE --> SEL
    EMPTY --> SEL
    SEL[Cliente cambia la selección] --> WHAT{¿Qué cambió?}
    WHAT -- Tamaño --> RECALC
    WHAT -- "Masa o salsa (exclusivo:\nmarcar otra desmarca la anterior)" --> RECALC
    WHAT -- "Marca o desmarca ingrediente" --> RECALC
    WHAT -- "Porciones 1 a 3" --> LIM{"¿Supera el límite local?\nmin de 3 menos receta y stock"}
    LIM -- Sí --> TIP["No avanza; mensaje:\n'Máximo 3 porciones por ingrediente'\no 'Stock disponible: N'"]
    LIM -- No --> RECALC
    WHAT -- "Cantidad de pizzas 1 a 20" --> RECALC
    RECALC["Estado local inmediato, luego\ndebounce 150 ms y POST /orders/quote\n(cancela la petición anterior)"] --> R{Respuesta}
    R -- "200 valid=true" --> OKP[Muestra calorías y precio;\nAgregar al pedido habilitado]
    R -- "200 valid=false" --> VIOL["Muestra importes parciales y mensajes\nde items[0].violations y violations raíz;\nAgregar deshabilitado con el motivo"]
    R -- "400 o error de red" --> ERRQ["Aviso 'No se pudo calcular' + Reintentar;\nAgregar deshabilitado"]
    OKP --> SEL
    VIOL --> SEL
    OKP --> ADD[Agregar al pedido: pasa al carrito]
```

Mensajes por violación (`code` a ubicación en la UI): ver `screens.md` §6.2.

## 5. Administrador: ingredientes

```mermaid
flowchart TD
    A[S-07 Lista de ingredientes] --> B{Acción}
    B -- Nuevo --> C[S-08 Formulario nuevo]
    B -- "Editar fila" --> D[S-08 Formulario edición]
    B -- "Switch Activo" --> E[Diálogo de confirmación]
    B -- "Ajustar stock" --> F[Diálogo de stock: Fijar o Ajustar]
    B -- "Buscar, filtrar, ver inactivos" --> A
    C --> G[POST /ingredients]
    G -- 201 --> A
    G -- 409 INGREDIENT_CODE_EXISTS --> H[Error en el campo Código]
    G -- 422 MISSING_SIZE_VALUES --> I[Resalta los tamaños faltantes]
    G -- 400 VALIDATION_ERROR --> J[Errores por campo]
    H --> C
    I --> C
    J --> C
    D --> K[PUT /ingredients/:id]
    K -- 200 --> A
    K -- 422 INGREDIENT_CATEGORY_LOCKED --> L["Aviso: la categoría no puede cambiar;\nlista las predefinidas que lo usan"]
    K -- "409, 422 o 400" --> D
    E -- Confirma --> M[PATCH /ingredients/:id/status]
    M -- 200 --> A
    M -- "422 MISSING_SIZE_VALUES al activar" --> N["Mensaje: faltan valores de tamaño y acción Editar"]
    F --> O[PATCH /ingredients/:id/stock]
    O -- 200 --> A
    O -- 422 STOCK_WOULD_BE_NEGATIVE --> P["'El ajuste dejaría el stock por debajo de 0.'"]
    P --> F
```

## 6. Administrador: pizzas predefinidas

```mermaid
flowchart TD
    A[S-09 Lista de predefinidas] --> B{Acción}
    B -- Nueva --> C[S-10 Formulario]
    B -- Editar --> C
    B -- "Switch Activa" --> D[PATCH /preset-pizzas/:id/status]
    C --> E[Elige masa, salsa y toppings con porciones 1 a 3]
    E --> F["Vista previa de precio y kcal por tamaño\n(POST /orders/quote con 3 ítems CUSTOM;\nse ignora MIN_TOPPINGS_NOT_MET)"]
    F --> G[Guardar: POST o PUT /preset-pizzas]
    G -- "200 o 201" --> A
    G -- "409 PRESET_CODE_EXISTS o PRESET_NAME_EXISTS" --> H[Error en Código o Nombre]
    G -- 422 INVALID_RECIPE --> I["Errores de receta por details\n(DOUGH_REQUIRED, MAX_PORTIONS_EXCEEDED, ...)"]
    H --> C
    I --> C
```

Sin campo de precio: el precio de cada predefinida siempre se muestra calculado por fórmula (S-18).

## 7. Administrador: gestión de pedidos y estados

```mermaid
stateDiagram-v2
    [*] --> Pendiente: POST /orders (cliente)
    Pendiente --> EnPreparacion: Admin Pasar a En preparación
    EnPreparacion --> Entregado: Admin Marcar como Entregado
    Entregado --> [*]
```

Sin cancelar, sin retroceder, sin saltar estados. Solo el administrador cambia el estado.

```mermaid
flowchart TD
    A[S-11 Lista de todos los pedidos\nfiltros: estado, fechas, búsqueda nº o email] --> B[Abre pedido]
    B --> C[S-12 Detalle: comprobante y panel de estado]
    C --> D{Estado actual}
    D -- Pendiente --> E["Botón Pasar a En preparación"]
    D -- En preparación --> F["Botón Marcar como Entregado"]
    D -- Entregado --> G["Sin acciones: 'Pedido entregado'"]
    E --> H[ConfirmDialog]
    F --> H
    H -- Confirma --> I[PATCH /orders/:id/status]
    I -- 200 --> J[Actualiza comprobante, chip e historial;\nsnackbar 'Estado actualizado']
    I -- 422 INVALID_STATUS_TRANSITION --> K["'El pedido ya cambió de estado.'\nrecarga el detalle"]
    I -- 404 --> L["'El pedido ya no está disponible.' y vuelve a la lista"]
    I -- 403 --> M["'No tienes permiso para esta acción.'"]
```

El cliente ve el cambio al refrescar "Mis pedidos" (botón "Actualizar", `F5`) o al volver a abrir el detalle (PA-UX-07).

## 8. Confirmación de pedido: secuencia cliente, UI y API

```mermaid
sequenceDiagram
    actor C as Cliente
    participant UI as S-05 Resumen
    participant N as cartProvider y cartQuoteProvider
    participant API as API /api/v1
    C->>UI: Abre Mi pedido
    UI->>N: cotizar carrito
    N->>API: POST /orders/quote {items[]}
    API-->>N: {valid, violations, items, totals, stock}
    N-->>UI: totales, IVA y avisos
    C->>UI: Confirmar pedido (Ctrl+Enter) y acepta el diálogo
    UI->>N: confirm(expectedTotal = totals.total)
    N->>API: POST /orders {items[], expectedTotal}
    alt 201
        API-->>N: OrderDetail (PENDING)
        N-->>UI: vacía carrito, navega a /orders/:id
    else 409 INSUFFICIENT_STOCK
        API-->>N: details[{name, requested, available}]
        N-->>UI: diálogo Stock insuficiente y recotiza
    else 409 PRICE_CHANGED
        API-->>N: details[{quote}]
        N-->>UI: diálogo con nuevo total
    end
```
