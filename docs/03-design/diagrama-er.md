# Diagrama Entidad-Relación — Fase 3 (Diseño UX/UI)

- **Fuente de verdad:** `docs/02-architecture/data-model.md` (ER lógico y esquema Prisma propuesto). La fase de diseño **no modifica el modelo de datos**: **sin cambios** respecto a la fase 2. Este documento reproduce el ER para que cada pantalla se pueda trazar a sus entidades y añade el modelo de **estado de interfaz** (no persistido).

## 1. ER lógico (idéntico a la fase 2)

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

## 2. Trazabilidad pantalla → entidades

| Pantalla    | Entidades leídas / escritas (vía API)                                                                                                                          | Campos mostrados destacados                                                     |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| S-01 / S-02 | `USER`, `ROLE`, `REFRESH_TOKEN` (escritura)                                                                                                                    | `full_name`, `email`, rol                                                       |
| S-03        | `PRESET_PIZZA`, `PRESET_PIZZA_INGREDIENT`, `INGREDIENT`, `INGREDIENT_SIZE_VALUE`, `SIZE` (lectura)                                                             | receta, precio y calorías por tamaño (calculados), disponibilidad               |
| S-04        | `INGREDIENT` (+ `stock`), `INGREDIENT_CATEGORY`, `INGREDIENT_SIZE_VALUE`, `SIZE`, `PRESET_PIZZA_INGREDIENT`                                                    | `stock`, precio/calorías por porción del tamaño, categoría                      |
| S-05        | cotización (sin escritura); al confirmar: `ORDER`, `ORDER_PIZZA`, `ORDER_PIZZA_INGREDIENT`, `ORDER_STATUS_HISTORY`, `ORDER_DAILY_SEQUENCE`, `INGREDIENT.stock` | subtotales 15 % / 0 %, IVA, total, calorías                                     |
| S-06 / S-13 | `ORDER`, `ORDER_PIZZA`, `ORDER_PIZZA_INGREDIENT`, `ORDER_STATUS_HISTORY` (solo snapshots)                                                                      | `order_number`, `created_at`, `customer_*_snapshot`, `status`, totales          |
| S-07 / S-08 | `INGREDIENT`, `INGREDIENT_SIZE_VALUE`, `INGREDIENT_CATEGORY`, `VAT_RATE`, `SIZE`                                                                               | código, nombre, categoría, `active`, `stock`, IVA, precio y calorías por tamaño |
| S-09 / S-10 | `PRESET_PIZZA`, `PRESET_PIZZA_INGREDIENT`, `INGREDIENT`                                                                                                        | código, nombre, descripción, `sort_order`, receta                               |
| S-11 / S-12 | `ORDER` (todos), `ORDER_STATUS_HISTORY`, `USER` (cambió)                                                                                                       | cliente, estado, historial                                                      |

## 3. Estado de interfaz (no persistido, Riverpod)

Modelos en memoria del frontend; **no hay tablas nuevas**. Se envían al API como `PizzaItemInput` (`api-contract.md` §1.4).

```mermaid
erDiagram
    CART ||--o{ CART_LINE : "contiene"
    CART_LINE ||--o| PIZZA_BUILDER_STATE : "se crea desde"
    CART_LINE ||--o{ LINE_TOPPING : "ingredientes"
    CART_LINE }o--|| PRICED_PIZZA : "ultima cotizacion"

    CART {
        list lines "max 50"
        QuoteResult lastQuote "totals, valid, violations"
    }
    CART_LINE {
        enum type "PRESET | CUSTOM"
        string presetPizzaId "nullable"
        string sizeCode
        string doughId "solo CUSTOM"
        string sauceId "solo CUSTOM"
        int quantity "1..20"
    }
    LINE_TOPPING {
        string ingredientId
        int portions "1..3 (extras en PRESET)"
    }
    PIZZA_BUILDER_STATE {
        string sizeCode
        string presetPizzaId "nullable"
        string doughId
        string sauceId
        map toppingPortions "ingredientId a porciones"
        int quantity
        bool quoting
    }
    PRICED_PIZZA {
        string unitPrice "string decimal del API"
        int unitCalories
        list violations
    }
```

## 4. Diccionario de datos

Sin cambios: ver `docs/02-architecture/data-model.md` §2 (entidades), §4 (ERD) y §5 (esquema Prisma). Los tipos de la UI (strings decimales para dinero, enteros para calorías) siguen `api-contract.md` §1.

## 5. Reglas de integridad relevantes para la UI

- Un ingrediente tiene exactamente 3 valores por tamaño: el formulario S-08 exige los tres.
- Masa y salsa son ingredientes (`DOUGH`/`SAUCE`) con porción fija 1: S-04 no los ofrece como ingredientes adicionales.
- Los pedidos y su comprobante se leen solo de snapshots; la UI nunca recalcula un pedido existente.
- Sin borrado de ingredientes, predefinidas ni pedidos: la UI solo ofrece desactivar (S-07, S-09).

## 6. Cambios respecto a la fase anterior

Ninguno en el modelo de datos. Se añade únicamente el modelo de estado de interfaz de §3 (no persistido).
