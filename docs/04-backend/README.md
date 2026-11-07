# Backend — Good Pizza

API REST `/api/v1` en Node.js 20+ (ESM), Express, Prisma (PostgreSQL), Zod, JWT + bcryptjs, helmet, cors, express-rate-limit y pino. Código en `backend/`. Contrato: `docs/02-architecture/api-contract.md` (se implementan los 25 endpoints).

## Cómo correrlo

Todo se ejecuta con scripts npm, que cargan `backend/.env.local` con `dotenv-cli`. No abras ni edites ese archivo desde herramientas; usa `backend/env.template` como guía de nombres.

```bash
cd backend
npm install                        # dependencias (el cliente Prisma se genera con db:migrate o npm run db:generate)
npm run db:deploy                  # aplica las migraciones existentes a `pizzeria` (esquema public); uso recomendado en el local
npm run db:migrate                 # prisma migrate dev: crea migraciones nuevas; solo en desarrollo
npm run db:seed                    # datos de ejemplo (idempotente)
npm run dev                        # API en http://localhost:3000/api/v1 (recarga con --watch)
npm start                          # sin recarga
npm test                           # Vitest + Supertest
npm run lint                       # ESLint
npm run db:test:migrate            # crea/migra el esquema de pruebas `test` (usa DATABASE_URL_TEST)
```

Comprobación rápida: `GET http://localhost:3000/api/v1/health` -> `{"data":{"status":"ok","database":"ok",...}}`.

### Variables de entorno (`backend/env.template`)

| Variable                                                               | Obligatoria                     | Propósito                                                                          |
| ---------------------------------------------------------------------- | ------------------------------- | ---------------------------------------------------------------------------------- |
| `NODE_ENV`, `PORT`                                                     | no (def. `development`, `3000`) | Entorno y puerto.                                                                  |
| `DATABASE_URL`                                                         | sí                              | URL de Prisma: `postgresql://USUARIO:CONTRASENA@HOST:5432/pizzeria?schema=public`. |
| `DATABASE_URL_TEST`                                                    | solo para pruebas con BD real   | Misma conexión con `?schema=test`. Si falta, esas pruebas se omiten con un aviso.  |
| `JWT_SECRET`, `JWT_REFRESH_SECRET`                                     | sí                              | Secretos distintos, >= 32 caracteres (obligatorio en producción).                  |
| `JWT_ACCESS_EXPIRES_IN`, `JWT_REFRESH_EXPIRES_IN`                      | no (`15m`, `7d`)                | Vida de los tokens.                                                                |
| `BCRYPT_COST`                                                          | no (`12`, mínimo 12)            | Coste de bcrypt.                                                                   |
| `CORS_ORIGINS`                                                         | no                              | Lista blanca separada por comas (sin `Origin` se acepta: app Windows).             |
| `RATE_LIMIT_WINDOW_MS`, `RATE_LIMIT_MAX`, `AUTH_RATE_LIMIT_MAX`        | no (`900000`, `300`, `10`)      | Limitadores global y de autenticación.                                             |
| `LOG_LEVEL`                                                            | no (`info`)                     | Nivel de pino.                                                                     |
| `SEED_ADMIN_EMAIL`, `SEED_CLIENT_EMAIL`                                | no                              | Emails del seed (def. `admin@goodpizza.local`, `cliente@goodpizza.local`).         |
| `SEED_ADMIN_PASSWORD`, `SEED_CLIENT_PASSWORD`                          | no                              | Contraseñas del seed; si faltan se generan al azar y se imprimen **una sola vez**. |
| `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_SCHEMA` | informativas                    | Prisma no las usa; `DB_NAME=pizzeria`.                                             |

Al arrancar, `src/config/env.js` valida el entorno; si falta o es inválida una variable, muestra su **nombre** (nunca el valor) y termina.

## Migraciones

| Carpeta                                | Contenido                                                                                                                                       |
| -------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `20261106185922_init`                  | Modelo completo (15 tablas, 3 enums).                                                                                                           |
| `20261106185930_init`                  | Migración vacía (sin cambios) generada por Prisma al repetir `--create-only`; ya está aplicada, se conserva para no desincronizar el historial. |
| `20261106190500_add_check_constraints` | Las 9 restricciones CHECK de `data-model.md` §5.1 (incluye `stock >= 0`).                                                                       |

Nota: los CHECK debían ir en la migración inicial, pero esta se aplicó antes de añadirlos; como una migración aplicada no se edita (y no se reinicia la base), se agregaron en una migración posterior. El resultado en BD es el mismo.

## Datos de ejemplo (seed)

`prisma/seed.js` + `prisma/seed-lib.js`: 2 roles, 3 tamaños, 6 categorías, tarifas IVA 15 %/0 %, **20 ingredientes de ejemplo** (3 masas, 3 salsas, 4 quesos, 4 carnes, 5 vegetales, 1 otro) con precio y calorías distintos por tamaño, stock y tarifa de IVA (la mayoría 15 %, algunos 0 %), las 5 pizzas predefinidas, 1 administrador y 1 cliente. **Son datos de ejemplo, no precios reales: revísalos antes de operar.** Es idempotente (`upsert`); no pisa precios/stock ya editados ni cambia la contraseña de un usuario existente.

## Pruebas

`npm test` ejecuta Vitest (`tests/unit`, `tests/api`, `tests/integration`). Las pruebas con BD real (`tests/integration/db.test.js`) usan **solo** el esquema `test`: se omiten si no existe `DATABASE_URL_TEST`, abortan si la URL no termina en `?schema=test` o si `current_schema()` no es `test`, y el setup de pruebas fuerza `DATABASE_URL` al esquema de pruebas (o a una URL inválida) para que nada toque `public`. Para habilitarlas:

1. En `backend/.env.local` agrega `DATABASE_URL_TEST="postgresql://USUARIO:CONTRASENA@localhost:5432/pizzeria?schema=test"` (tus mismas credenciales, `?schema=test`).
2. `npm run db:test:migrate` (crea el esquema `test` y aplica las migraciones).
3. `npm test`.

## Endpoints reales (25)

Prefijo `/api/v1`. Respuestas `{ "data": ... }`; listas paginadas `{ data, page, pageSize, total }`; errores `{ "error": { "code", "message", "details" } }`. Cualquier otra ruta o método -> `404 ROUTE_NOT_FOUND`.

| #   | Método | Ruta                        | Auth                 | Notas                                                                                               |
| --- | ------ | --------------------------- | -------------------- | --------------------------------------------------------------------------------------------------- |
| 1   | GET    | `/health`                   | Pública              | 200 / 503 `SERVICE_UNAVAILABLE`                                                                     |
| 2   | POST   | `/auth/register`            | Pública (limitador)  | 201; siempre rol CLIENT; contraseña 8..72                                                           |
| 3   | POST   | `/auth/login`               | Pública (limitador)  | 200; 401 `INVALID_CREDENTIALS`; 403 desactivado                                                     |
| 4   | POST   | `/auth/refresh`             | Pública (limitador)  | Rotación; reutilización revoca todos                                                                |
| 5   | POST   | `/auth/logout`              | Pública              | 204 idempotente                                                                                     |
| 6   | GET    | `/auth/me`                  | Auth                 | Usuario actual                                                                                      |
| 7   | GET    | `/sizes`                    | Auth                 |                                                                                                     |
| 8   | GET    | `/ingredient-categories`    | Auth                 |                                                                                                     |
| 9   | GET    | `/vat-rates`                | ADMIN                |                                                                                                     |
| 10  | GET    | `/ingredients`              | Auth                 | `category`, `search`, `includeInactive` (solo ADMIN), `page`, `pageSize`; sin `page` lista completa |
| 11  | GET    | `/ingredients/:id`          | Auth                 | Cliente: solo activos                                                                               |
| 12  | POST   | `/ingredients`              | ADMIN                | 201; 409 `INGREDIENT_CODE_EXISTS`; 422 `MISSING_SIZE_VALUES`/`INVALID_VAT_RATE`                     |
| 13  | PUT    | `/ingredients/:id`          | ADMIN                | 422 `INGREDIENT_CATEGORY_LOCKED`                                                                    |
| 14  | PATCH  | `/ingredients/:id/stock`    | ADMIN                | `SET`/`ADD` atómico; 422 `STOCK_WOULD_BE_NEGATIVE`                                                  |
| 15  | PATCH  | `/ingredients/:id/status`   | ADMIN                | Activar exige los 3 tamaños                                                                         |
| 16  | GET    | `/preset-pizzas`            | Auth                 | Con `pricesBySize`, `available`, `unavailableReasons`                                               |
| 17  | GET    | `/preset-pizzas/:id`        | Auth                 |                                                                                                     |
| 18  | POST   | `/preset-pizzas`            | ADMIN                | 409 `PRESET_CODE_EXISTS`/`PRESET_NAME_EXISTS`; 422 `INVALID_RECIPE`                                 |
| 19  | PUT    | `/preset-pizzas/:id`        | ADMIN                | Reemplaza la receta en una transacción                                                              |
| 20  | PATCH  | `/preset-pizzas/:id/status` | ADMIN                | Baja lógica                                                                                         |
| 21  | POST   | `/orders/quote`             | Auth                 | Cálculo en vivo, sin escribir                                                                       |
| 22  | POST   | `/orders`                   | CLIENT               | 201 + `Location`; 409 `INSUFFICIENT_STOCK`/`PRICE_CHANGED`; 422 `PIZZA_RULES_VIOLATED`              |
| 23  | GET    | `/orders`                   | Auth                 | Cliente: solo suyos; filtros `status`, `from`, `to`, `search` (ADMIN)                               |
| 24  | GET    | `/orders/:id`               | Auth (dueño o ADMIN) | Ajeno -> 404                                                                                        |
| 25  | PATCH  | `/orders/:id/status`        | ADMIN                | PENDING -> IN_PREPARATION -> DELIVERED                                                              |

No existen (por diseño): `DELETE /ingredients/:id`, `DELETE /preset-pizzas/:id`, cancelación/edición de pedidos, gestión de usuarios o tarifas.

## Documentos de la fase

`entregable.md`, `flujo.md`, `diagrama-er.md`, `pruebas-unitarias.md`, `manual-usuario.md`, `documentacion-tecnica.md` en esta carpeta.

## Servir el frontend como estático (opcional)

No se implementó: el frontend es una aplicación de escritorio Windows (no hay `frontend/build/web`).
