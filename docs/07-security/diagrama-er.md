# Diagrama Entidad-Relación — Fase 7 (anotaciones de seguridad)

Esquema **sin cambios** respecto a la fase 4. La fuente de verdad es `backend/prisma/schema.prisma` y el diccionario completo está en `docs/04-backend/diagrama-er.md`. Aquí se repite el modelo físico con anotaciones de seguridad: datos sensibles, restricciones que protegen la integridad y comportamiento de borrado.

```mermaid
erDiagram
    ROLE ||--o{ USER : "asigna (Restrict)"
    USER ||--o{ REFRESH_TOKEN : "posee (Cascade)"
    USER ||--o{ ORDER : "realiza (Restrict)"
    USER ||--o{ ORDER_STATUS_HISTORY : "cambia (Restrict)"
    INGREDIENT_CATEGORY ||--o{ INGREDIENT : "clasifica (Restrict)"
    VAT_RATE ||--o{ INGREDIENT : "grava (Restrict)"
    INGREDIENT ||--o{ INGREDIENT_SIZE_VALUE : "valores (Cascade)"
    SIZE ||--o{ INGREDIENT_SIZE_VALUE : "por tamano (Restrict)"
    PRESET_PIZZA ||--o{ PRESET_PIZZA_INGREDIENT : "receta (Cascade)"
    INGREDIENT ||--o{ PRESET_PIZZA_INGREDIENT : "usado en (Restrict)"
    ORDER ||--|{ ORDER_PIZZA : "contiene (Cascade)"
    ORDER ||--|{ ORDER_STATUS_HISTORY : "historial (Cascade)"
    ORDER_PIZZA ||--|{ ORDER_PIZZA_INGREDIENT : "componentes (Cascade)"
    PRESET_PIZZA |o--o{ ORDER_PIZZA : "origen (SetNull)"
    SIZE ||--o{ ORDER_PIZZA : "tamano (Restrict)"
    INGREDIENT ||--o{ ORDER_PIZZA_INGREDIENT : "snapshot de (Restrict)"

    USER {
        uuid id PK "sub del JWT"
        string email UK "PII, minusculas"
        string full_name "PII"
        string password_hash "bcrypt coste>=12, nunca se expone"
        int role_id FK "solo el seed crea ADMIN"
        boolean active "se revisa en login, refresh, me y POST orders"
    }
    REFRESH_TOKEN {
        uuid id PK "= jti"
        uuid user_id FK
        string token_hash UK "SHA-256, nunca el token"
        timestamptz expires_at "7 dias"
        timestamptz revoked_at "rotacion y reutilizacion"
        uuid replaced_by_id "cadena de rotacion"
    }
    ROLE {
        int id PK
        string code UK "ADMIN o CLIENT"
    }
    INGREDIENT {
        uuid id PK
        string code UK
        int stock "CHECK stock >= 0 (antisobreventa)"
        boolean active "baja logica, sin DELETE"
    }
    INGREDIENT_SIZE_VALUE {
        decimal price "Decimal(10,2), CHECK >= 0"
        int calories "CHECK >= 0"
    }
    VAT_RATE {
        string code UK "VAT_15 o VAT_0, sin endpoint de escritura"
        decimal rate_percent "CHECK 0..100"
    }
    PRESET_PIZZA_INGREDIENT {
        int portions "CHECK 1..3"
    }
    ORDER {
        uuid id PK "no adivinable (UUID v4)"
        string order_number UK "GP-AAAAMMDD-NNNN"
        uuid user_id FK "filtro por dueno (IDOR)"
        string customer_email_snapshot "PII"
        decimal total "CHECK total = sub15 + sub0 + iva"
        enum status "solo avanza, solo ADMIN"
    }
    ORDER_STATUS_HISTORY {
        uuid changed_by_id FK "auditoria del cambio"
    }
    ORDER_PIZZA {
        int quantity "CHECK 1..20"
        decimal unit_price "snapshot Decimal(10,2)"
    }
    ORDER_PIZZA_INGREDIENT {
        int portions "CHECK 1..3"
        decimal vat_rate_percent "snapshot"
    }
    ORDER_DAILY_SEQUENCE {
        date order_date PK "upsert atomico en la transaccion"
        int last_value
    }
    SIZE {
        int id PK
        string code UK
    }
    INGREDIENT_CATEGORY {
        int id PK
        string code UK
    }
    PRESET_PIZZA {
        uuid id PK
        string code UK
        boolean active "baja logica"
    }
```

## Diccionario de datos (solo atributos relevantes para la seguridad)

| Entidad                 | Atributo                                            | Tipo          | Nulo | Restricciones           | Clasificación / control                                                                   |
| ----------------------- | --------------------------------------------------- | ------------- | ---- | ----------------------- | ----------------------------------------------------------------------------------------- |
| users                   | `email`                                             | varchar(254)  | No   | UNIQUE                  | PII. Se normaliza a minúsculas. Lo revela el 409 de registro (S-11)                       |
| users                   | `full_name`                                         | varchar(120)  | No   | —                       | PII                                                                                       |
| users                   | `password_hash`                                     | varchar(100)  | No   | —                       | Secreto. bcrypt, nunca sale de `auth.service`                                             |
| users                   | `active`                                            | boolean       | No   | def. true               | Bloquea login, refresh, `/auth/me` y `POST /orders`; no se revisa en cada petición (S-07) |
| refresh_tokens          | `token_hash`                                        | varchar(128)  | No   | UNIQUE                  | Secreto derivado (SHA-256). El token en claro solo lo tiene el cliente                    |
| refresh_tokens          | `revoked_at`                                        | timestamptz   | Sí   | —                       | Rotación y detección de reutilización                                                     |
| orders                  | `customer_name_snapshot`, `customer_email_snapshot` | varchar       | No   | —                       | PII congelada en el pedido. Solo la ven el dueño y el ADMIN                               |
| orders                  | `total` y subtotales                                | decimal(12,2) | No   | CHECK de consistencia   | Integridad del dinero                                                                     |
| ingredients             | `stock`                                             | int           | No   | CHECK `>= 0`            | Última defensa contra la sobreventa                                                       |
| order_pizzas            | `quantity`                                          | smallint      | No   | CHECK 1..20             | Límite de abuso en la BD                                                                  |
| order_pizza_ingredients | `portions`, `recipe_portions`                       | smallint      | No   | CHECK 1..3, 0..portions | Límite de abuso en la BD                                                                  |

## Reglas de integridad con impacto en seguridad

- **Borrado:** `Restrict` impide borrar usuarios con pedidos o historial, ingredientes usados en pedidos o recetas, y catálogos en uso. `Cascade` solo aplica a los hijos del propio agregado (líneas del pedido, valores por tamaño, receta) y a los refresh tokens del usuario. `SetNull` en `order_pizzas.preset_pizza_id`: el nombre queda en el snapshot.
- **No hay DELETE expuesto en la API** (baja lógica), así que las cascadas solo se activarían con SQL directo.
- **Snapshots inmutables:** ningún endpoint actualiza las líneas de un pedido. Solo cambian `status` y `status_changed_at`.
- **Esquema `test`:** mismas tablas en un esquema aparte. El aislamiento depende de controles en el código, no de privilegios (S-17).
- **Privilegios recomendados (no verificados):** rol de migraciones con DDL, rol de la app con solo DML sobre `public`, y rol de pruebas con acceso solo a `test`.

## Cambios respecto a la fase anterior

- Sin cambios de esquema. Solo se añaden anotaciones de seguridad.
