# Arquitectura — Good Pizza

- **Fase:** 2 (Arquitectura) · **Versión:** 1.0 · **Fecha:** 2026-11-06
- **Entradas:** `docs/prompt-proyecto.md` (especificación, manda), `docs/01-requirements/` (RF-01..RF-29, RNF-01..RNF-10, S-01..S-26).
- **Documentos hermanos:** `data-model.md` (modelo y esquema Prisma), `api-contract.md` (contrato REST), `adr/` (decisiones).

> Nota de alcance: la plantilla del harness admite móvil/Linux/macOS, pero la especificación del proyecto manda **solo Windows** (RNF-07). La arquitectura no impide otras plataformas, pero no se configuran ni se prueban.

## 1. Vista general

Monolito en un único repositorio con dos piezas desplegables en la misma máquina del local:

- `backend/`: API REST Node.js 20 + Express, prefijo `/api/v1`, Prisma sobre PostgreSQL 17 (base `pizzeria`, ya existente; el modelo se crea con migraciones).
- `frontend/`: app Flutter de escritorio Windows (Material 3, español, NavigationRail) que consume la API por HTTP.

```mermaid
flowchart LR
    subgraph PC["PC del local (Windows)"]
        subgraph APP["frontend/ — Flutter Windows (good_pizza)"]
            UI["Presentation<br/>(pages, widgets)"]
            ST["Riverpod<br/>(Notifiers / AsyncNotifiers)"]
            RP["Repositorios por feature"]
            DIO["dio + AuthInterceptor"]
            SS[("flutter_secure_storage<br/>(Windows Credential Manager)")]
            UI --> ST --> RP --> DIO
            DIO <--> SS
        end
        subgraph API["backend/ — Node.js 20 + Express"]
            MW["Middlewares<br/>helmet · cors · rate-limit · json limit<br/>requireAuth · requireRole · validate(Zod)"]
            R["routes/"]
            C["controllers/"]
            S["services/"]
            ENG["services/pricing-engine/<br/>(motor de cálculo puro)"]
            PR["Prisma Client"]
            EH["errorHandler<br/>{error:{code,message,details}}"]
            MW --> R --> C --> S
            S --> ENG
            S --> PR
            C -. errores .-> EH
        end
        DB[("PostgreSQL 17<br/>base pizzeria")]
        ENV[["backend/.env.local<br/>(no versionado, no se lee por agentes)"]]
    end
    DIO -- "HTTP JSON /api/v1<br/>Bearer access token" --> MW
    PR -- "DATABASE_URL" --> DB
    ENV -. "dotenv-cli (npm scripts)" .-> API
```

Principios:

1. **Una sola fuente de verdad para las reglas de negocio**: el motor de cálculo del backend (ADR-002). Flutter no reimplementa fórmulas, IVA ni validaciones de armado; las pide a `POST /api/v1/orders/quote`.
2. **El servidor no confía en el cliente** (RNF-04): al confirmar, recalcula todo desde el catálogo y guarda snapshots (ADR-003).
3. **Integridad transaccional** del stock y del número de orden (ADR-004, ADR-005).
4. **Capas estrictas** en el backend y **feature-first** en el frontend.

## 2. Backend

### 2.1 Capas

```mermaid
flowchart TD
    REQ[HTTP request] --> SEC["Middlewares globales<br/>helmet, cors, express.json({limit:'100kb'}), rate-limit, pino-http"]
    SEC --> ROUTE["routes/*.routes.js<br/>solo enrutado + middlewares por ruta"]
    ROUTE --> AUTH["requireAuth → requireRole('ADMIN'|'CLIENT')"]
    AUTH --> VAL["validate(zodSchema) → req.body/query/params tipados"]
    VAL --> CTRL["controllers/*.controller.js<br/>HTTP in/out, sin lógica de negocio"]
    CTRL --> SVC["services/*.service.js<br/>reglas, transacciones, autorización por dueño"]
    SVC --> ENGINE["pricing-engine (funciones puras)<br/>sin Prisma, sin HTTP"]
    SVC --> PRISMA["lib/prisma.js (PrismaClient único)"]
    PRISMA --> PG[(PostgreSQL)]
    CTRL -->|"next(err)"| ERR["middlewares/errorHandler.js"]
    SVC -->|"throw AppError"| ERR
```

| Capa                       | Responsabilidad                                                                                                                                                      | No hace                 |
| -------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------- |
| `routes/`                  | Declara método + ruta, encadena `requireAuth`, `requireRole`, `validate`, controlador.                                                                               | Lógica, acceso a datos. |
| `middlewares/`             | Seguridad, autenticación JWT, autorización por rol, validación Zod, 404, manejo de errores.                                                                          | Reglas de negocio.      |
| `controllers/`             | Extrae datos validados, llama al servicio, mapea a respuesta `{ data }` y código HTTP.                                                                               | Prisma, cálculos.       |
| `services/`                | Casos de uso: auth, ingredientes, predefinidas, pedidos, cotización, stock, numeración. Autorización por dueño (un cliente solo ve sus pedidos). Abre transacciones. | Conocer `req`/`res`.    |
| `services/pricing-engine/` | Motor puro: cálculo de precio, calorías, IVA por componente con half-up, validaciones de armado, agregación de stock requerido. Recibe un "catálogo" ya cargado.     | I/O.                    |
| `lib/prisma.js`            | Instancia única de `PrismaClient`.                                                                                                                                   | —                       |
| `schemas/`                 | Esquemas Zod de request (body, query, params).                                                                                                                       | —                       |
| `utils/`                   | `AppError`, `asyncHandler`, `money` (Decimal, half-up, formato `"0.00"`), `dates` (fecha local del servidor).                                                        | —                       |

### 2.2 Estructura de carpetas propuesta (`backend/`)

```
backend/
├── env.template                 # nombres de variables (sin valores reales)
├── package.json                 # scripts: dev, start, test, lint, db:migrate, db:seed
├── vitest.config.js
├── prisma/
│   ├── schema.prisma            # ver data-model.md
│   ├── migrations/              # generadas con `npm run db:migrate -- --name <accion>`
│   └── seed.js                  # idempotente (upsert); contraseñas desde SEED_*_PASSWORD
├── src/
│   ├── server.js                # arranque (listen)
│   ├── app.js                   # construye la app Express (exportada para Supertest)
│   ├── config/
│   │   ├── env.js               # valida process.env con Zod al arrancar (falla rápido)
│   │   └── constants.js         # MAX_PORTIONS_PER_INGREDIENT=3, MIN_DISTINCT_TOPPINGS=3,
│   │                            # MAX_PIZZAS_PER_LINE=20, ORDER_NUMBER_PREFIX='GP', etc.
│   ├── lib/
│   │   ├── prisma.js
│   │   └── logger.js            # pino; redacta authorization, password, tokens
│   ├── middlewares/
│   │   ├── requireAuth.js       # valida access JWT → req.user = { id, role }
│   │   ├── requireRole.js
│   │   ├── validate.js
│   │   ├── rateLimiters.js      # globalLimiter, authLimiter
│   │   ├── notFound.js
│   │   └── errorHandler.js      # AppError, ZodError, Prisma P2002/P2025 → formato uniforme
│   ├── routes/
│   │   ├── index.js             # monta todo bajo /api/v1
│   │   ├── health.routes.js
│   │   ├── auth.routes.js
│   │   ├── catalog.routes.js    # sizes, ingredient-categories, vat-rates
│   │   ├── ingredients.routes.js
│   │   ├── presetPizzas.routes.js
│   │   └── orders.routes.js
│   ├── controllers/             # uno por archivo de rutas
│   ├── schemas/                 # auth.schemas.js, ingredient.schemas.js, preset.schemas.js, order.schemas.js
│   ├── services/
│   │   ├── auth.service.js          # registro, login, refresh con rotación, logout
│   │   ├── token.service.js         # firma/verificación JWT, hash de refresh tokens
│   │   ├── catalog.service.js       # tamaños, categorías, tarifas IVA
│   │   ├── ingredient.service.js    # CRUD + stock + activación (sin borrado)
│   │   ├── presetPizza.service.js   # CRUD + disponibilidad + precio por fórmula
│   │   ├── catalogLoader.service.js # carga ingredientes/valores/tarifas para el motor
│   │   ├── quote.service.js         # cotización (sin escritura)
│   │   ├── order.service.js         # confirmar pedido (transacción), listar, detalle, estado
│   │   ├── stock.service.js         # bloqueo FOR UPDATE + descuento condicional
│   │   ├── orderNumber.service.js   # secuencia diaria GP-AAAAMMDD-NNNN
│   │   └── pricing-engine/
│   │       ├── index.js             # API pública del motor
│   │       ├── buildPizza.js        # normaliza CUSTOM/PRESET a componentes
│   │       ├── validatePizza.js     # reglas de armado → violations[]
│   │       ├── calculatePizza.js    # precio, calorías, subtotales por tarifa
│   │       ├── calculateOrder.js    # subtotales 15/0, IVA half-up, total, calorías
│   │       └── stockRequirements.js # porciones requeridas agregadas por ingrediente
│   └── utils/
│       ├── AppError.js
│       ├── asyncHandler.js
│       ├── money.js
│       └── dates.js
└── tests/
    ├── unit/                    # pricing-engine, money, orderNumber (formato), validaciones
    ├── api/                     # Supertest: endpoints, permisos, formato de error
    └── helpers/                 # fábricas de catálogo, tokens de prueba
```

> Nota (fase 9): esta es la estructura propuesta en la fase 2. La estructura real está en `docs/04-backend/documentacion-tecnica.md` (por ejemplo, `routes/index.js` en lugar de `*.routes.js`) y en `docs/05-frontend/documentacion-tecnica.md` (`features/preset_pizzas` y `features/admin`).

### 2.3 Motor de cálculo (servicio único)

El motor vive en `src/services/pricing-engine/` y es **puro**: recibe una petición de pizzas y un objeto `catalog` (ingredientes con categoría, activo, stock, tarifa IVA y valores por tamaño; recetas de predefinidas) y devuelve un resultado determinista. No accede a Prisma, lo que permite probarlo con Vitest sin base de datos (requisito de pruebas del prompt).

```mermaid
flowchart LR
    IN["items[] (CUSTOM / PRESET)"] --> B["buildPizza<br/>CUSTOM: masa+salsa+toppings<br/>PRESET: receta + extras"]
    CAT["catalog (cargado por catalogLoader<br/>o bloqueado FOR UPDATE en la transacción)"] --> B
    B --> V["validatePizza → violations[]"]
    B --> CP["calculatePizza<br/>unitPrice, unitCalories,<br/>unitSubtotalVat15, unitSubtotalVat0"]
    CP --> CO["calculateOrder<br/>subtotales × cantidad,<br/>IVA 15 % half-up, total"]
    B --> SR["stockRequirements<br/>Σ porciones × cantidad por ingrediente"]
    SR --> V2["validar stock agregado vs disponible"]
    V --> OUT["QuoteResult { valid, violations, items, totals, stock }"]
    V2 --> OUT
    CO --> OUT
```

Reglas que implementa (todas en un solo lugar):

| Regla                                                                                                                       | Fuente                         | Código de violación                                                  |
| --------------------------------------------------------------------------------------------------------------------------- | ------------------------------ | -------------------------------------------------------------------- |
| Exactamente 1 masa (categoría `DOUGH`) y 1 salsa (`SAUCE`) por pizza, porción fija 1.                                       | Prompt, RF-09                  | `DOUGH_REQUIRED`, `SAUCE_REQUIRED`, `INVALID_DOUGH`, `INVALID_SAUCE` |
| Toppings solo de categorías `CHEESE`, `MEAT`, `VEGETABLE`, `OTHER`.                                                         | Derivado (ver ADR-002)         | `INGREDIENT_CATEGORY_NOT_ALLOWED`                                    |
| Máximo 3 porciones por ingrediente; en predefinidas cuenta receta + extras.                                                 | RF-10, RF-14, S-02             | `MAX_PORTIONS_EXCEEDED`                                              |
| Mínimo 3 toppings distintos solo en `CUSTOM`.                                                                               | RF-11, S-17                    | `MIN_TOPPINGS_NOT_MET`                                               |
| Predefinidas: solo agregar (los extras se suman a la receta, nunca restan).                                                 | RF-14, S-06                    | (estructural: el payload no permite quitar)                          |
| Ingrediente activo y con valores para el tamaño.                                                                            | RF-29, S-15                    | `INGREDIENT_INACTIVE`, `MISSING_SIZE_VALUES`                         |
| Predefinida activa y disponible (receta sin inactivos ni sin stock).                                                        | S-25                           | `PRESET_UNAVAILABLE`, `PRESET_INACTIVE`                              |
| Stock: Σ(porciones × cantidad) por ingrediente ≤ stock; masa y salsa 1 por pizza × cantidad.                                | RF-12, RF-18, S-03, S-04, S-12 | `INSUFFICIENT_STOCK`                                                 |
| Cantidad por línea 1..20.                                                                                                   | S-26                           | validación Zod (400)                                                 |
| Precio = Σ(precio(tamaño) × porciones) de masa, salsa y toppings; calorías ídem.                                            | RF-15                          | —                                                                    |
| Subtotal 15 % / 0 % según tarifa de cada componente; IVA = round_half_up(Subtotal15 × 0.15, 2); Total = Sub15 + Sub0 + IVA. | RF-16, S-19                    | —                                                                    |

Aritmética: `Prisma.Decimal` (decimal.js) en todo el cálculo; los precios de catálogo tienen 2 decimales, por lo que solo el IVA requiere redondeo (`ROUND_HALF_UP`, 2 decimales), aplicado una vez sobre el subtotal 15 % del pedido completo, no por línea (US-10). Las calorías son enteros.

Uso del motor:

- `quote.service` → carga el catálogo sin bloqueo, ejecuta el motor y devuelve `200` con `valid` y `violations` (no lanza 422), para que la UI muestre mensajes en vivo.
- `order.service.create` → dentro de `prisma.$transaction`: bloquea con `SELECT ... FOR UPDATE` (orden por id) las filas de ingredientes referenciados, ejecuta el **mismo** motor con esos valores bloqueados, lanza `422`/`409` si hay violaciones, descuenta stock, obtiene número de orden y persiste el pedido con snapshots.
- `presetPizza.service` → usa `calculatePizza` para mostrar precio y calorías por tamaño de cada predefinida (S-18: sin precio fijo).

### 2.4 Cálculo en vivo desde el frontend

Flutter no duplica reglas: el `PizzaBuilderController` (Riverpod) mantiene la selección y, ante cada cambio, llama a `POST /api/v1/orders/quote` con un `items[]` de un único elemento, con _debounce_ de ~150 ms y cancelación de la petición anterior (`CancelToken` de dio). En el resumen del pedido llama a la misma ruta con todas las líneas del carrito para obtener totales e IVA y validar el stock agregado.

```mermaid
sequenceDiagram
    actor C as Cliente
    participant UI as PizzaBuilderPage
    participant N as PizzaBuilderController (Riverpod)
    participant R as OrdersRepository (dio)
    participant API as POST /orders/quote
    participant E as pricing-engine
    C->>UI: marca queso x3
    UI->>N: setPortions(queso, 3)
    N->>N: actualiza selección (estado inmediato)
    N->>R: quote([pizza]) tras debounce 150 ms (cancela la anterior)
    R->>API: JSON items[]
    API->>E: build + validate + calculate
    E-->>API: QuoteResult
    API-->>R: 200 { data: { valid, violations, items, totals } }
    R-->>N: QuoteResult
    N-->>UI: precio, calorías, mensajes, botón "Agregar" habilitado/no
```

Límites locales en la UI que **no** son reglas de cálculo, sino restricciones de entrada derivadas de datos del servidor: el selector de porciones se limita a `min(3 - porcionesReceta, stockDisponible)` y la cantidad a 1..20 (RF-10, RF-12, US-06). La validación definitiva siempre es del servidor. RNF-01 (< 200 ms) se cumple en red local (API y BD en la misma máquina o LAN); mientras llega la respuesta se muestra el último valor con un indicador de actualización.

## 3. Frontend (`frontend/`)

### 3.1 Creación y dependencias

- Creación (dentro de `frontend/`): `flutter create --org com.pizzeria --project-name good_pizza --platforms=windows .`
- Nombre visible: "Good Pizza" (título de ventana en `windows/runner/main.cpp` y `MaterialApp.title`).
- Dependencias: `flutter_riverpod`, `go_router`, `dio`, `flutter_secure_storage`, `flutter_svg` (logo), `intl` + `flutter_localizations` (español, formato USD), `decimal` (parseo de importes en string). Desarrollo: `flutter_test`, `mocktail`, `flutter_lints`.
- Modelos inmutables escritos a mano (`const` + `fromJson`/`toJson`) para evitar `build_runner`; si backend y frontend crecen se puede migrar a `freezed`.

### 3.2 Estructura feature-first

```
frontend/
├── assets/
│   └── brand/good_pizza_logo.svg        # logotipo (lo diseña la fase UX/frontend)
├── lib/
│   ├── main.dart                        # ProviderScope + GoodPizzaApp
│   ├── app.dart                         # MaterialApp.router, tema, locale es
│   ├── core/
│   │   ├── config/app_config.dart       # API_URL vía --dart-define (incluye /api/v1)
│   │   ├── api/
│   │   │   ├── dio_provider.dart        # Dio con baseUrl y timeouts
│   │   │   ├── auth_interceptor.dart    # añade Bearer; ante 401 TOKEN_EXPIRED → refresh y reintento
│   │   │   └── api_exception.dart       # mapea {error:{code,message,details}}
│   │   ├── storage/token_storage.dart   # flutter_secure_storage (access + refresh)
│   │   ├── router/app_router.dart       # go_router + redirect por sesión y rol
│   │   ├── theme/                       # app_colors.dart (azul marino), app_theme.dart (M3 claro)
│   │   ├── widgets/                     # AppShell (NavigationRail), GoodPizzaLogo, AsyncValueView,
│   │   │                                # MoneyText, ErrorBanner, EmptyState
│   │   └── utils/money_format.dart      # "$ 7.50" a partir de string decimal
│   └── features/
│       ├── auth/            {data, domain, presentation}   # login, registro, sesión
│       ├── catalog/         {data, domain}                 # tamaños, ingredientes activos
│       ├── presets/         {data, domain, presentation}   # lista de predefinidas (cliente)
│       ├── pizza_builder/   {domain, presentation}         # "Personalizar pizza" + cotización en vivo
│       ├── cart/            {domain, presentation}         # resumen del pedido, confirmar
│       ├── orders/          {data, domain, presentation}   # mis pedidos, comprobante
│       ├── admin_ingredients/ {data, domain, presentation}
│       ├── admin_presets/     {data, domain, presentation}
│       └── admin_orders/      {data, domain, presentation}
└── test/
    ├── core/                # interceptor, formato de dinero
    ├── features/            # widget tests por pantalla con repositorios falsos
    └── flows/               # flujo "personalizar pizza → resumen → confirmar → comprobante"
```

Convenciones (skill `flutter-state-management`): los widgets nunca usan `dio`; cada feature expone un repositorio en `data/` inyectado por provider; la UI siempre maneja `AsyncValue` (loading / error con reintento / data con estado vacío); en pruebas se usan `ProviderContainer`/`ProviderScope` con `overrides` y repositorios falsos.

### 3.3 Estado (Riverpod)

| Provider                                                                  | Tipo                                        | Contenido                                                                                         |
| ------------------------------------------------------------------------- | ------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `sessionProvider`                                                         | `AsyncNotifier<Session?>`                   | Usuario actual (id, nombre, email, rol), tokens en secure storage; login/registro/logout.         |
| `sizesProvider`, `activeIngredientsProvider`                              | `FutureProvider`                            | Catálogo para el armado (incluye stock disponible y valores por tamaño para mostrar).             |
| `presetPizzasProvider`                                                    | `FutureProvider`                            | Predefinidas con precio/calorías por tamaño y disponibilidad.                                     |
| `pizzaBuilderProvider`                                                    | `Notifier<PizzaBuilderState>` (autoDispose) | Tamaño, masa, salsa, toppings, predefinida base, cantidad, último `QuoteResult`, estado de carga. |
| `cartProvider`                                                            | `Notifier<CartState>`                       | Líneas (payload + último quote por línea); en memoria, no persistido.                             |
| `cartQuoteProvider`                                                       | `FutureProvider`                            | Cotización del carrito completo (totales, IVA, stock agregado).                                   |
| `myOrdersProvider`, `orderDetailProvider(id)`                             | `AsyncNotifier` / `FutureProvider.family`   | Historial y comprobante; refresco manual.                                                         |
| `adminIngredientsProvider`, `adminPresetsProvider`, `adminOrdersProvider` | `AsyncNotifier`                             | Listados y mutaciones de administración.                                                          |

### 3.4 Navegación (go_router + NavigationRail)

`AppShell` es un `ShellRoute` con `NavigationRail` (Material 3) cuyas entradas dependen del rol. `redirect`: sin sesión → `/login`; con sesión en `/login` → inicio por rol; ruta `/admin/*` con rol CLIENT → inicio cliente (y viceversa).

| Rol     | Ruta                                                                     | Pantalla                                            |
| ------- | ------------------------------------------------------------------------ | --------------------------------------------------- |
| Público | `/login`, `/register`                                                    | Login, Registro                                     |
| Cliente | `/presets`                                                               | Pizzas predefinidas (inicio cliente)                |
| Cliente | `/builder` (`?presetId=&size=`)                                          | Personalizar pizza                                  |
| Cliente | `/cart`                                                                  | Resumen del pedido                                  |
| Cliente | `/orders`, `/orders/:id`                                                 | Mis pedidos, comprobante                            |
| Admin   | `/admin/ingredients`, `/admin/ingredients/new`, `/admin/ingredients/:id` | Ingredientes                                        |
| Admin   | `/admin/presets`, `/admin/presets/new`, `/admin/presets/:id`             | Pizzas predefinidas                                 |
| Admin   | `/admin/orders`, `/admin/orders/:id`                                     | Gestión de pedidos (comprobante + cambio de estado) |

## 4. Autenticación y autorización

Detalle en ADR-006.

- **Registro** público (`POST /auth/register`): crea siempre rol `CLIENT` (S-14). Contraseña ≥ 8 caracteres (S-21), hash bcrypt con coste `BCRYPT_COST` (≥ 12). Email normalizado a minúsculas y único.
- **Login** (`POST /auth/login`): mensaje genérico `INVALID_CREDENTIALS` ante email o contraseña erróneos (US-02). Limitador específico `authLimiter`.
- **Access token**: JWT HS256 firmado con `JWT_SECRET`, vida `JWT_ACCESS_EXPIRES_IN` (15 min). Claims: `sub` (userId), `role` (`ADMIN`|`CLIENT`), `type: "access"`.
- **Refresh token**: JWT firmado con `JWT_REFRESH_SECRET`, vida `JWT_REFRESH_EXPIRES_IN` (7 días), claim `jti`. Se guarda solo su hash SHA-256 en `refresh_tokens`. **Rotación** en cada `POST /auth/refresh`; si se presenta un refresh ya rotado/revocado se revocan todos los del usuario (detección de reutilización). `POST /auth/logout` revoca el refresh actual.
- **Almacenamiento en cliente**: ambos tokens en `flutter_secure_storage` (en Windows, Credential Manager). El `AuthInterceptor` añade `Authorization: Bearer`, y ante `401 TOKEN_EXPIRED` hace un único refresh serializado y reintenta.
- **Autorización por rol**: `requireRole('ADMIN')` en toda la administración y en `PATCH /orders/:id/status`; `requireRole('CLIENT')` en `POST /orders`.
- **Autorización por dueño**: en `order.service`, si `role === 'CLIENT'` toda consulta filtra por `userId = req.user.id`; acceder a un pedido ajeno devuelve `404 NOT_FOUND` (no revela existencia, US-13).
- El rol se lee del token y no se revalida en cada petición. Solo `POST /orders`, el login, el refresh y `GET /auth/me` comprueban que el usuario siga activo. Un usuario desactivado conserva acceso de lectura hasta que caduca el access token (15 min); ver el hallazgo S-07 de seguridad.

## 5. Configuración por entorno

Entornos: `development` (equipo del desarrollador / local), `test` (Vitest) y `production` (PC del local). PostgreSQL en todos; las credenciales viven en `backend/.env.local` (no versionado, nunca lo leen los agentes). Los scripts npm lo cargan con `dotenv-cli`. `src/config/env.js` valida todas las variables con Zod al arrancar y aborta con un mensaje que nombra la variable faltante (sin imprimir valores).

Variables que debe contener `backend/env.template` (la fase backend actualiza el archivo; aquí solo nombres y propósito, nunca valores reales):

| Variable                                                               | Obligatoria                         | Propósito / valor esperado                                                                                                                                                         |
| ---------------------------------------------------------------------- | ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `NODE_ENV`                                                             | sí                                  | `development` \| `test` \| `production`.                                                                                                                                           |
| `PORT`                                                                 | sí                                  | Puerto HTTP de la API (p. ej. 3000).                                                                                                                                               |
| `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_SCHEMA` | informativas                        | Componentes de la conexión; `DB_NAME=pizzeria`. Prisma no las usa directamente.                                                                                                    |
| `DATABASE_URL`                                                         | sí                                  | URL que consume Prisma: `postgresql://USUARIO:CONTRASENA@HOST:5432/pizzeria?schema=public`.                                                                                        |
| `JWT_SECRET`                                                           | sí                                  | Secreto del access token (aleatorio, ≥ 32 bytes).                                                                                                                                  |
| `JWT_REFRESH_SECRET`                                                   | sí                                  | Secreto del refresh token, distinto del anterior.                                                                                                                                  |
| `JWT_ACCESS_EXPIRES_IN`                                                | no (def. `15m`)                     | Vida del access token.                                                                                                                                                             |
| `JWT_REFRESH_EXPIRES_IN`                                               | no (def. `7d`)                      | Vida del refresh token.                                                                                                                                                            |
| `BCRYPT_COST`                                                          | no (def. `12`)                      | Coste de bcrypt (mínimo 12).                                                                                                                                                       |
| `CORS_ORIGINS`                                                         | no                                  | Lista blanca separada por comas. La app Windows (dio sobre `dart:io`) no envía `Origin`, por lo que las peticiones sin `Origin` se aceptan; la lista protege frente a navegadores. |
| `RATE_LIMIT_WINDOW_MS`                                                 | no (def. `900000`)                  | Ventana del limitador global.                                                                                                                                                      |
| `RATE_LIMIT_MAX`                                                       | no (def. `300`)                     | Peticiones por ventana e IP (global). La cotización en vivo consume cuota: el valor por defecto lo contempla.                                                                      |
| `AUTH_RATE_LIMIT_MAX`                                                  | no (def. `10`)                      | Intentos de login/registro/refresh por ventana e IP.                                                                                                                               |
| `LOG_LEVEL`                                                            | no (def. `info`)                    | Nivel de pino.                                                                                                                                                                     |
| `SEED_ADMIN_EMAIL`                                                     | no (def. `admin@goodpizza.local`)   | Email del administrador del seed.                                                                                                                                                  |
| `SEED_ADMIN_PASSWORD`                                                  | no                                  | Contraseña del admin del seed; si falta, el seed genera una aleatoria y la imprime una sola vez.                                                                                   |
| `SEED_CLIENT_EMAIL`                                                    | no (def. `cliente@goodpizza.local`) | Email del cliente del seed.                                                                                                                                                        |
| `SEED_CLIENT_PASSWORD`                                                 | no                                  | Contraseña del cliente del seed; misma regla.                                                                                                                                      |

Frontend: `API_URL` por `--dart-define` (por defecto `http://localhost:3000/api/v1`), leído con `String.fromEnvironment` en `lib/core/config/app_config.dart`. Sin secretos en el frontend.

Zona horaria: la fecha del número de orden y `orderDate` usan la zona horaria del proceso Node (la del sistema operativo del servidor, S-24). Las marcas de tiempo (`createdAt`, etc.) se guardan como `timestamptz` y se devuelven en ISO-8601 UTC.

## 6. Seguridad transversal (resumen)

helmet; cors con lista blanca; `express-rate-limit` (global + auth); `express.json({ limit: '100kb' })`; Zod en todo input (`strict()` para rechazar campos desconocidos); bcrypt; pino con `redact` de `req.headers.authorization`, `password`, `refreshToken`; errores 500 sin stack al cliente; Prisma parametrizado (las consultas `$queryRaw` usan plantillas etiquetadas, nunca concatenación). Revisión completa en la fase 7.

## 7. Pruebas (estrategia acordada con la arquitectura)

- **Unitarias (Vitest)** sobre `pricing-engine`, `utils/money`, formato de número de orden y validaciones: sin base de datos.
- **API (Vitest + Supertest)** sobre `app.js` con los servicios o el cliente Prisma sustituidos por dobles (`vi.mock`), para endpoints, códigos, formato de error y permisos por rol/dueño, **sin escribir en la base `pizzeria`**.
- **Integración con BD** (stock transaccional y concurrencia, secuencia diaria): solo si existe una base/esquema de pruebas separado (ver Preguntas abiertas, PA-01); en caso contrario se omiten con `describe.skipIf` y se reporta.
- **Flutter**: widget tests por pantalla y prueba de flujo "personalizar pizza → orden" con repositorios falsos.

## 8. Preguntas abiertas de arquitectura

Ver la lista consolidada en `entregable.md` §5 (PA-01..PA-06).
