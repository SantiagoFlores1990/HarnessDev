# Flujo — Fase 1: Requisitos

## Flujo de la fase (proceso)

```mermaid
flowchart TD
    A[Entrada: docs/prompt-proyecto.md] --> B[Extraer actores y reglas]
    B --> C[Redactar RF/RNF con MoSCoW]
    C --> D[Historias Given/When/Then]
    D --> E[Glosario y supuestos]
    E --> F{¿Ambigüedades sin resolver?}
    F -- Sí --> G[Registrar en Preguntas abiertas]
    G --> H
    F -- No --> H{¿Criterios cumplidos?}
    H -- Sí --> I[Salida: docs/01-requirements]
    H -- No --> C
```

## Flujo funcional del sistema (cliente: de la pizza a la orden)

```mermaid
sequenceDiagram
    actor U as Cliente
    participant F as Flutter App
    participant A as API Node
    participant D as PostgreSQL
    U->>F: Elige tamaño, masa, salsa, ingredientes y cantidades
    F-->>U: Calorías y precio en vivo
    U->>F: Agrega pizza al pedido y confirma
    F->>A: POST /api/v1/orders
    A->>D: Inicia transacción y lee ingredientes
    A->>A: Valida reglas, recalcula precio, calorías e IVA
    alt Stock suficiente
        A->>D: Descuenta stock y guarda pedido con snapshots
        D-->>A: Pedido GP-AAAAMMDD-0001 (Pendiente)
        A-->>F: 201 con orden
        F-->>U: Comprobante
    else Stock insuficiente
        A->>D: Rollback
        A-->>F: 409 con mensaje claro
        F-->>U: Error
    end
```

## Estados del pedido

```mermaid
stateDiagram-v2
    [*] --> Pendiente
    Pendiente --> EnPreparacion: Admin
    EnPreparacion --> Entregado: Admin
    Entregado --> [*]
```

## Descripción paso a paso

1. El cliente se registra e inicia sesión.
2. Elige una predefinida o arma una pizza; la app valida reglas y muestra calorías y precio en vivo.
3. Agrega una o varias pizzas con cantidad y revisa el resumen con IVA desglosado.
4. Confirma; el servidor revalida, descuenta stock en transacción, guarda snapshots y numera la orden.
5. El administrador avanza el estado; el cliente lo consulta en "Mis pedidos".
