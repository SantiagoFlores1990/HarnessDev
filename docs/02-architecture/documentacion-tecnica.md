# Documentación técnica — Fase 2: Arquitectura

## 1. Visión técnica

Monolito en un repositorio: API REST Node.js 20/Express (`backend/`, prefijo `/api/v1`) con Prisma sobre PostgreSQL 17 (base `pizzeria`, ya existente; modelo por migraciones) y app Flutter de escritorio Windows (`frontend/`). Las reglas de negocio (precio, calorías, IVA por componente con half-up, armado, stock) viven en un motor puro único del backend; el frontend las consume por `POST /api/v1/orders/quote`. Detalle completo en `architecture.md`.

## 2. Arquitectura y componentes

| Componente                                                           | Responsabilidad                                         | Documento                  |
| -------------------------------------------------------------------- | ------------------------------------------------------- | -------------------------- |
| Middlewares (helmet, cors, rate-limit, auth, validate, errorHandler) | Seguridad, autenticación, validación, errores uniformes | architecture §2.1, §6      |
| routes / controllers                                                 | Enrutado y HTTP in/out                                  | architecture §2.1          |
| services                                                             | Casos de uso, transacciones, autorización por dueño     | architecture §2.2          |
| pricing-engine                                                       | Cálculo y reglas (puro, testeable)                      | architecture §2.3, ADR-002 |
| stock.service / orderNumber.service                                  | Concurrencia de stock y numeración diaria               | ADR-005, ADR-004           |
| Prisma + PostgreSQL                                                  | Persistencia, CHECK, índices                            | data-model                 |
| Flutter core (dio, router, theme, storage)                           | Infraestructura de la app                               | architecture §3            |
| Flutter features                                                     | Pantallas cliente y admin                               | architecture §3.2-3.4      |

## 3. Tecnologías y versiones

| Componente            | Tecnología                                                         | Versión          |
| --------------------- | ------------------------------------------------------------------ | ---------------- |
| Runtime backend       | Node.js                                                            | ≥ 20             |
| Framework HTTP        | Express                                                            | ^4.21            |
| ORM                   | Prisma / @prisma/client                                            | ^6.0             |
| Validación            | Zod                                                                | ^3.23            |
| Auth                  | jsonwebtoken / bcryptjs                                            | ^9.0 / ^2.4      |
| Seguridad             | helmet / cors / express-rate-limit                                 | ^8 / ^2.8 / ^7.4 |
| Logging               | pino (+ pino-http, a añadir)                                       | ^9.5             |
| Pruebas backend       | Vitest / Supertest                                                 | ^2.1 / ^7.0      |
| Env                   | dotenv-cli                                                         | ^7.4             |
| Base de datos         | PostgreSQL                                                         | 17               |
| Frontend              | Flutter (Dart 3), Material 3                                       | estable vigente  |
| Estado / rutas / HTTP | flutter_riverpod / go_router / dio                                 | última estable   |
| Almacenamiento seguro | flutter_secure_storage                                             | última estable   |
| Otros Flutter         | flutter_svg, intl, flutter_localizations, decimal; mocktail (test) | última estable   |

Versiones del backend tomadas de `backend/package.json` actual.

## 4. Estructura de carpetas

Ver `architecture.md` §2.2 (backend) y §3.2 (frontend). Resumen:

```
backend/  src/{config,lib,middlewares,routes,controllers,schemas,services/pricing-engine,utils}, prisma/{schema.prisma,migrations,seed.js}, tests/{unit,api,helpers}
frontend/ lib/{core/{config,api,storage,router,theme,widgets,utils},features/<feature>/{data,domain,presentation}}, assets/brand, test/{core,features,flows}
docs/02-architecture/  architecture.md, data-model.md, api-contract.md, adr/, 6 entregables
```

## 5. Configuración y variables de entorno

`backend/.env.local` (no versionado, no lo leen los agentes) cargado por los scripts npm con dotenv-cli; validado con Zod en `src/config/env.js`. Nombres y propósito (sin valores):

| Variable                                                                               | Propósito                                                                                 |
| -------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `NODE_ENV`, `PORT`                                                                     | Entorno y puerto.                                                                         |
| `DB_HOST`, `DB_PORT`, `DB_NAME` (=`pizzeria`), `DB_USER`, `DB_PASSWORD`, `DB_SCHEMA`   | Componentes informativos de la conexión.                                                  |
| `DATABASE_URL`                                                                         | Conexión que usa Prisma.                                                                  |
| `JWT_SECRET`, `JWT_REFRESH_SECRET`                                                     | Secretos de firma (distintos, aleatorios, ≥ 32 bytes).                                    |
| `JWT_ACCESS_EXPIRES_IN` (15m), `JWT_REFRESH_EXPIRES_IN` (7d)                           | Vida de los tokens.                                                                       |
| `BCRYPT_COST` (12)                                                                     | Coste bcrypt.                                                                             |
| `CORS_ORIGINS`                                                                         | Lista blanca de orígenes de navegador.                                                    |
| `RATE_LIMIT_WINDOW_MS`, `RATE_LIMIT_MAX`, `AUTH_RATE_LIMIT_MAX`                        | Limitadores.                                                                              |
| `LOG_LEVEL`                                                                            | Nivel de log.                                                                             |
| `SEED_ADMIN_EMAIL`, `SEED_ADMIN_PASSWORD`, `SEED_CLIENT_EMAIL`, `SEED_CLIENT_PASSWORD` | Usuarios del seed; si falta una contraseña se genera aleatoria y se imprime una sola vez. |
| `DATABASE_URL_TEST` (opcional)                                                         | Solo si se aprueba PA-01: base/esquema separado para pruebas de integración.              |

Frontend: `API_URL` vía `--dart-define` (def. `http://localhost:3000/api/v1`).

La fase 4 debe agregar a `backend/env.template` las variables nuevas respecto a la plantilla actual: `JWT_ACCESS_EXPIRES_IN`, `JWT_REFRESH_EXPIRES_IN`, `BCRYPT_COST`, `RATE_LIMIT_WINDOW_MS`, `RATE_LIMIT_MAX`, `AUTH_RATE_LIMIT_MAX`, `LOG_LEVEL`, `SEED_ADMIN_EMAIL`, `SEED_ADMIN_PASSWORD`, `SEED_CLIENT_EMAIL`, `SEED_CLIENT_PASSWORD`, y cambiar el ejemplo de `DB_NAME`/`DATABASE_URL` a `pizzeria`.

## 6. API / Interfaces

Contrato completo en `api-contract.md`. Resumen:

| Método     | Ruta                               | Auth          | Request                        | Response                                    | Errores            |
| ---------- | ---------------------------------- | ------------- | ------------------------------ | ------------------------------------------- | ------------------ |
| GET        | /health                            | Pública       | —                              | 200 status                                  | 503                |
| POST       | /auth/register                     | Pública       | fullName, email, password      | 201 user + tokens                           | 400, 409           |
| POST       | /auth/login                        | Pública       | email, password                | 200 user + tokens                           | 400, 401, 403      |
| POST       | /auth/refresh                      | Pública       | refreshToken                   | 200 tokens                                  | 400, 401           |
| POST       | /auth/logout                       | Pública       | refreshToken                   | 204                                         | 400                |
| GET        | /auth/me                           | Auth          | —                              | 200 user                                    | 401                |
| GET        | /sizes, /ingredient-categories     | Auth          | —                              | 200 lista                                   | 401                |
| GET        | /vat-rates                         | ADMIN         | —                              | 200 lista                                   | 401, 403           |
| GET        | /ingredients, /ingredients/:id     | Auth          | filtros                        | 200                                         | 400, 404           |
| POST / PUT | /ingredients, /ingredients/:id     | ADMIN         | Ingredient + sizeValues        | 201 / 200                                   | 400, 404, 409, 422 |
| PATCH      | /ingredients/:id/stock             | ADMIN         | operation SET/ADD, value       | 200                                         | 400, 404, 422      |
| PATCH      | /ingredients/:id/status            | ADMIN         | active                         | 200                                         | 400, 404, 422      |
| GET        | /preset-pizzas, /preset-pizzas/:id | Auth          | —                              | 200 con pricesBySize, available             | 400, 404           |
| POST / PUT | /preset-pizzas, /preset-pizzas/:id | ADMIN         | datos + recipe                 | 201 / 200                                   | 400, 404, 409, 422 |
| PATCH      | /preset-pizzas/:id/status          | ADMIN         | active                         | 200                                         | 400, 404           |
| POST       | /orders/quote                      | Auth          | items[]                        | 200 valid, violations, items, totals, stock | 400                |
| POST       | /orders                            | CLIENT        | items[], expectedTotal?        | 201 OrderDetail                             | 400, 403, 409, 422 |
| GET        | /orders                            | Auth          | status, from, to, search, page | 200 paginado                                | 400                |
| GET        | /orders/:id                        | Dueño o ADMIN | —                              | 200 OrderDetail                             | 400, 404           |
| PATCH      | /orders/:id/status                 | ADMIN         | status                         | 200 OrderDetail                             | 400, 403, 404, 422 |

## 7. Base de datos

15 tablas y 3 enums; esquema Prisma completo, CHECK, seed y consultas críticas en `data-model.md`; ER lógico en `diagrama-er.md`. Migraciones: `npm run db:migrate -- --name init --create-only` → añadir CHECK al SQL → `npm run db:migrate`. Nunca se borra ni recrea la base `pizzeria`; no se editan migraciones aplicadas. Seed idempotente: `npm run db:seed` (datos de ejemplo).

## 8. Instalación y ejecución (previsto)

```
cd backend
npm install
npm run db:migrate        # aplica migraciones sobre pizzeria (usa .env.local vía dotenv-cli)
npm run db:seed           # datos de ejemplo; imprime contraseñas generadas si faltan SEED_*_PASSWORD
npm run dev               # API en http://localhost:PORT/api/v1

cd ../frontend
flutter pub get
flutter run -d windows --dart-define=API_URL=http://localhost:3000/api/v1
```

## 9. Pruebas

Estrategia en ADR-011 y casos a automatizar en `pruebas-unitarias.md`: unitarias del motor y utilidades (sin BD), API con Supertest y dobles (sin escribir en `pizzeria`), integración real solo con `DATABASE_URL_TEST` (PA-01); Flutter con widget tests y prueba de flujo con repositorios falsos. Comandos: `npm test`, `flutter test`, `flutter analyze`.

## 10. Seguridad

bcrypt (coste ≥ 12, contraseña 8..72); JWT access 15 min + refresh rotativo con hash en BD y detección de reutilización; autorización por rol y por dueño (ajeno → 404); helmet, cors con lista blanca, rate limit global y de auth, límite de body 100 KB; Zod `strict()`; Prisma parametrizado; logs con redacción de credenciales; tokens en flutter_secure_storage; ningún secreto en el repositorio ni en la documentación. Revisión en fase 7.

## 11. Despliegue y operación

Sin DevOps/Docker/CI (fase 8 omitida, S-11). Operación local: backend con `npm start` en la PC del local y PostgreSQL local; la app Windows apunta a la API por `API_URL`. Verificación de salud: `GET /api/v1/health`. La zona horaria del SO del servidor determina la fecha del número de orden (S-24).

## 12. Decisiones (ADR) y deuda técnica

| ADR | Tema                                        |
| --- | ------------------------------------------- |
| 001 | Monolito y capas del backend                |
| 002 | Motor de cálculo único y `/orders/quote`    |
| 003 | Snapshots en pedidos                        |
| 004 | Secuencia diaria del número de orden        |
| 005 | Concurrencia de stock                       |
| 006 | JWT access + refresh                        |
| 007 | Frontend Riverpod, go_router, feature-first |
| 008 | Dinero Decimal y redondeo half-up           |
| 009 | Catálogos como tablas, estado enum          |
| 010 | Baja lógica                                 |
| 011 | Estrategia de pruebas sin tocar datos       |

Deuda técnica conocida: carrito no persistido; CHECK mantenidos a mano en SQL; sin purga programada de `refresh_tokens` (se purga en login); concurrencia real sin probar si no se aprueba PA-01; modelos Flutter escritos a mano.
