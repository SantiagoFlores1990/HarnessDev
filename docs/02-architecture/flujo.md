# Flujo — Fase 2: Arquitectura

## Flujo de la fase (proceso)

```mermaid
flowchart TD
    A["Entrada: prompt-proyecto.md + 01-requirements<br/>(RF, RNF, S-01..S-26, historias, glosario)"] --> B[Identificar componentes y restricciones fijas]
    B --> C[Diseñar capas backend y motor de cálculo único]
    C --> D[Modelo de datos lógico + esquema Prisma]
    D --> E[Contrato de API /api/v1]
    E --> F[Estructura frontend feature-first]
    F --> G[ADR de decisiones relevantes]
    G --> H{"¿Cada RF/RNF trazado a<br/>endpoint, entidad o regla?"}
    H -- No --> C
    H -- Sí --> I{"¿Contrato y ER coherentes<br/>(verificaciones VC-xx)?"}
    I -- No --> D
    I -- Sí --> J["Salida: architecture, data-model, api-contract,<br/>adr/, 6 entregables"]
```

## Flujos de pantalla (cliente y administrador)

```mermaid
flowchart LR
    L["/login — Iniciar sesión"] -->|Registrarme| R["/register — Registro"]
    R -->|201 + tokens| P
    L -->|login CLIENT| P["/presets — Pizzas predefinidas"]
    L -->|login ADMIN| AI["/admin/ingredients — Ingredientes"]

    subgraph Cliente
        P -->|Personalizar predefinida| B["/builder — Personalizar pizza"]
        P -->|Armar desde cero| B
        B -->|Agregar al pedido| CART["/cart — Resumen del pedido"]
        CART -->|Seguir agregando| P
        CART -->|Confirmar 201| REC["/orders/:id — Comprobante"]
        O["/orders — Mis pedidos"] --> REC
    end

    subgraph Administrador
        AI --> AIE["/admin/ingredients/:id — Editar ingrediente"]
        AP["/admin/presets — Predefinidas"] --> APE["/admin/presets/:id — Editar receta"]
        AO["/admin/orders — Pedidos"] --> AOD["/admin/orders/:id — Comprobante y avance de estado"]
    end
```

La navegación entre secciones de un mismo rol se hace con el `NavigationRail` (cliente: Predefinidas, Personalizar, Pedido, Mis pedidos; admin: Ingredientes, Predefinidas, Pedidos; ambos: Cerrar sesión).

## Flujo funcional del sistema: confirmar pedido

```mermaid
sequenceDiagram
    actor U as Cliente
    participant F as Flutter (CartPage)
    participant A as API (orders.controller)
    participant S as order.service
    participant E as pricing-engine
    participant D as PostgreSQL
    U->>F: Confirmar pedido
    F->>A: POST /api/v1/orders {items, expectedTotal}
    A->>A: requireAuth + requireRole(CLIENT) + validate(Zod)
    A->>S: create(userId, items, expectedTotal)
    S->>D: BEGIN
    S->>D: SELECT ingredientes implicados ORDER BY id FOR UPDATE
    S->>D: SELECT recetas y valores por tamaño
    S->>E: build + validate + calculate (catálogo bloqueado)
    E-->>S: QuoteResult
    alt violaciones de armado
        S->>D: ROLLBACK
        S-->>A: AppError 422 PIZZA_RULES_VIOLATED
    else stock insuficiente
        S->>D: ROLLBACK
        S-->>A: AppError 409 INSUFFICIENT_STOCK
    else total distinto de expectedTotal
        S->>D: ROLLBACK
        S-->>A: AppError 409 PRICE_CHANGED
    else válido
        S->>D: UPDATE stock = stock - n WHERE stock >= n (por ingrediente)
        S->>D: UPSERT order_daily_sequences RETURNING last_value
        S->>D: INSERT orders, order_pizzas, order_pizza_ingredients, order_status_history
        S->>D: COMMIT
        S-->>A: OrderDetail
    end
    A-->>F: 201 {data} o {error:{code,message,details}}
    F-->>U: Comprobante GP-AAAAMMDD-NNNN o mensaje de error
```

## Flujo funcional: cálculo en vivo

```mermaid
sequenceDiagram
    actor U as Cliente
    participant F as PizzaBuilderPage
    participant N as pizzaBuilderProvider
    participant A as POST /orders/quote
    U->>F: Cambia tamaño, masa, salsa o porciones
    F->>N: actualizar selección
    N->>N: debounce 150 ms y cancelar petición previa
    N->>A: {items:[pizza]}
    A-->>N: 200 {valid, violations, items, totals}
    N-->>F: precio, calorías y mensajes
    F-->>U: "Agregar al pedido" habilitado solo si valid
```

## Flujo funcional: avance de estado (admin)

```mermaid
stateDiagram-v2
    [*] --> PENDING: POST /orders (cliente)
    PENDING --> IN_PREPARATION: PATCH status (admin)
    IN_PREPARATION --> DELIVERED: PATCH status (admin)
    DELIVERED --> [*]
```

Sin cancelación ni retroceso (S-07, S-20). Cualquier otra transición responde `422 INVALID_STATUS_TRANSITION`; un cliente recibe `403 FORBIDDEN`.

## Descripción paso a paso

1. El arquitecto toma el prompt (fuente que manda) y los requisitos de la fase 1.
2. Define el monolito y las capas del backend; centraliza las reglas en el motor de cálculo (ADR-001, ADR-002).
3. Deriva el modelo lógico desde el ER conceptual, añade snapshots, secuencia diaria, historial de estados y tokens de refresco; produce el esquema Prisma.
4. Diseña el contrato `/api/v1` (25 endpoints) con errores uniformes y matriz de permisos.
5. Define la estructura feature-first del frontend, su estado (Riverpod) y su navegación (go_router).
6. Registra 11 ADR y verifica la trazabilidad RF/RNF ↔ endpoint/entidad/regla (`pruebas-unitarias.md`).
7. En ejecución: el cliente arma una pizza con cotización en vivo, la agrega al carrito, confirma (transacción con stock, numeración y snapshots) y ve el comprobante; el admin avanza el estado.
