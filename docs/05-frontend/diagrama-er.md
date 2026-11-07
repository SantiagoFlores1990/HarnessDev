# Diagrama Entidad-Relación — Fase 5 (Frontend)

El frontend **no tiene base de datos propia**: no guarda datos de negocio (los tokens van en `flutter_secure_storage` y el carrito vive en memoria). El ER físico es el de la base `pizzeria` y no cambia en esta fase: ver `docs/04-backend/diagrama-er.md` (igual a `backend/prisma/schema.prisma`).

Este documento muestra el **modelo de datos del cliente**: las clases inmutables de `frontend/lib/features/*/domain/` que representan los recursos del API y cómo se relacionan. Cada clase se construye con `fromJson` a partir de las respuestas del contrato (`api-contract.md` §1.4).

```mermaid
erDiagram
    SESSION ||--|| APP_USER : "usuario autenticado"
    APP_USER ||--o{ ORDER_SUMMARY : "cliente: solo los suyos"
    ORDER_SUMMARY ||--|| ORDER_DETAIL : "se amplia al abrir"
    ORDER_DETAIL ||--|{ PRICED_PIZZA : "pizzas (snapshot)"
    PRICED_PIZZA ||--|{ PRICED_COMPONENT : "masa, salsa, ingredientes"
    PRICED_PIZZA }o--o| PRESET_REF : "si es predefinida"
    ORDER_DETAIL ||--|| TOTALS : totals
    ORDER_DETAIL ||--|{ STATUS_HISTORY_ENTRY : statusHistory
    QUOTE_RESULT ||--|{ PRICED_PIZZA : items
    QUOTE_RESULT ||--|| TOTALS : totals
    QUOTE_RESULT ||--o{ VIOLATION : "violations (raiz)"
    PRICED_PIZZA ||--o{ VIOLATION : "violations (por item)"
    QUOTE_RESULT ||--o{ STOCK_NEED : stock
    CART ||--o{ CART_LINE : lines
    CART_LINE ||--|| PIZZA_ITEM_INPUT : "payload del API"
    PIZZA_ITEM_INPUT ||--o{ PORTION_INPUT : "toppings o extras"
    PRESET_PIZZA ||--|{ RECIPE_ITEM : recipe
    PRESET_PIZZA ||--|{ SIZE_PRICE : "pricesBySize (motor)"
    PRESET_PIZZA ||--o{ VIOLATION : unavailableReasons
    INGREDIENT }o--|| INGREDIENT_CATEGORY : category
    INGREDIENT }o--|| VAT_RATE : vatRate
    INGREDIENT ||--|{ SIZE_VALUE : "3 tamanos"
    SIZE_VALUE }o--|| SIZE_OPTION : sizeCode

    SESSION {
        AppUser user
    }
    APP_USER {
        string id PK
        string fullName
        string email
        UserRole role "ADMIN o CLIENT"
    }
    INGREDIENT {
        string id PK
        string code
        string name
        string categoryCode
        string vatRateCode
        string vatRatePercent "string decimal"
        bool active
        int stock
    }
    SIZE_VALUE {
        string sizeCode FK
        string price "string decimal 2 dec."
        int calories
    }
    SIZE_OPTION {
        string code PK "INDIVIDUAL MEDIUM FAMILY"
        string name
        int sortOrder
    }
    INGREDIENT_CATEGORY {
        string code PK
        string name
        int sortOrder
    }
    VAT_RATE {
        string code PK "VAT_15 VAT_0"
        string ratePercent
        bool isDefault
    }
    PRESET_PIZZA {
        string id PK
        string code
        string name
        string description
        bool active
        int sortOrder
        bool available
    }
    RECIPE_ITEM {
        string ingredientId FK
        string name
        string categoryCode
        int portions
        int stock
    }
    SIZE_PRICE {
        string sizeCode FK
        string price
        int calories
    }
    PIZZA_ITEM_INPUT {
        string type "CUSTOM o PRESET"
        string sizeCode
        string doughId
        string sauceId
        string presetPizzaId
        int quantity "1 a 20"
    }
    PORTION_INPUT {
        string ingredientId FK
        int portions "1 a 3"
    }
    CART {
        int pizzaCount
    }
    CART_LINE {
        string id "local"
        string presetName
    }
    QUOTE_RESULT {
        bool valid
    }
    PRICED_PIZZA {
        int index
        string type
        string sizeName
        int quantity
        string unitPrice
        int unitCalories
        string lineSubtotal
        int lineCalories
    }
    PRICED_COMPONENT {
        string ingredientId FK
        string name
        string component "DOUGH SAUCE TOPPING"
        int recipePortions
        int portions
        string lineAmount
        int lineCalories
    }
    PRESET_REF {
        string id
        string code
        string name
    }
    TOTALS {
        string subtotalVat15
        string subtotalVat0
        string vat15
        string total
        int totalCalories
    }
    VIOLATION {
        string code
        string message
        int itemIndex
        string ingredientId
    }
    STOCK_NEED {
        string ingredientId
        string name
        int required
        int available
    }
    ORDER_SUMMARY {
        string id PK
        string orderNumber "GP-AAAAMMDD-0001"
        datetime createdAt
        OrderStatus status
        int pizzaCount
        string total
    }
    ORDER_DETAIL {
        datetime statusChangedAt
    }
    STATUS_HISTORY_ENTRY {
        OrderStatus fromStatus
        OrderStatus toStatus
        datetime changedAt
        string changedByName
    }
```

## Diccionario de datos (clases del cliente)

| Entidad (clase Dart)                                                                                                                                                                      | Archivo                                   | Origen en el API                                                 | Notas                                                            |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------- | ---------------------------------------------------------------- | ---------------------------------------------------------------- |
| `AppUser`, `Session`, `UserRole`                                                                                                                                                          | `auth/domain/auth_models.dart`            | `/auth/login`, `/auth/register`, `/auth/me`                      | Solo en memoria; los tokens van en `TokenStorage`                |
| `SizeOption`, `IngredientCategory`, `VatRate`, `SizeValue`, `Ingredient`, `IngredientDraft`, `PageResult`                                                                                 | `catalog/domain/catalog_models.dart`      | `/sizes`, `/ingredient-categories`, `/vat-rates`, `/ingredients` | Los importes se conservan como `String` decimal (nunca `double`) |
| `PresetPizza`, `RecipeItem`, `SizePrice`, `PresetDraft`                                                                                                                                   | `preset_pizzas/domain/preset_models.dart` | `/preset-pizzas`                                                 | `pricesBySize` y `available` los calcula el servidor             |
| `PizzaItemInput`, `PortionInput`, `Violation`, `PricedPizza`, `PricedComponent`, `Totals`, `StockNeed`, `QuoteResult`, `OrderSummary`, `OrderDetail`, `StatusHistoryEntry`, `OrderStatus` | `orders/domain/order_models.dart`         | `/orders/quote`, `/orders`, `/orders/:id`                        | `OrderDetail` sale solo de snapshots                             |
| `BuilderState`                                                                                                                                                                            | `pizza_builder/domain/builder_state.dart` | (estado de UI)                                                   | Solo la selección; el precio es `QuoteResult`                    |
| `CartLine`, `CartState`                                                                                                                                                                   | `cart/domain/cart_state.dart`             | (estado de UI)                                                   | En memoria, no persistido; se vacía al confirmar o cerrar sesión |

## Reglas de integridad (del lado del cliente)

- Dinero siempre `String` con 2 decimales; solo se formatea (`$ 7.50`), nunca se suma ni se redondea en Dart.
- Límites de entrada (no reglas de negocio): porciones 1..3 y no más que el stock; cantidad de pizzas 1..20; en predefinidas, porciones ≥ las de la receta (solo agregar).
- Un ítem `PRESET` nunca envía masa, salsa ni receta; solo `extras` con las porciones **adicionales**.

## Cambios respecto a la fase anterior

- El ER físico (`backend/prisma/schema.prisma`) **no cambia**: sin cambios.
- Se agrega este modelo de datos del cliente.
