# Flujo — Fase 9 (consolidado del proyecto Good Pizza)

Este documento describe: (1) el proceso SDLC del proyecto con su estado real, (2) los flujos funcionales de cliente y administrador tal como están implementados, (3) el flujo de autenticación, (4) el flujo transaccional de confirmación de pedido, y (5) los flujos operativos de mantenimiento (salud, respaldo, migraciones y pruebas).

## 1. Proceso SDLC del proyecto

Orden de las fases según `docs/prompt-proyecto.md`: requisitos, arquitectura, diseño UX, backend, frontend, QA, seguridad y documentación final. La fase 8 (DevOps/Docker/CI) se omite por decisión del usuario.

```mermaid
flowchart TD
    F1["Fase 1 Requisitos<br/>Completada"] --> F2["Fase 2 Arquitectura<br/>Completada"]
    F2 --> F3["Fase 3 Diseño UX<br/>Completada"]
    F3 --> F4["Fase 4 Backend<br/>Completada; seed y pruebas BD pendientes del usuario"]
    F4 --> F5["Fase 5 Frontend Windows<br/>Completada; compila con ATL"]
    F5 --> F6["Fase 6 QA<br/>GO condicionado"]
    F6 --> F7["Fase 7 Seguridad<br/>GO condicionado"]
    F7 -.-> F8["Fase 8 DevOps Docker CI<br/>OMITIDA por decisión del usuario"]
    F7 --> F9["Fase 9 Mantenimiento y docs<br/>Completada en esta entrega"]
    F8 -.-> F9
    F9 --> PEND{"Condiciones antes de operar en el local"}
    PEND --> C1["C1: secretos JWT robustos o NODE_ENV production"]
    PEND --> C2["D-05: DATABASE_URL_TEST y 22 pruebas de integración"]
    PEND --> C3["Seed ejecutado en pizzeria"]
    PEND --> C4["flutter run -d windows contra la API real"]
    C1 --> GO["Uso en el local"]
    C2 --> GO
    C3 --> GO
    C4 --> GO
```

En cada fase se produjeron los seis entregables de la skill `phase-deliverables` en `docs/NN-*/`. La fase 8 no tiene entregables (solo `.gitkeep`).

## 2. Flujo funcional del cliente: de la pizza a la orden

Implementado en el frontend (`/presets`, `/builder`, `/cart`, `/orders`, `/orders/:id`) y en el backend (`/orders/quote`, `/orders`).

```mermaid
flowchart TD
    A(["Inicio de sesión como CLIENT"]) --> B{"Elegir origen"}
    B -- "Pizza predefinida" --> P["Pizzas predefinidas<br/>GET /preset-pizzas"]
    B -- "Armar desde cero" --> M["Personalizar pizza<br/>/builder"]
    P -- "Agregar al pedido" --> CART
    P -- "Personalizar" --> M2["/builder con presetId y size<br/>solo se agregan ingredientes"]
    M2 --> Q
    M --> M1["Elegir tamaño"]
    M1 --> M3["Elegir 1 masa y 1 salsa"]
    M3 --> M4["Marcar ingredientes y porciones 1 a 3<br/>límite por stock"]
    M4 --> Q["POST /orders/quote con debounce de 150 ms"]
    Q --> V{"valid y sin violaciones?"}
    V -- "No" --> ERR["Mensajes de violación<br/>Agregar deshabilitado"]
    ERR --> M4
    V -- "Si" --> ADD["Agregar al pedido<br/>Ctrl+Enter"]
    ADD --> CART["Resumen del pedido<br/>/cart"]
    CART --> TOT["POST /orders/quote con todas las líneas<br/>Subtotal 15, Subtotal 0, IVA 15, TOTAL"]
    TOT --> CONF{"Confirmar pedido<br/>diálogo de confirmación"}
    CONF -- "Cancelar" --> CART
    CONF -- "Confirmar" --> POST["POST /orders con expectedTotal"]
    POST --> RES{"Respuesta"}
    RES -- "201" --> DET["Comprobante /orders/:id<br/>estado Pendiente"]
    RES -- "409 INSUFFICIENT_STOCK" --> S1["Diálogo Stock insuficiente<br/>Ajustar pedido"]
    S1 --> CART
    RES -- "409 PRICE_CHANGED" --> S2["Diálogo El precio cambió<br/>Revisar o aceptar y confirmar"]
    S2 --> CART
    RES -- "422 PIZZA_RULES_VIOLATED" --> S3["Banner con violaciones por línea"]
    S3 --> CART
    DET --> MIS["Mis pedidos /orders<br/>Actualizar o F5 para ver cambios de estado"]
```

Reglas aplicadas en el motor del backend (no en la UI): exactamente 1 masa y 1 salsa; toppings de categorías queso, carne, vegetal u otros; máximo 3 porciones por ingrediente; mínimo 3 ingredientes distintos solo en pizzas personalizadas; cantidad por línea de 1 a 20; stock agregado suficiente. Los precios los calcula siempre el servidor.

## 3. Flujo funcional del administrador

Implementado en `/admin/ingredients`, `/admin/presets`, `/admin/orders`.

```mermaid
flowchart TD
    A(["Inicio de sesión como ADMIN"]) --> ING["Ingredientes<br/>GET /ingredients?includeInactive=true"]
    A --> PRE["Pizzas predefinidas<br/>GET /preset-pizzas?includeInactive=true"]
    A --> ORD["Pedidos<br/>GET /orders"]
    ING --> NI["Nuevo o editar ingrediente<br/>código, nombre, categoría, IVA 15 o 0,<br/>precio y kcal por tamaño"]
    NI --> SAVE1["POST o PUT /ingredients"]
    ING --> STK["Ajustar stock<br/>Fijar valor o Sumar o restar"]
    STK --> ST1["PATCH /ingredients/:id/stock<br/>no puede quedar negativo"]
    ING --> ACT["Activar o desactivar<br/>sin borrado"]
    ACT --> ST2["PATCH /ingredients/:id/status<br/>activar exige los 3 tamaños"]
    PRE --> NP["Nueva o editar predefinida<br/>código, nombre, receta"]
    NP --> PV["Vista previa de precio<br/>POST /orders/quote con 3 tamaños"]
    PV --> SAVE2["POST o PUT /preset-pizzas<br/>receta reemplazada en transacción"]
    PRE --> ACT2["Activar o desactivar<br/>PATCH /preset-pizzas/:id/status"]
    ORD --> DET["Detalle del pedido<br/>GET /orders/:id"]
    DET --> ESTADO{"Estado actual"}
    ESTADO -- "PENDING" --> E1["Pasar a En preparación<br/>confirmación"]
    ESTADO -- "IN_PREPARATION" --> E2["Marcar como Entregado<br/>confirmación"]
    ESTADO -- "DELIVERED" --> E3["Sin acciones: estado final"]
    E1 --> PATCH["PATCH /orders/:id/status"]
    E2 --> PATCH
    PATCH --> OK{"200 o 422 INVALID_STATUS_TRANSITION"}
    OK -- "Error de transición" --> UPD["Pedido ya cambió de estado<br/>Actualizar"]
```

Las transiciones solo avanzan: PENDING → IN_PREPARATION → DELIVERED. No hay retroceso, cancelación ni devolución de stock.

## 4. Flujo de autenticación y renovación de sesión

```mermaid
sequenceDiagram
    actor U as Usuario
    participant APP as App Windows
    participant API as API /api/v1
    participant DB as PostgreSQL
    participant SS as Almacenamiento seguro
    U->>APP: email y contraseña
    APP->>API: POST /auth/login
    API->>DB: busca usuario y compara bcrypt (hash de relleno si no existe)
    alt credenciales válidas y activo
        API->>DB: guarda hash SHA-256 del refresh (jti)
        API-->>APP: access JWT 15 min y refresh JWT 7 días
        APP->>SS: guarda ambos tokens
    else incorrectas
        API-->>APP: 401 INVALID_CREDENTIALS (mensaje genérico)
    else desactivado
        API-->>APP: 403 FORBIDDEN
    end
    Note over APP,API: peticiones con Authorization Bearer
    APP->>API: GET /ingredients (access caducado)
    API-->>APP: 401 TOKEN_EXPIRED
    APP->>API: POST /auth/refresh (un solo refresh serializado)
    API->>DB: revoca el refresh usado y crea uno nuevo (rotación atómica)
    alt refresh válido
        API-->>APP: nuevos tokens
        APP->>SS: reemplaza tokens y reintenta
    else refresh reutilizado, revocado o caducado
        API->>DB: si es reutilizado, revoca todos los refresh del usuario
        API-->>APP: 401 INVALID_REFRESH_TOKEN
        APP->>SS: borra tokens y pide iniciar sesión
    end
    U->>APP: Ctrl+Shift+Q (cerrar sesión)
    APP->>API: POST /auth/logout (refresh)
    API->>DB: revoca el refresh (idempotente)
    APP->>SS: borra tokens
```

Límite de peticiones: 10 intentos de login, registro o refresh cada 15 minutos por IP (valor por defecto); en un PC todos los usuarios comparten la IP (S-02).

## 5. Flujo transaccional de confirmación de pedido

Describe el camino crítico de integridad del stock y del número de orden (ADR-004 y ADR-005).

```mermaid
flowchart TD
    A["POST /orders: CLIENT, cuerpo validado con Zod"] --> B["Transacción Prisma"]
    B --> C["Cargar ingredientes referenciados<br/>SELECT FOR UPDATE ordenado por id"]
    C --> D["Motor de cálculo (puro)<br/>buildPizza, validatePizza, calculateOrder"]
    D --> E{"Violaciones de armado?"}
    E -- "Si" --> F422["422 PIZZA_RULES_VIOLATED"]
    E -- "No" --> G{"Stock agregado suficiente?"}
    G -- "No" --> F409["409 INSUFFICIENT_STOCK<br/>detalle por ingrediente"]
    G -- "Si" --> H{"expectedTotal enviado y distinto?"}
    H -- "Si" --> F409P["409 PRICE_CHANGED<br/>details con la cotización nueva"]
    H -- "No" --> I["UPDATE ingredients SET stock = stock - n<br/>WHERE stock >= n"]
    I --> J{"Filas afectadas = 1?"}
    J -- "No" --> R["Rollback y 409"]
    J -- "Si" --> K["Número GP-AAAAMMDD-NNNN<br/>upsert en order_daily_sequences"]
    K --> L["Insertar orders, order_pizzas,<br/>order_pizza_ingredients y historial inicial"]
    L --> M["Commit"]
    M --> N["201 Created + cabecera Location"]
    F422 --> RB["Rollback: nada se descuenta"]
    F409 --> RB
    F409P --> RB
    R --> RB
```

Notas: el orden de bloqueo es determinista para evitar interbloqueos. El `CHECK (stock >= 0)` es la última defensa. La concurrencia real con PostgreSQL está pendiente de verificación (pruebas de integración omitidas, backlog D-05).

## 6. Flujo operativo de mantenimiento

### 6.1 Arranque y comprobación

```mermaid
flowchart LR
    A["Arrancar PostgreSQL"] --> B["cd backend"]
    B --> C["npm start"]
    C --> D{"Configuración válida?"}
    D -- "No" --> E["Mensaje con nombres de variables<br/>revisar .env.local"]
    D -- "Si" --> F["GET /api/v1/health"]
    F -- "200 ok" --> G["Arrancar app Windows"]
    F -- "503 SERVICE_UNAVAILABLE" --> H["Revisar PostgreSQL y DATABASE_URL"]
```

### 6.2 Respaldo y restauración de prueba

```mermaid
flowchart TD
    A["pg_dump -Fc -n public -W"] --> B["Archivo .dump en carpeta restringida"]
    B --> C["pg_restore --list para verificar"]
    C --> D{"Restauración de prueba?"}
    D -- "Si" --> E["createdb pizzeria_restore_check<br/>pg_restore --no-owner"]
    E --> F["Comprobar tablas y conteos<br/>borrar la base de prueba"]
    D -- "No" --> G["Conservar copia"]
    H["Restauración real"] --> I{"Autorizada por el responsable?"}
    I -- "No" --> X["No hacer"]
    I -- "Si" --> J["Parar API, copia del estado actual,<br/>pg_restore --clean sobre public"]
```

### 6.3 Migraciones y esquema de pruebas

```mermaid
flowchart TD
    A["Cambio en schema.prisma"] --> B["Desarrollo: npm run db:migrate --name nombre"]
    B --> C["Revisar SQL generado"]
    C --> D["Probar en esquema test: npm run db:test:migrate"]
    D --> E["npm test con DATABASE_URL_TEST"]
    E --> F{"Verde?"}
    F -- "No" --> B
    F -- "Si" --> G["En el local: copia de seguridad y npm run db:deploy"]
    G --> H["Comprobar health"]
```

### 6.4 Pruebas

```mermaid
flowchart LR
    subgraph BE["Backend (backend/)"]
        B1["npm test<br/>267 pasan, 22 omitidas sin DATABASE_URL_TEST"]
        B2["npm run lint"]
    end
    subgraph FE["Frontend (frontend/)"]
        F1["flutter analyze"]
        F2["flutter test<br/>225 pasan"]
        F3["integration_test en Windows<br/>1 prueba"]
    end
    B1 --> R["Resultados en docs/06-qa/test-report.md"]
    B2 --> R
    F1 --> R
    F2 --> R
    F3 --> R
```

## 7. Flujo de incidencias

```mermaid
flowchart TD
    A["Incidencia reportada"] --> B{"La API responde a health?"}
    B -- "No" --> C["Revisar proceso, puerto y PostgreSQL<br/>runbook sec. 3 y 10"]
    B -- "Si, 503" --> D["Base de datos caída o URL incorrecta"]
    B -- "Si, 200" --> E{"Código de error de la respuesta"}
    E -- "500 INTERNAL_ERROR" --> F["Buscar Error no controlado en el log<br/>runbook sec. 9"]
    E -- "429 RATE_LIMITED" --> G["Esperar 15 min o reiniciar API<br/>backlog S-02"]
    E -- "401 TOKEN_EXPIRED o INVALID_REFRESH_TOKEN" --> H["Iniciar sesión de nuevo"]
    E -- "409 o 422" --> I["Regla de negocio: stock, precio o transición<br/>acción del usuario"]
    E -- "403 FORBIDDEN" --> J["Rol incorrecto o cuenta desactivada"]
    C --> K["Registrar incidente y solución"]
    D --> K
    F --> K
    G --> K
    H --> K
    I --> K
    J --> K
```

## 8. Estado de los flujos respecto al diseño

| Flujo                                   | Implementado                        | Verificado                                                        | Pendiente                          |
| --------------------------------------- | ----------------------------------- | ----------------------------------------------------------------- | ---------------------------------- |
| Registro, login, logout y renovación    | Sí                                  | Pruebas de API en proceso, pruebas de widget y del interceptor    | Prueba con backend real (G-12)     |
| Armado, cotización y confirmación       | Sí                                  | Motor en casos límite (20 001 subtotales), flujos HTTP en proceso | Concurrencia con PostgreSQL (D-05) |
| Snapshots de pedidos antiguos           | Sí                                  | En proceso con dobles de Prisma                                   | Prueba con BD real (D-05)          |
| Gestión de ingredientes y stock (admin) | Sí                                  | Pruebas de widget y de API                                        | Prueba manual con datos del seed   |
| Gestión de predefinidas (admin)         | Sí                                  | Pruebas de widget y de API                                        | Prueba manual con datos del seed   |
| Cambio de estado del pedido             | Sí                                  | Matriz de permisos y transiciones                                 | Prueba manual con datos del seed   |
| Respaldo y restauración                 | Procedimiento documentado (runbook) | No ejecutado                                                      | Automatización (backlog N-07)      |
