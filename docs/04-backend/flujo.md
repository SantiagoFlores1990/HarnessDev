# Flujo — Fase 4: Backend

## Flujo de la fase (proceso)

```mermaid
flowchart TD
    A[Entrada: contrato, data-model, ADR 001-011] --> B[Esquema Prisma + migración init]
    B --> C[Migración de CHECK y aplicar con db:migrate]
    C --> D[Motor puro pricing-engine]
    D --> E[Servicios, controladores, rutas, middlewares]
    E --> F[Seed de datos de ejemplo]
    F --> G[Pruebas: unit, servicios, API, integración en esquema test]
    G --> H{npm test y npm run lint en verde?}
    H -- No --> E
    H -- Sí --> I[Documentación y 6 entregables]
```

## Flujo funcional: capas y errores

```mermaid
flowchart LR
    REQ[HTTP] --> SEC[helmet, cors, pino, rate limit, json 100 KB]
    SEC --> RT[routes]
    RT --> AU[requireAuth y requireRole]
    AU --> VA[validate Zod strict]
    VA --> CT[controllers]
    CT --> SV[services]
    SV --> EN[pricing-engine puro]
    SV --> PR[(Prisma / PostgreSQL)]
    SV -. AppError .-> EH[errorHandler]
    VA -. ZodError .-> EH
    EH --> OUT["{error:{code,message,details}}"]
```

## Flujo funcional: cotización y confirmación de pedido

```mermaid
sequenceDiagram
    actor C as Cliente
    participant API as API Node
    participant E as pricing-engine
    participant D as PostgreSQL
    C->>API: POST /orders/quote (items)
    API->>D: carga ingredientes, recetas y tamaños (sin bloquear)
    API->>E: quoteOrder
    E-->>API: valid, violations, items, totals, stock
    API-->>C: 200 (cálculo en vivo)
    C->>API: POST /orders (items, expectedTotal?)
    API->>D: BEGIN
    API->>D: SELECT id FROM ingredients WHERE id = ANY(...) ORDER BY id FOR UPDATE
    API->>D: lee ingredientes y recetas bloqueados
    API->>E: quoteOrder con valores bloqueados
    alt reglas de armado incumplidas
        API->>D: ROLLBACK
        API-->>C: 422 PIZZA_RULES_VIOLATED
    else stock insuficiente
        API->>D: ROLLBACK
        API-->>C: 409 INSUFFICIENT_STOCK (solicitado vs disponible)
    else total distinto de expectedTotal
        API->>D: ROLLBACK
        API-->>C: 409 PRICE_CHANGED (nueva cotización)
    else válido
        API->>D: UPDATE ingredients SET stock = stock - n WHERE id AND stock >= n (por id)
        API->>D: upsert order_daily_sequences RETURNING last_value
        API->>D: INSERT order + pizzas + componentes (snapshots) + historial
        API->>D: COMMIT
        API-->>C: 201 OrderDetail (Location)
    end
```

## Flujo funcional: autenticación con refresh rotativo

```mermaid
sequenceDiagram
    actor U as Usuario
    participant API as API Node
    participant D as PostgreSQL
    U->>API: POST /auth/login
    API->>D: busca usuario, bcrypt.compare
    API->>D: guarda SHA-256 del refresh token
    API-->>U: access 15 min + refresh 7 días
    U->>API: POST /auth/refresh (refresh)
    API->>D: token vigente y no revocado?
    alt vigente
        API->>D: revoca el actual y crea el nuevo (transacción)
        API-->>U: nuevo par de tokens
    else ya rotado o revocado
        API->>D: revoca TODOS los del usuario
        API-->>U: 401 INVALID_REFRESH_TOKEN
    end
```

## Flujo funcional: estados del pedido

```mermaid
stateDiagram-v2
    [*] --> PENDING: POST /orders (CLIENT)
    PENDING --> IN_PREPARATION: PATCH status (ADMIN)
    IN_PREPARATION --> DELIVERED: PATCH status (ADMIN)
    DELIVERED --> [*]
```

## Descripción paso a paso

1. El cliente consulta catálogo y predefinidas (con precio por tamaño calculado por el motor y `available`).
2. Mientras arma la pizza, el frontend llama a `/orders/quote`; el servidor devuelve precio, calorías, IVA y violaciones sin escribir nada.
3. Al confirmar, `POST /orders` repite el cálculo dentro de una transacción con los ingredientes bloqueados, descuenta stock, asigna el número del día y guarda snapshots; ante cualquier fallo no queda ningún cambio.
4. El cliente solo consulta sus pedidos (el ajeno responde 404). El administrador cambia el estado en orden y cada cambio queda en `order_status_history`.
5. Cambiar precios o stock después no altera pedidos existentes: el detalle sale únicamente de los snapshots.
