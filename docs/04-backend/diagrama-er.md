# Diagrama Entidad-Relación — Fase 4 (Backend, ER físico)

Es el modelo **realmente implementado** en `backend/prisma/schema.prisma` y aplicado a la base `pizzeria` (esquema `public`) con las migraciones de `backend/prisma/migrations/`. Coincide con el ER lógico de la fase 2 (`docs/02-architecture/data-model.md`): el esquema Prisma se implementó tal cual, sin ajustes.

```mermaid
erDiagram
    ROLE ||--o{ USER : "asigna"
    USER ||--o{ REFRESH_TOKEN : "posee"
    USER ||--o{ ORDER : "realiza"
    USER ||--o{ ORDER_STATUS_HISTORY : "cambia"
    INGREDIENT_CATEGORY ||--o{ INGREDIENT : "clasifica"
    VAT_RATE ||--o{ INGREDIENT : "grava"
    INGREDIENT ||--|{ INGREDIENT_SIZE_VALUE : "valores por tamaño"
    SIZE ||--o{ INGREDIENT_SIZE_VALUE : "de"
    PRESET_PIZZA ||--|{ PRESET_PIZZA_INGREDIENT : "receta"
    INGREDIENT ||--o{ PRESET_PIZZA_INGREDIENT : "usado en"
    ORDER ||--|{ ORDER_PIZZA : "contiene"
    ORDER ||--|{ ORDER_STATUS_HISTORY : "historial"
    ORDER_PIZZA ||--|{ ORDER_PIZZA_INGREDIENT : "compuesta por"
    INGREDIENT ||--o{ ORDER_PIZZA_INGREDIENT : "referenciado"
    SIZE ||--o{ ORDER_PIZZA : "tamaño"
    PRESET_PIZZA |o--o{ ORDER_PIZZA : "origen"

    ROLE {
        int id PK
        varchar code UK "ADMIN | CLIENT"
        varchar name
    }
    USER {
        uuid id PK
        varchar full_name
        varchar email UK
        varchar password_hash
        int role_id FK
        boolean active
        timestamptz created_at
        timestamptz updated_at
    }
    REFRESH_TOKEN {
        uuid id PK "jti"
        uuid user_id FK
        varchar token_hash UK
        timestamptz expires_at
        timestamptz revoked_at "nullable"
        uuid replaced_by_id "nullable"
        timestamptz created_at
    }
    SIZE {
        int id PK
        varchar code UK "INDIVIDUAL | MEDIUM | FAMILY"
        varchar name UK
        smallint sort_order UK
    }
    INGREDIENT_CATEGORY {
        int id PK
        varchar code UK "DOUGH | SAUCE | CHEESE | MEAT | VEGETABLE | OTHER"
        varchar name UK
        smallint sort_order
    }
    VAT_RATE {
        int id PK
        varchar code UK "VAT_15 | VAT_0"
        varchar name
        decimal rate_percent UK "5,2"
        boolean is_default
    }
    INGREDIENT {
        uuid id PK
        varchar code UK
        varchar name
        int category_id FK
        int vat_rate_id FK
        boolean active
        int stock "CHECK >= 0"
        timestamptz created_at
        timestamptz updated_at
    }
    INGREDIENT_SIZE_VALUE {
        uuid id PK
        uuid ingredient_id FK
        int size_id FK
        decimal price "10,2 CHECK >= 0"
        int calories "CHECK >= 0"
        timestamptz updated_at
    }
    PRESET_PIZZA {
        uuid id PK
        varchar code UK
        varchar name UK
        varchar description "nullable"
        boolean active
        int sort_order
        timestamptz created_at
        timestamptz updated_at
    }
    PRESET_PIZZA_INGREDIENT {
        uuid id PK
        uuid preset_pizza_id FK
        uuid ingredient_id FK
        smallint portions "CHECK 1..3"
    }
    ORDER {
        uuid id PK
        varchar order_number UK "GP-AAAAMMDD-NNNN"
        date order_date "zona horaria del servidor"
        uuid user_id FK
        varchar customer_name_snapshot
        varchar customer_email_snapshot
        enum status "PENDING | IN_PREPARATION | DELIVERED"
        decimal subtotal_vat15 "12,2"
        decimal subtotal_vat0 "12,2"
        decimal vat15_amount "12,2"
        decimal total "12,2"
        int total_calories
        timestamptz status_changed_at
        timestamptz created_at
        timestamptz updated_at
    }
    ORDER_DAILY_SEQUENCE {
        date order_date PK
        int last_value
        timestamptz updated_at
    }
    ORDER_STATUS_HISTORY {
        uuid id PK
        uuid order_id FK
        enum from_status "nullable"
        enum to_status
        uuid changed_by_id FK
        timestamptz changed_at
    }
    ORDER_PIZZA {
        uuid id PK
        uuid order_id FK
        smallint line_number
        enum kind "PRESET | CUSTOM"
        uuid preset_pizza_id FK "nullable"
        varchar preset_name_snapshot "nullable"
        int size_id FK
        varchar size_code_snapshot
        varchar size_name_snapshot
        smallint quantity "CHECK 1..20"
        decimal unit_price "10,2"
        int unit_calories
        decimal unit_subtotal_vat15 "10,2"
        decimal unit_subtotal_vat0 "10,2"
        decimal line_subtotal "12,2"
        int line_calories
    }
    ORDER_PIZZA_INGREDIENT {
        uuid id PK
        uuid order_pizza_id FK
        uuid ingredient_id FK
        enum component "DOUGH | SAUCE | TOPPING"
        varchar ingredient_code_snapshot
        varchar ingredient_name_snapshot
        varchar category_code_snapshot
        smallint recipe_portions "0..3"
        smallint portions "CHECK 1..3"
        decimal unit_price "10,2 snapshot"
        int unit_calories "snapshot"
        decimal vat_rate_percent "5,2 snapshot"
        decimal line_amount "10,2"
        int line_calories
    }
```

## Diccionario de datos (resumen físico)

Convenciones: tablas y columnas en `snake_case`; ids `uuid` en entidades de negocio e `int` autoincremental en catálogos; fechas `timestamptz(3)`; dinero `numeric` (nunca `Float`); calorías `int`.

| Tabla                      | Columnas clave                                                                                                                                                                                                                                                      | Restricciones                                                                                                                                                                               |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `roles`                    | `id`, `code` (ADMIN/CLIENT), `name`                                                                                                                                                                                                                                 | `code` único                                                                                                                                                                                |
| `users`                    | `id`, `full_name`, `email`, `password_hash`, `role_id`, `active`                                                                                                                                                                                                    | `email` único (minúsculas); FK `role_id` Restrict; índice `role_id`                                                                                                                         |
| `refresh_tokens`           | `id` (= jti), `user_id`, `token_hash` (SHA-256), `expires_at`, `revoked_at`, `replaced_by_id`                                                                                                                                                                       | `token_hash` único; FK `user_id` Cascade; índices `user_id`, `expires_at`                                                                                                                   |
| `sizes`                    | `id`, `code`, `name`, `sort_order`                                                                                                                                                                                                                                  | `code`, `name`, `sort_order` únicos                                                                                                                                                         |
| `ingredient_categories`    | `id`, `code`, `name`, `sort_order`                                                                                                                                                                                                                                  | `code`, `name` únicos                                                                                                                                                                       |
| `vat_rates`                | `id`, `code`, `name`, `rate_percent numeric(5,2)`, `is_default`                                                                                                                                                                                                     | `code`, `rate_percent` únicos; CHECK `0..100`                                                                                                                                               |
| `ingredients`              | `id`, `code`, `name`, `category_id`, `vat_rate_id`, `active`, `stock`                                                                                                                                                                                               | `code` único; CHECK `stock >= 0`; FK Restrict; índices `category_id`, `vat_rate_id`, `(active, category_id)`                                                                                |
| `ingredient_size_values`   | `id`, `ingredient_id`, `size_id`, `price numeric(10,2)`, `calories`                                                                                                                                                                                                 | único `(ingredient_id, size_id)`; CHECK `price >= 0`, `calories >= 0`; FK ingrediente Cascade, tamaño Restrict                                                                              |
| `preset_pizzas`            | `id`, `code`, `name`, `description`, `active`, `sort_order`                                                                                                                                                                                                         | `code` y `name` únicos; índice `(active, sort_order)`; sin precio propio                                                                                                                    |
| `preset_pizza_ingredients` | `id`, `preset_pizza_id`, `ingredient_id`, `portions`                                                                                                                                                                                                                | único `(preset_pizza_id, ingredient_id)`; CHECK `portions 1..3`; FK receta Cascade, ingrediente Restrict                                                                                    |
| `orders`                   | `id`, `order_number`, `order_date date`, `user_id`, `customer_name_snapshot`, `customer_email_snapshot`, `status`, `subtotal_vat15`, `subtotal_vat0`, `vat15_amount`, `total` (`numeric(12,2)`), `total_calories`, `status_changed_at`                              | `order_number` único; CHECK `total = subtotal_vat15 + subtotal_vat0 + vat15_amount`; FK `user_id` Restrict; índices `(user_id, created_at desc)`, `(status, created_at desc)`, `order_date` |
| `order_daily_sequences`    | `order_date` (PK), `last_value`                                                                                                                                                                                                                                     | Una fila por fecha de negocio; upsert atómico                                                                                                                                               |
| `order_status_history`     | `id`, `order_id`, `from_status` (nullable), `to_status`, `changed_by_id`, `changed_at`                                                                                                                                                                              | FK pedido Cascade, usuario Restrict; índices `(order_id, changed_at)`, `changed_by_id`                                                                                                      |
| `order_pizzas`             | `id`, `order_id`, `line_number`, `kind`, `preset_pizza_id`, `preset_name_snapshot`, `size_id`, `size_code_snapshot`, `size_name_snapshot`, `quantity`, `unit_price`, `unit_calories`, `unit_subtotal_vat15`, `unit_subtotal_vat0`, `line_subtotal`, `line_calories` | único `(order_id, line_number)`; CHECK `quantity 1..20`; FK predefinida SetNull, tamaño Restrict                                                                                            |
| `order_pizza_ingredients`  | `id`, `order_pizza_id`, `ingredient_id`, `component`, `ingredient_code_snapshot`, `ingredient_name_snapshot`, `category_code_snapshot`, `recipe_portions`, `portions`, `unit_price`, `unit_calories`, `vat_rate_percent`, `line_amount`, `line_calories`            | único `(order_pizza_id, ingredient_id)`; CHECK `portions 1..3` y `recipe_portions 0..portions`; FK pizza Cascade, ingrediente Restrict                                                      |

Enums PostgreSQL: `order_status` (`PENDING`, `IN_PREPARATION`, `DELIVERED`), `pizza_kind` (`PRESET`, `CUSTOM`), `pizza_component` (`DOUGH`, `SAUCE`, `TOPPING`).

## Restricciones CHECK (migración `20261106190500_add_check_constraints`)

`ingredients_stock_nonneg`, `isv_price_nonneg`, `isv_calories_nonneg`, `vat_rates_percent_range`, `ppi_portions_range`, `order_pizzas_quantity_range`, `opi_portions_range`, `opi_recipe_portions_range`, `orders_total_consistent`. Verificadas en el esquema `public` (9 de 9) y en el esquema `test` (prueba de integración).

## Reglas de integridad

- Dinero siempre `Decimal`; en JSON viaja como string con 2 decimales.
- Snapshots: `orders`, `order_pizzas` y `order_pizza_ingredients` guardan nombres, códigos, precios, calorías y tarifa de IVA; el detalle del pedido se construye solo con ellos (salvo `presetPizza.code`, ver preguntas abiertas del entregable).
- Sin borrado de ingredientes ni predefinidas (baja lógica con `active`); FK desde pedidos `Restrict`.
- El servicio garantiza lo que el esquema no modela: 3 valores de tamaño por ingrediente, receta con 1 masa y 1 salsa, 1 masa y 1 salsa por pizza del pedido, transiciones de estado válidas.

## Cambios respecto a la fase anterior

- Sin cambios en el modelo: el esquema Prisma coincide con `data-model.md` §5.
- Los CHECK se añadieron en una segunda migración (la inicial ya estaba aplicada); resultado equivalente en BD.
