# Contrato de API — Good Pizza (`/api/v1`)

- **Fase:** 2 (Arquitectura) · **Versión:** 1.0 · **Fecha:** 2026-11-06
- **Fuente de verdad** para `backend-dev` y `flutter-dev`: ninguno se desvía de este documento sin actualizarlo antes.
- **Base URL:** `http://<host>:<PORT>/api/v1` (desarrollo: `http://localhost:3000/api/v1`).

## 1. Convenciones generales

| Tema              | Regla                                                                                                                                                                                                                       |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Formato           | JSON UTF-8. `Content-Type: application/json`. Body máximo 100 KB.                                                                                                                                                           |
| Autenticación     | `Authorization: Bearer <accessToken>` salvo en rutas marcadas "Pública".                                                                                                                                                    |
| Roles             | `ADMIN`, `CLIENT`. "Auth" = cualquier rol autenticado.                                                                                                                                                                      |
| Respuesta exitosa | Objeto: `{ "data": { ... } }`. Lista paginada: `{ "data": [ ... ], "page": 1, "pageSize": 20, "total": 57 }`. Lista no paginada: `{ "data": [ ... ] }`.                                                                     |
| Dinero            | **String decimal con 2 decimales** en USD, sin IVA salvo `vat15` y `total`: `"7.50"`. Nunca número flotante. En requests de admin se acepta string `"1.50"` o número con ≤ 2 decimales; el servidor lo normaliza a Decimal. |
| Tarifa IVA        | String `"15.00"` / `"0.00"`.                                                                                                                                                                                                |
| Calorías          | Entero (kcal).                                                                                                                                                                                                              |
| Fechas            | Marcas de tiempo ISO-8601 UTC (`"2026-11-06T15:04:05.123Z"`). `orderDate` = `"YYYY-MM-DD"` en la zona horaria del servidor.                                                                                                 |
| Ids               | UUID v4 (string) para usuarios, ingredientes, predefinidas, pedidos. Catálogos se referencian por `code`.                                                                                                                   |
| Paginación        | `?page=1&pageSize=20` (pageSize máx. 100).                                                                                                                                                                                  |
| Validación        | Zod `strict()`: campos desconocidos → 400.                                                                                                                                                                                  |
| Códigos de tamaño | `INDIVIDUAL`, `MEDIUM`, `FAMILY`.                                                                                                                                                                                           |
| Categorías        | `DOUGH`, `SAUCE`, `CHEESE`, `MEAT`, `VEGETABLE`, `OTHER`.                                                                                                                                                                   |
| Tarifas IVA       | `VAT_15`, `VAT_0`.                                                                                                                                                                                                          |
| Estados           | `PENDING` (Pendiente), `IN_PREPARATION` (En preparación), `DELIVERED` (Entregado). Las etiquetas en español las pone la UI.                                                                                                 |

### 1.1 Formato de error uniforme

```json
{
  "error": {
    "code": "INSUFFICIENT_STOCK",
    "message": "No hay stock suficiente de Queso mozzarella: solicitado 6, disponible 4.",
    "details": [
      {
        "ingredientId": "8f1c…",
        "code": "QUE-MOZ",
        "name": "Queso mozzarella",
        "requested": 6,
        "available": 4
      }
    ]
  }
}
```

- `code`: constante en inglés (tabla 1.2). El frontend decide por `code`, no por `message`.
- `message`: texto en español apto para mostrar al usuario.
- `details`: arreglo (puede estar vacío). Para `VALIDATION_ERROR`: `[{ "path": "items.0.quantity", "message": "..." }]`. Para reglas de negocio: objetos de violación (§1.3).

### 1.2 Catálogo de códigos de error

| HTTP | code                                        | Cuándo                                                                                                                                  |
| ---- | ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| 400  | `VALIDATION_ERROR`                          | Body/query/params no cumplen el esquema Zod (tipos, rangos 1..3 porciones, 1..20 cantidad, email, contraseña < 8, campos desconocidos). |
| 401  | `UNAUTHENTICATED`                           | Falta token o es inválido.                                                                                                              |
| 401  | `TOKEN_EXPIRED`                             | Access token caducado (el cliente debe usar `/auth/refresh`).                                                                           |
| 401  | `INVALID_CREDENTIALS`                       | Login fallido (mensaje genérico).                                                                                                       |
| 401  | `INVALID_REFRESH_TOKEN`                     | Refresh inválido, caducado, revocado o reutilizado.                                                                                     |
| 403  | `FORBIDDEN`                                 | Rol sin permiso o usuario desactivado.                                                                                                  |
| 404  | `NOT_FOUND`                                 | Recurso inexistente **o** pedido de otro cliente.                                                                                       |
| 404  | `ROUTE_NOT_FOUND`                           | Ruta o método no definido (p. ej. `DELETE /ingredients/:id`).                                                                           |
| 409  | `EMAIL_ALREADY_EXISTS`                      | Registro con email existente.                                                                                                           |
| 409  | `INGREDIENT_CODE_EXISTS`                    | Código de ingrediente duplicado.                                                                                                        |
| 409  | `PRESET_CODE_EXISTS` / `PRESET_NAME_EXISTS` | Predefinida duplicada.                                                                                                                  |
| 409  | `INSUFFICIENT_STOCK`                        | Stock insuficiente al confirmar (estado concurrente).                                                                                   |
| 409  | `PRICE_CHANGED`                             | `expectedTotal` enviado no coincide con el total recalculado. `details` = cotización nueva.                                             |
| 422  | `PIZZA_RULES_VIOLATED`                      | Una o más reglas de armado fallan al confirmar; `details` = violaciones (§1.3).                                                         |
| 422  | `MISSING_SIZE_VALUES`                       | Ingrediente sin valores para los 3 tamaños.                                                                                             |
| 422  | `INVALID_RECIPE`                            | Receta de predefinida inválida (masa/salsa ≠ 1, categoría no permitida, porciones > 3, ingrediente repetido). `details` = violaciones.  |
| 422  | `INGREDIENT_CATEGORY_LOCKED`                | Cambio de categoría de un ingrediente usado en recetas que rompería la receta.                                                          |
| 422  | `INVALID_STATUS_TRANSITION`                 | Salto o retroceso de estado.                                                                                                            |
| 422  | `INVALID_VAT_RATE`                          | `vatRateCode` no existe.                                                                                                                |
| 422  | `STOCK_WOULD_BE_NEGATIVE`                   | Ajuste de stock (`ADD`) que dejaría el stock por debajo de 0.                                                                           |
| 429  | `RATE_LIMITED`                              | Límite de peticiones superado.                                                                                                          |
| 500  | `INTERNAL_ERROR`                            | Error inesperado (sin stack).                                                                                                           |
| 503  | `SERVICE_UNAVAILABLE`                       | Solo `/health`: la base de datos no responde.                                                                                           |

### 1.3 Objeto de violación de reglas de armado

Usado en `details` de `PIZZA_RULES_VIOLATED` / `INVALID_RECIPE` y en `violations` de `/orders/quote`:

```json
{
  "code": "MAX_PORTIONS_EXCEEDED",
  "message": "Máximo 3 porciones por ingrediente (Queso mozzarella: 4).",
  "itemIndex": 0,
  "ingredientId": "8f1c…",
  "meta": { "max": 3, "requested": 4 }
}
```

| code de violación                      | Mensaje base (es)                                                 | Aplica                  |
| -------------------------------------- | ----------------------------------------------------------------- | ----------------------- |
| `DOUGH_REQUIRED`                       | "Elige una masa."                                                 | todas                   |
| `SAUCE_REQUIRED`                       | "Elige una salsa base."                                           | todas                   |
| `INVALID_DOUGH` / `INVALID_SAUCE`      | "El ingrediente elegido no es una masa/salsa."                    | CUSTOM                  |
| `INGREDIENT_CATEGORY_NOT_ALLOWED`      | "La masa y la salsa no se agregan como ingredientes adicionales." | toppings/extras         |
| `DUPLICATE_INGREDIENT`                 | "Un ingrediente aparece repetido; usa la cantidad."               | toppings/extras/receta  |
| `MAX_PORTIONS_EXCEEDED`                | "Máximo 3 porciones por ingrediente."                             | todas (receta + extras) |
| `MIN_TOPPINGS_NOT_MET`                 | "Elige al menos 3 ingredientes distintos."                        | solo CUSTOM (S-17)      |
| `INGREDIENT_NOT_FOUND`                 | "Ingrediente inexistente."                                        | todas                   |
| `INGREDIENT_INACTIVE`                  | "El ingrediente X no está disponible."                            | todas                   |
| `MISSING_SIZE_VALUES`                  | "El ingrediente X no tiene precio para el tamaño elegido."        | todas                   |
| `PRESET_NOT_FOUND` / `PRESET_INACTIVE` | "La pizza predefinida no existe / no está disponible."            | PRESET                  |
| `PRESET_UNAVAILABLE`                   | "La pizza X no está disponible: falta Y."                         | PRESET (S-25)           |
| `INSUFFICIENT_STOCK`                   | "No hay stock suficiente de X: solicitado N, disponible M."       | agregado del pedido     |

### 1.4 Modelos compartidos

**PizzaItemInput** (request de `/orders/quote` y `/orders`):

```json
// Pizza armada desde cero
{
  "type": "CUSTOM",
  "sizeCode": "MEDIUM",
  "doughId": "uuid",
  "sauceId": "uuid",
  "toppings": [ { "ingredientId": "uuid", "portions": 3 }, { "ingredientId": "uuid", "portions": 1 } ],
  "quantity": 1
}
// Predefinida (con o sin extras)
{
  "type": "PRESET",
  "presetPizzaId": "uuid",
  "sizeCode": "FAMILY",
  "extras": [ { "ingredientId": "uuid", "portions": 1 } ],
  "quantity": 2
}
```

Reglas de esquema (400): `type` ∈ {CUSTOM, PRESET}; `sizeCode` válido; `quantity` entero 1..20; `portions` entero 1..3; `toppings` 0..30 elementos; `extras` 0..30; `items` 1..50 elementos. En PRESET no se envían masa/salsa/receta: las toma el servidor de la receta vigente; `extras[].portions` son porciones **adicionales** a la receta (solo agregar, RF-14). `doughId`/`sauceId` son opcionales en el esquema para permitir el cálculo parcial en vivo: en quote su ausencia se informa como violación y en `POST /orders` produce 422.

**PricedPizza** (respuesta):

```json
{
  "index": 0,
  "type": "CUSTOM",
  "presetPizza": null,
  "size": { "code": "MEDIUM", "name": "Mediana" },
  "quantity": 1,
  "components": [
    {
      "ingredientId": "uuid",
      "code": "MAS-TRA",
      "name": "Masa tradicional",
      "component": "DOUGH",
      "categoryCode": "DOUGH",
      "recipePortions": 0,
      "portions": 1,
      "unitPrice": "2.00",
      "unitCalories": 300,
      "vatRatePercent": "15.00",
      "lineAmount": "2.00",
      "lineCalories": 300
    },
    {
      "ingredientId": "uuid",
      "code": "SAL-TOM",
      "name": "Salsa de tomate",
      "component": "SAUCE",
      "categoryCode": "SAUCE",
      "recipePortions": 0,
      "portions": 1,
      "unitPrice": "1.00",
      "unitCalories": 60,
      "vatRatePercent": "0.00",
      "lineAmount": "1.00",
      "lineCalories": 60
    },
    {
      "ingredientId": "uuid",
      "code": "QUE-MOZ",
      "name": "Queso mozzarella",
      "component": "TOPPING",
      "categoryCode": "CHEESE",
      "recipePortions": 0,
      "portions": 3,
      "unitPrice": "1.50",
      "unitCalories": 110,
      "vatRatePercent": "15.00",
      "lineAmount": "4.50",
      "lineCalories": 330
    }
  ],
  "unitPrice": "7.50",
  "unitCalories": 690,
  "unitSubtotalVat15": "6.50",
  "unitSubtotalVat0": "1.00",
  "lineSubtotal": "7.50",
  "lineCalories": 690,
  "valid": false,
  "violations": [
    {
      "code": "MIN_TOPPINGS_NOT_MET",
      "message": "Elige al menos 3 ingredientes distintos.",
      "itemIndex": 0,
      "ingredientId": null,
      "meta": { "min": 3, "current": 1 }
    }
  ]
}
```

`presetPizza` es `null` en CUSTOM o `{ "id": "uuid", "code": "MARGHERITA", "name": "Margarita" }` en PRESET.

**Totals**:

```json
{
  "subtotalVat15": "6.50",
  "subtotalVat0": "1.00",
  "vat15": "0.98",
  "total": "8.48",
  "totalCalories": 690
}
```

`vat15 = round_half_up(subtotalVat15 × 0.15, 2)` (6.50 × 0.15 = 0.975 → 0.98). `total = subtotalVat15 + subtotalVat0 + vat15`.

**OrderSummary**:

```json
{
  "id": "uuid",
  "orderNumber": "GP-20261106-0001",
  "orderDate": "2026-11-06",
  "createdAt": "2026-11-06T15:04:05.123Z",
  "status": "PENDING",
  "customer": {
    "id": "uuid",
    "fullName": "Ana Pérez",
    "email": "ana@ejemplo.com"
  },
  "pizzaCount": 3,
  "totalCalories": 2070,
  "total": "25.44"
}
```

`customer` sale de los snapshots del pedido; `pizzaCount` = Σ cantidades de las líneas.

**OrderDetail** (comprobante, RF-24) = `OrderSummary` + `statusChangedAt` + `pizzas` (lista de PricedPizza sin `valid`/`violations` y con `lineNumber` en lugar de `index`) + `totals` (Totals) + `statusHistory`:

```json
{
  "statusChangedAt": "2026-11-06T15:04:05.123Z",
  "pizzas": [
    {
      "lineNumber": 1,
      "type": "PRESET",
      "presetPizza": {
        "id": "uuid",
        "code": "MARGHERITA",
        "name": "Margarita"
      },
      "size": { "code": "MEDIUM", "name": "Mediana" },
      "quantity": 2,
      "components": [],
      "unitPrice": "9.50",
      "unitCalories": 820,
      "unitSubtotalVat15": "7.70",
      "unitSubtotalVat0": "1.80",
      "lineSubtotal": "19.00",
      "lineCalories": 1640
    }
  ],
  "totals": {
    "subtotalVat15": "15.40",
    "subtotalVat0": "3.60",
    "vat15": "2.31",
    "total": "21.31",
    "totalCalories": 1640
  },
  "statusHistory": [
    {
      "fromStatus": null,
      "toStatus": "PENDING",
      "changedAt": "…",
      "changedBy": { "id": "uuid", "fullName": "…" }
    }
  ]
}
```

Todos los importes de `OrderDetail` salen de los snapshots, nunca del catálogo vigente (RF-19).

**Ingredient** (vista admin; la vista cliente omite `createdAt`/`updatedAt`):

```json
{
  "id": "uuid",
  "code": "QUE-MOZ",
  "name": "Queso mozzarella",
  "category": { "code": "CHEESE", "name": "Queso" },
  "vatRate": { "code": "VAT_15", "ratePercent": "15.00" },
  "active": true,
  "stock": 120,
  "sizeValues": [
    { "sizeCode": "INDIVIDUAL", "price": "1.00", "calories": 80 },
    { "sizeCode": "MEDIUM", "price": "1.50", "calories": 110 },
    { "sizeCode": "FAMILY", "price": "2.20", "calories": 160 }
  ],
  "createdAt": "…",
  "updatedAt": "…"
}
```

**PresetPizza**:

```json
{
  "id": "uuid",
  "code": "MARGHERITA",
  "name": "Margarita",
  "description": "…",
  "active": true,
  "sortOrder": 1,
  "recipe": [
    {
      "ingredientId": "uuid",
      "code": "MAS-TRA",
      "name": "Masa tradicional",
      "categoryCode": "DOUGH",
      "portions": 1,
      "active": true,
      "stock": 40
    }
  ],
  "pricesBySize": [
    { "sizeCode": "INDIVIDUAL", "price": "5.10", "calories": 610 }
  ],
  "available": true,
  "unavailableReasons": []
}
```

`pricesBySize` (los 3 tamaños) se calcula con el motor (sin precio fijo, S-18). `available=false` si la predefinida está inactiva o algún ingrediente de la receta está inactivo, sin stock suficiente para 1 pizza o sin valores de tamaño (S-25); `unavailableReasons` lista violaciones.

---

## 2. Endpoints

Resumen:

| #   | Método | Ruta                        | Auth                    | Descripción                               |
| --- | ------ | --------------------------- | ----------------------- | ----------------------------------------- |
| 1   | GET    | `/health`                   | Pública                 | Estado del servicio y de la BD.           |
| 2   | POST   | `/auth/register`            | Pública                 | Registro de cliente.                      |
| 3   | POST   | `/auth/login`               | Pública                 | Inicio de sesión.                         |
| 4   | POST   | `/auth/refresh`             | Pública (refresh token) | Rotación de tokens.                       |
| 5   | POST   | `/auth/logout`              | Pública (refresh token) | Revoca el refresh token.                  |
| 6   | GET    | `/auth/me`                  | Auth                    | Usuario actual.                           |
| 7   | GET    | `/sizes`                    | Auth                    | Tamaños.                                  |
| 8   | GET    | `/ingredient-categories`    | Auth                    | Categorías.                               |
| 9   | GET    | `/vat-rates`                | ADMIN                   | Tarifas IVA.                              |
| 10  | GET    | `/ingredients`              | Auth                    | Lista (cliente: solo activos).            |
| 11  | GET    | `/ingredients/:id`          | Auth                    | Detalle (cliente: solo activo).           |
| 12  | POST   | `/ingredients`              | ADMIN                   | Crear.                                    |
| 13  | PUT    | `/ingredients/:id`          | ADMIN                   | Editar datos, tarifa, valores por tamaño. |
| 14  | PATCH  | `/ingredients/:id/stock`    | ADMIN                   | Fijar o ajustar stock.                    |
| 15  | PATCH  | `/ingredients/:id/status`   | ADMIN                   | Activar/desactivar.                       |
| 16  | GET    | `/preset-pizzas`            | Auth                    | Lista (cliente: solo activas).            |
| 17  | GET    | `/preset-pizzas/:id`        | Auth                    | Detalle.                                  |
| 18  | POST   | `/preset-pizzas`            | ADMIN                   | Crear.                                    |
| 19  | PUT    | `/preset-pizzas/:id`        | ADMIN                   | Editar datos y receta.                    |
| 20  | PATCH  | `/preset-pizzas/:id/status` | ADMIN                   | Activar/desactivar.                       |
| 21  | POST   | `/orders/quote`             | Auth                    | Cotizar (cálculo en vivo, sin escribir).  |
| 22  | POST   | `/orders`                   | CLIENT                  | Confirmar pedido.                         |
| 23  | GET    | `/orders`                   | Auth                    | Cliente: sus pedidos; Admin: todos.       |
| 24  | GET    | `/orders/:id`               | Auth (dueño o ADMIN)    | Comprobante.                              |
| 25  | PATCH  | `/orders/:id/status`        | ADMIN                   | Avanzar estado.                           |

No existen: `DELETE /ingredients/:id` (S-23), `DELETE /preset-pizzas/:id` (baja lógica, ADR-010), cancelación o edición de pedidos (S-20), endpoints de gestión de usuarios o de tarifas IVA (fijas por seed). Cualquier ruta/método no definido → `404 ROUTE_NOT_FOUND`.

Errores comunes a todos los endpoints autenticados: `401 UNAUTHENTICATED`, `401 TOKEN_EXPIRED`, `403 FORBIDDEN` (rol), `429 RATE_LIMITED`, `500 INTERNAL_ERROR`. Abajo se listan solo los específicos.

---

### 2.1 Health

#### 1. `GET /health` — Pública

Response `200`:

```json
{
  "data": {
    "status": "ok",
    "database": "ok",
    "version": "0.1.0",
    "time": "2026-11-06T15:04:05.123Z"
  }
}
```

Response `503 SERVICE_UNAVAILABLE` si la BD no responde (`SELECT 1` falla). No requiere token.

---

### 2.2 Autenticación

#### 2. `POST /auth/register` — Pública (authLimiter)

Request:

```json
{
  "fullName": "Ana Pérez",
  "email": "ana@ejemplo.com",
  "password": "minimo8car"
}
```

Validación: `fullName` 2..120; `email` válido ≤ 254 (se normaliza a minúsculas); `password` 8..72 caracteres (72 = límite de bcrypt). Siempre crea rol `CLIENT` (S-14); un campo `role` en el body → 400.

Response `201`:

```json
{
  "data": {
    "user": {
      "id": "uuid",
      "fullName": "Ana Pérez",
      "email": "ana@ejemplo.com",
      "role": "CLIENT"
    },
    "accessToken": "jwt",
    "accessTokenExpiresIn": 900,
    "refreshToken": "jwt",
    "refreshTokenExpiresIn": 604800
  }
}
```

Errores: `400 VALIDATION_ERROR` (para contraseña: "La contraseña debe tener al menos 8 caracteres."), `409 EMAIL_ALREADY_EXISTS`, `429`.

#### 3. `POST /auth/login` — Pública (authLimiter)

Request: `{ "email": "ana@ejemplo.com", "password": "..." }`
Response `200`: mismo cuerpo que registro (con `role` `ADMIN` o `CLIENT`).
Errores: `400 VALIDATION_ERROR`, `401 INVALID_CREDENTIALS` ("Email o contraseña incorrectos."), `403 FORBIDDEN` (usuario desactivado), `429`.

#### 4. `POST /auth/refresh` — Pública (authLimiter)

Request: `{ "refreshToken": "jwt" }`
Response `200`: `{ "data": { "accessToken", "accessTokenExpiresIn", "refreshToken", "refreshTokenExpiresIn" } }` (el refresh anterior queda revocado).
Errores: `400`, `401 INVALID_REFRESH_TOKEN` (si es un token ya rotado se revocan todos los del usuario).

#### 5. `POST /auth/logout` — Pública

Request: `{ "refreshToken": "jwt" }`
Response `204` (sin cuerpo). Idempotente: token desconocido o ya revocado también responde 204.
Errores: `400`.

#### 6. `GET /auth/me` — Auth

Response `200`: `{ "data": { "id": "uuid", "fullName": "…", "email": "…", "role": "CLIENT" } }`

---

### 2.3 Catálogos

#### 7. `GET /sizes` — Auth

Response `200`: `{ "data": [ { "code": "INDIVIDUAL", "name": "Individual", "sortOrder": 1 }, { "code": "MEDIUM", "name": "Mediana", "sortOrder": 2 }, { "code": "FAMILY", "name": "Familiar", "sortOrder": 3 } ] }`

#### 8. `GET /ingredient-categories` — Auth

Response `200`: `{ "data": [ { "code": "DOUGH", "name": "Masa", "sortOrder": 1 }, … ] }`

#### 9. `GET /vat-rates` — ADMIN

Response `200`: `{ "data": [ { "code": "VAT_15", "name": "IVA 15 %", "ratePercent": "15.00", "isDefault": true }, { "code": "VAT_0", "name": "IVA 0 %", "ratePercent": "0.00", "isDefault": false } ] }`

---

### 2.4 Ingredientes

#### 10. `GET /ingredients` — Auth

Query: `category` (code, opcional), `search` (código o nombre, opcional), `includeInactive` (`true|false`, solo ADMIN; para CLIENT se ignora y siempre es `false`), `page`, `pageSize`. Sin `page` se devuelve la lista completa no paginada (catálogo pequeño, ~20 elementos), que es lo que usa el armado.

Response `200`: lista de **Ingredient** ordenada por categoría y nombre (paginada si se envía `page`). Para CLIENT se incluye `stock` (necesario para limitar porciones, US-06).

Errores: `400 VALIDATION_ERROR`.

#### 11. `GET /ingredients/:id` — Auth

Response `200`: `{ "data": Ingredient }`. Errores: `400` (id no UUID), `404 NOT_FOUND` (inexistente, o inactivo para CLIENT).

#### 12. `POST /ingredients` — ADMIN

Request:

```json
{
  "code": "QUE-MOZ",
  "name": "Queso mozzarella",
  "categoryCode": "CHEESE",
  "vatRateCode": "VAT_15",
  "active": true,
  "stock": 120,
  "sizeValues": [
    { "sizeCode": "INDIVIDUAL", "price": "1.00", "calories": 80 },
    { "sizeCode": "MEDIUM", "price": "1.50", "calories": 110 },
    { "sizeCode": "FAMILY", "price": "2.20", "calories": 160 }
  ]
}
```

Validación: `code` 2..20 `^[A-Z0-9-]+$` (se normaliza a mayúsculas); `name` 2..80; `categoryCode` válido; `vatRateCode` opcional (por defecto la tarifa `isDefault`, 15 %); `active` opcional (def. `true`); `stock` entero ≥ 0 (def. 0); `sizeValues` exactamente uno por tamaño, `price` ≥ 0 con ≤ 2 decimales (máx. 99999999.99), `calories` entero ≥ 0.

Response `201`: `{ "data": Ingredient }`.
Errores: `400 VALIDATION_ERROR` (precio o stock negativo, decimales de más), `409 INGREDIENT_CODE_EXISTS`, `422 MISSING_SIZE_VALUES` (faltan o se repiten tamaños; `details: [{ "missing": ["FAMILY"] }]`), `422 INVALID_VAT_RATE`.

#### 13. `PUT /ingredients/:id` — ADMIN

Request: mismo cuerpo que POST **sin** `stock` ni `active` (se gestionan con 14 y 15). `code` editable si sigue siendo único.
Response `200`: `{ "data": Ingredient }`. No afecta pedidos existentes (snapshots).
Errores: `400`, `404`, `409 INGREDIENT_CODE_EXISTS`, `422 MISSING_SIZE_VALUES`, `422 INVALID_VAT_RATE`, `422 INGREDIENT_CATEGORY_LOCKED` (`details: [{ "presetPizzas": ["Margarita"] }]`).

#### 14. `PATCH /ingredients/:id/stock` — ADMIN

Request (una de las dos formas):

```json
{ "operation": "SET", "value": 150 }
```

```json
{ "operation": "ADD", "value": -5 }
```

`SET` fija el stock (`value` ≥ 0). `ADD` ajusta con un entero ≠ 0, de forma atómica (`stock = stock + value`) y respetando `CHECK stock >= 0`, por lo que no pisa descuentos concurrentes de pedidos.
Response `200`: `{ "data": Ingredient }`.
Errores: `400 VALIDATION_ERROR` (SET negativo), `404`, `422 STOCK_WOULD_BE_NEGATIVE`.

#### 15. `PATCH /ingredients/:id/status` — ADMIN

Request: `{ "active": false }`
Response `200`: `{ "data": Ingredient }`. Desactivar no borra ni altera el histórico; el ingrediente deja de ofrecerse al cliente y las predefinidas que lo usan pasan a no disponibles. Activar exige los 3 valores de tamaño.
Errores: `400`, `404`, `422 MISSING_SIZE_VALUES`.

---

### 2.5 Pizzas predefinidas

#### 16. `GET /preset-pizzas` — Auth

Query: `includeInactive` (solo ADMIN). Response `200`: `{ "data": [ PresetPizza ] }` ordenado por `sortOrder`. CLIENT solo recibe activas; las no disponibles se incluyen con `available: false` para mostrarlas deshabilitadas (US-03).

#### 17. `GET /preset-pizzas/:id` — Auth

Response `200`: `{ "data": PresetPizza }`. Errores: `400`, `404` (inexistente, o inactiva para CLIENT).

#### 18. `POST /preset-pizzas` — ADMIN

Request:

```json
{
  "code": "MARGHERITA",
  "name": "Margarita",
  "description": "Tomate, mozzarella y albahaca",
  "active": true,
  "sortOrder": 1,
  "recipe": [
    { "ingredientId": "uuid-masa", "portions": 1 },
    { "ingredientId": "uuid-salsa", "portions": 1 },
    { "ingredientId": "uuid-mozzarella", "portions": 2 },
    { "ingredientId": "uuid-albahaca", "portions": 1 }
  ]
}
```

Reglas: exactamente 1 ingrediente `DOUGH` y 1 `SAUCE` con `portions = 1`; toppings de otras categorías con `portions` 1..3; sin repetidos; **sin mínimo de toppings** (S-17, US-19). No hay campo de precio (S-18). Se permite usar ingredientes inactivos (la predefinida quedará no disponible).
Response `201`: `{ "data": PresetPizza }`.
Errores: `400`, `409 PRESET_CODE_EXISTS`, `409 PRESET_NAME_EXISTS`, `422 INVALID_RECIPE` (`details` = violaciones: `DOUGH_REQUIRED`, `SAUCE_REQUIRED`, `MAX_PORTIONS_EXCEEDED`, `INGREDIENT_CATEGORY_NOT_ALLOWED`, `DUPLICATE_INGREDIENT`, `INGREDIENT_NOT_FOUND`).

#### 19. `PUT /preset-pizzas/:id` — ADMIN

Request: mismo cuerpo que POST sin `active`. La receta se reemplaza completa en una transacción. Afecta solo a pedidos nuevos.
Response `200`: `{ "data": PresetPizza }`. Errores: los de 18 + `404`.

#### 20. `PATCH /preset-pizzas/:id/status` — ADMIN

Request: `{ "active": false }`. Response `200`: `{ "data": PresetPizza }`. Errores: `400`, `404`.

---

### 2.6 Pedidos

#### 21. `POST /orders/quote` — Auth (CLIENT o ADMIN)

Cotización sin efectos: usa el mismo motor que `POST /orders` (ADR-002). Pensado para el cálculo en vivo de "Personalizar pizza" (un ítem) y del resumen del pedido (todas las líneas).

Request:

```json
{ "items": ["PizzaItemInput", "…"] }
```

Response `200` (siempre que el esquema sea válido, aunque haya violaciones de reglas):

```json
{
  "data": {
    "valid": true,
    "violations": [],
    "items": ["PricedPizza", "…"],
    "totals": {
      "subtotalVat15": "15.40",
      "subtotalVat0": "3.60",
      "vat15": "2.31",
      "total": "21.31",
      "totalCalories": 1640
    },
    "stock": [
      {
        "ingredientId": "uuid",
        "name": "Queso mozzarella",
        "required": 6,
        "available": 120
      }
    ]
  }
}
```

- `valid` = ninguna violación en ningún ítem ni de stock agregado.
- `violations` (raíz) = violaciones de stock agregado del pedido (`INSUFFICIENT_STOCK`); las de cada pizza van en `items[i].violations`.
- Con violaciones, los importes se calculan con los componentes válidos presentes (cálculo parcial en vivo); un componente inexistente, inactivo o sin valores para el tamaño no suma.
- El stock es informativo: no se reserva.

Errores: `400 VALIDATION_ERROR` (forma del payload).

#### 22. `POST /orders` — CLIENT

Request:

```json
{ "items": ["PizzaItemInput", "…"], "expectedTotal": "21.31" }
```

`expectedTotal` es opcional: si se envía y no coincide con el total recalculado (p. ej. el admin cambió un precio entre la cotización y la confirmación) se responde `409 PRICE_CHANGED` sin crear el pedido, con `details: [ { "quote": { "items": [], "totals": {} } } ]`.

Proceso (una transacción, ADR-004/005): bloqueo `FOR UPDATE` de los ingredientes implicados → motor (reglas + cálculo) → verificación y descuento de stock (masa y salsa 1 por pizza; toppings 1 por porción; × cantidad; agregado entre líneas) → número `GP-AAAAMMDD-NNNN` → inserción de pedido, pizzas, componentes con snapshots e historial (`fromStatus: null → PENDING`). Si algo falla, no queda ningún cambio.

Response `201`: `{ "data": OrderDetail }` (estado `PENDING`). Cabecera `Location: /api/v1/orders/{id}`.

Errores:

| HTTP | code                   | Detalle                                                                                                               |
| ---- | ---------------------- | --------------------------------------------------------------------------------------------------------------------- |
| 400  | `VALIDATION_ERROR`     | Forma del payload, cantidad fuera de 1..20, porciones fuera de 1..3.                                                  |
| 403  | `FORBIDDEN`            | Un ADMIN intenta crear pedidos.                                                                                       |
| 409  | `INSUFFICIENT_STOCK`   | `details`: `[{ ingredientId, code, name, requested, available }]`, mensaje con ingrediente y disponibilidad (RNF-06). |
| 409  | `PRICE_CHANGED`        | Ver arriba.                                                                                                           |
| 422  | `PIZZA_RULES_VIOLATED` | `details`: violaciones por ítem (§1.3).                                                                               |

#### 23. `GET /orders` — Auth

Query: `status` (opcional), `from`, `to` (`YYYY-MM-DD`, sobre `orderDate`), `search` (número de orden o email, solo ADMIN), `page` (def. 1), `pageSize` (def. 20, máx. 100). Orden: `createdAt` descendente.

- CLIENT: solo sus pedidos (filtro forzado por `userId` del token).
- ADMIN: todos los registros. En `GET /ingredients` y `GET /preset-pizzas` ve solo los activos salvo que envíe `includeInactive=true` (decisión PA-B1; implementado así).

Response `200`: `{ "data": [ OrderSummary ], "page": 1, "pageSize": 20, "total": 3 }`.
Errores: `400`.

#### 24. `GET /orders/:id` — Auth (dueño o ADMIN)

Response `200`: `{ "data": OrderDetail }` construido solo con snapshots.
Errores: `400` (id no UUID), `404 NOT_FOUND` (inexistente **o** de otro cliente; no revela existencia).

#### 25. `PATCH /orders/:id/status` — ADMIN

Request: `{ "status": "IN_PREPARATION" }`
Transiciones válidas: `PENDING → IN_PREPARATION`, `IN_PREPARATION → DELIVERED`. Se actualiza con condición sobre el estado actual (`UPDATE … WHERE id = $1 AND status = $prev`) para evitar dobles avances concurrentes, y se registra en `order_status_history`.
Response `200`: `{ "data": OrderDetail }`.
Errores: `400`, `403 FORBIDDEN` (CLIENT, US-20), `404`, `422 INVALID_STATUS_TRANSITION` (`details: [{ "from": "DELIVERED", "to": "PENDING", "allowed": [] }]`).

---

## 3. Matriz de permisos

| Endpoint                                               | Pública | CLIENT                    | ADMIN |
| ------------------------------------------------------ | ------- | ------------------------- | ----- |
| `GET /health`                                          | sí      | sí                        | sí    |
| `POST /auth/register`, `/login`, `/refresh`, `/logout` | sí      | sí                        | sí    |
| `GET /auth/me`, `/sizes`, `/ingredient-categories`     | —       | sí                        | sí    |
| `GET /vat-rates`                                       | —       | 403                       | sí    |
| `GET /ingredients`, `/ingredients/:id`                 | —       | solo activos              | todos |
| `POST/PUT/PATCH /ingredients…`                         | —       | 403                       | sí    |
| `GET /preset-pizzas`, `/preset-pizzas/:id`             | —       | solo activas              | todas |
| `POST/PUT/PATCH /preset-pizzas…`                       | —       | 403                       | sí    |
| `POST /orders/quote`                                   | —       | sí                        | sí    |
| `POST /orders`                                         | —       | sí                        | 403   |
| `GET /orders`                                          | —       | solo propios              | todos |
| `GET /orders/:id`                                      | —       | solo propio (ajeno → 404) | sí    |
| `PATCH /orders/:id/status`                             | —       | 403                       | sí    |

## 4. Ejemplo de referencia (para pruebas de contrato)

Datos (tamaño MEDIUM): masa 2.00 / 300 kcal / 15 %; salsa 1.00 / 60 kcal / 0 %; queso 1.50 / 110 kcal / 15 % × 3; jamón 1.20 / 90 kcal / 15 % × 1; piña 0.80 / 40 kcal / 0 % × 1; cantidad 2.

- unitPrice = 2.00 + 1.00 + 4.50 + 1.20 + 0.80 = **9.50**; unitCalories = 300 + 60 + 330 + 90 + 40 = **820**.
- unitSubtotalVat15 = 2.00 + 4.50 + 1.20 = 7.70; unitSubtotalVat0 = 1.00 + 0.80 = 1.80.
- lineSubtotal = 19.00; lineCalories = 1640.
- Totales: subtotalVat15 = 15.40; subtotalVat0 = 3.60; vat15 = 15.40 × 0.15 = **2.31**; total = **21.31**; totalCalories = 1640.
- Stock requerido: masa 2, salsa 2, queso 6, jamón 2, piña 2.
- Casos de redondeo (US-10): subtotalVat15 0.35 → IVA 0.05 (0.0525); 0.30 → 0.05 (0.045 half-up); 10.00 con 0 % 2.00 → IVA 1.50, total 13.50; 6.50 → 0.98 (0.975 half-up).
- US-07: MEDIUM, masa 2.00, salsa 1.00, queso 1.50 × 3 → 7.50 sin IVA.
