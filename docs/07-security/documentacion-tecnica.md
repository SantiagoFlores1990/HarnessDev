# Documentación técnica — Fase 7: Seguridad

## 1. Visión técnica

La seguridad de Good Pizza se apoya en tres ideas:

1. **El servidor no confía en el cliente:** recalcula precios y stock, valida todo con Zod strict y autoriza por rol y por dueño en cada ruta.
2. **Sesiones de corta duración** con refresh rotativo, del que solo se guarda el hash.
3. **Integridad en la base:** Decimal, CHECK, transacciones con `FOR UPDATE` y snapshots.

Esta fase documenta los controles existentes, sus brechas (`security-report.md`) y el endurecimiento recomendado. El código no cambia.

## 2. Arquitectura y componentes (vista de seguridad)

Orden de los middlewares en `backend/src/app.js`:

| #   | Middleware                       | Archivo:línea     | Función                                                                                               |
| --- | -------------------------------- | ----------------- | ----------------------------------------------------------------------------------------------------- |
| 1   | `helmet()`                       | `app.js:16`       | Cabeceras de seguridad (CSP, `X-Content-Type-Options`, `X-Frame-Options`, etc.)                       |
| 2   | `cors` con lista blanca          | `app.js:17-23`    | Sin `Origin` (app de escritorio) se acepta; un navegador solo desde `CORS_ORIGINS`; sin `credentials` |
| 3   | `requestLogger`                  | `app.js:24`       | Método, ruta sin query, estado y duración. Sin cabeceras ni cuerpo                                    |
| 4   | Limitador global                 | `app.js:25`       | `RATE_LIMIT_MAX` por `RATE_LIMIT_WINDOW_MS` y por IP (S-02)                                           |
| 5   | `express.json({limit:"100kb"})`  | `app.js:26`       | Límite del cuerpo                                                                                     |
| 6   | Rutas `/api/v1`                  | `routes/index.js` | `authLimiter`, `requireAuth`, `requireRole` y `validate(Zod)` por ruta                                |
| 7   | `notFoundRoute` y `errorHandler` | `app.js:30-31`    | Formato uniforme; 500 sin stack                                                                       |

Servicios con lógica de seguridad:

- `token.service.js`: firma y verificación HS256, `type`, `jti` y hash SHA-256.
- `auth.service.js`: bcrypt, hash de relleno, rotación y reutilización.
- `order.service.js`: filtro por dueño, transacción y transiciones.
- `stock.service.js`: descuento condicionado.

En el frontend:

- `token_storage.dart`: `flutter_secure_storage`.
- `auth_interceptor.dart`: Bearer y refresh serializado.
- `session_provider.dart`: restauración y cierre de sesión.
- `app_router.dart`: guards de UX.

## 3. Tecnologías y versiones (relevantes para la seguridad)

| Componente            | Tecnología                        | Versión instalada                                          |
| --------------------- | --------------------------------- | ---------------------------------------------------------- |
| Runtime               | Node.js                           | 24.13.1 (engines `>=20`)                                   |
| HTTP                  | express                           | 4.22.3                                                     |
| Cabeceras             | helmet                            | 8.3.0                                                      |
| CORS                  | cors                              | 2.8.6                                                      |
| Rate limit            | express-rate-limit                | 7.5.1                                                      |
| JWT                   | jsonwebtoken                      | 9.0.3                                                      |
| Hash                  | bcryptjs                          | 2.4.3                                                      |
| Validación            | zod                               | 3.25.76 (aviso GHSA-mrhx-c7xc-m3w5, S-05/S-08)             |
| ORM                   | @prisma/client / prisma           | 6.19.3                                                     |
| Logs                  | pino                              | 9.14.0                                                     |
| Almacenamiento seguro | flutter_secure_storage / _windows | 11.2.0 / 4.2.2                                             |
| HTTP cliente          | dio                               | según `pubspec.lock` (al día según `flutter pub outdated`) |

## 4. Estructura de carpetas (archivos con controles de seguridad)

```
backend/src/config/env.js            validación de variables (S-01)
backend/src/middlewares/             requireAuth, requireRole, validate, rateLimiters, errorHandler, requestLogger
backend/src/services/token.service.js, auth.service.js, order.service.js, stock.service.js, catalogLoader.service.js
backend/src/schemas/                 Zod strict por endpoint
backend/src/lib/logger.js            redacción de pino
backend/prisma/migrations/*check*    CHECK de integridad
backend/scripts/db-test-migrate.js   barrera del esquema test
backend/tests/helpers/setup.js       fuerza la BD de pruebas
frontend/lib/core/storage/, core/api/, features/auth/, core/router/
.claude/settings.json, .claude/hooks/ guardas del entorno de desarrollo (H-01..H-04)
```

## 5. Configuración y variables de entorno (solo nombres y propósito)

| Variable                                                        | Propósito de seguridad                                 | Recomendación                                                                    |
| --------------------------------------------------------------- | ------------------------------------------------------ | -------------------------------------------------------------------------------- |
| `NODE_ENV`                                                      | En `production` exige secretos de 32 o más y distintos | `production` en el PC del local (C1)                                             |
| `JWT_SECRET`, `JWT_REFRESH_SECRET`                              | Firma de access y refresh                              | Aleatorios, de 48 bytes o más en base64url, distintos; nunca los de la plantilla |
| `JWT_ACCESS_EXPIRES_IN`, `JWT_REFRESH_EXPIRES_IN`               | Vida de los tokens                                     | `15m` / `7d`; valorar menos para ADMIN (S-03)                                    |
| `BCRYPT_COST`                                                   | Coste del hash (12 a 15 fuera de pruebas)              | 12 o más                                                                         |
| `CORS_ORIGINS`                                                  | Lista blanca para navegadores                          | Vacía o `http://localhost:3000` si no hay versión web                            |
| `RATE_LIMIT_WINDOW_MS`, `RATE_LIMIT_MAX`, `AUTH_RATE_LIMIT_MAX` | Límites por IP                                         | Revisar según el número de puestos (S-02)                                        |
| `LOG_LEVEL`                                                     | Nivel de pino                                          | `info` en producción; `debug` solo para diagnóstico                              |
| `DATABASE_URL`                                                  | Conexión de la app                                     | Rol sin DDL ni superusuario (S-17)                                               |
| `DATABASE_URL_TEST`                                             | Pruebas de integración                                 | Siempre `?schema=test`; idealmente con otro rol (S-17)                           |
| `SEED_ADMIN_PASSWORD`, `SEED_CLIENT_PASSWORD`                   | Contraseñas iniciales                                  | 12 o más caracteres, o dejarlas vacías para que se generen (S-10)                |
| (propuesta) `HOST`                                              | Interfaz de escucha                                    | `127.0.0.1` (S-04)                                                               |

## 6. API / Interfaces (matriz de autorización)

La matriz completa, verificada ruta por ruta, está en `security-report.md` §6. Resumen:

| Grupo                                                  | Auth              | Controles adicionales                                         | Errores de seguridad                                                  |
| ------------------------------------------------------ | ----------------- | ------------------------------------------------------------- | --------------------------------------------------------------------- |
| `/health`                                              | Pública           | —                                                             | 503 sin detalles                                                      |
| `/auth/register`, `/login`, `/refresh`                 | Pública           | `authLimiter`, Zod strict, bcrypt, rotación                   | 400, 401 `INVALID_CREDENTIALS`/`INVALID_REFRESH_TOKEN`, 403, 409, 429 |
| `/auth/logout`                                         | Pública (refresh) | Idempotente                                                   | 400                                                                   |
| Catálogos y lectura de ingredientes y predefinidas     | Auth              | Los inactivos se ocultan al CLIENT                            | 401, 404                                                              |
| Escritura de ingredientes y predefinidas, `/vat-rates` | ADMIN             | Zod strict, sin `stock`/`active` en PUT                       | 401, 403, 409, 422                                                    |
| `/orders/quote`                                        | Auth              | Sin escritura                                                 | 400, 401                                                              |
| `POST /orders`                                         | CLIENT            | `active` en la BD, transacción, `FOR UPDATE`, `expectedTotal` | 403, 409, 422                                                         |
| `GET /orders`, `/orders/:id`                           | Auth              | Filtro por dueño → 404                                        | 401, 404                                                              |
| `PATCH /orders/:id/status`                             | ADMIN             | Transiciones solo hacia adelante, `WHERE status = prev`       | 403, 422                                                              |

## 7. Base de datos

Ver `diagrama-er.md` de esta fase (anotaciones de seguridad) y `docs/04-backend/diagrama-er.md` (diccionario completo). Puntos clave:

- 9 CHECK (stock, precios, calorías, porciones, cantidad, tarifa, consistencia del total).
- `onDelete` Restrict, Cascade o SetNull según el agregado.
- SQL crudo solo con plantillas etiquetadas (`catalogLoader.service.js:88`, `orderNumber.service.js:10-15`, `health.service.js:9`).

## 8. Instalación y ejecución (endurecida)

1. Copiar `backend/env.template` a `backend/.env.local` y completar los secretos (ver §5 y `manual-usuario.md` §4.3).
2. `cd backend && npm run db:deploy` contra la base real (aplica las migraciones sin el reset interactivo de `migrate dev`), y `npm run db:seed` una sola vez.
3. `npm start` con `NODE_ENV=production`.
4. Firewall: bloquear las conexiones entrantes al puerto 3000.
5. `cd frontend && flutter build windows --release --dart-define=API_URL=http://localhost:3000/api/v1`.

## 9. Pruebas

Ver `pruebas-unitarias.md`: 26 casos de seguridad cubiertos (134 pruebas backend y 19 Flutter ejecutadas en esta fase, todas pasan), 13 casos propuestos y las 22 de integración pendientes de `DATABASE_URL_TEST`.

## 10. Seguridad

### 10.1 Controles por categoría OWASP Top 10 (2021)

| Categoría                          | Estado                                                                        | Referencia             |
| ---------------------------------- | ----------------------------------------------------------------------------- | ---------------------- |
| A01 Control de acceso              | Correcto (rol y dueño en 25 de 25 rutas)                                      | report §5-6; S-07      |
| A02 Fallos criptográficos          | Correcto en el código; depende de los secretos y de no usar HTTP en red       | S-01, S-04             |
| A03 Inyección                      | Correcto (Prisma y plantillas etiquetadas)                                    | report §5              |
| A04 Diseño inseguro                | Abuso de stock y PC compartido                                                | S-03, S-06             |
| A05 Configuración                  | Validación de secretos solo en `production`; `listen` en todas las interfaces | S-01, S-04, S-12       |
| A06 Componentes vulnerables        | zod (producción, Media); dev-only críticas                                    | S-05, S-08, S-09       |
| A07 Autenticación                  | Sólida; límites compartidos                                                   | S-02, S-10, S-11       |
| A08 Integridad de software y datos | Lockfiles versionados; snapshots; CHECK                                       | —                      |
| A09 Logging y monitoreo            | Redacción correcta; no hay auditoría de catálogo                              | S-12, flujo (STRIDE R) |
| A10 SSRF                           | No aplica (la API no hace peticiones salientes)                               | —                      |

### 10.2 Endurecimiento recomendado (en orden)

1. S-01: validación de secretos en todos los entornos y `NODE_ENV=production`.
2. S-04: `HOST=127.0.0.1` y firewall.
3. S-03: cierre de sesión por inactividad y sin persistencia para CLIENT.
4. S-02: limitadores separados y por cuenta.
5. S-05: recortar `details` y comprobar el largo de los arreglos antes de validar; Zod 4.
6. S-06: topes de pedido y limitador por usuario.
7. S-12, S-13, S-10, S-14: ajustes menores.
8. H-01..H-04: permisos y hooks de Claude Code (usuario).

## 11. Despliegue y operación

- Fase 8 (DevOps) omitida por mandato del prompt: no hay Docker ni CI. Al no haber CI, `npm audit` no se ejecuta automáticamente; hay que lanzarlo a mano en cada actualización.
- Rotación de secretos: cambiar `JWT_SECRET` y `JWT_REFRESH_SECRET` invalida todas las sesiones. Es el procedimiento ante incidentes.
- Copias de seguridad cifradas de PostgreSQL fuera del PC (no verificable desde el repositorio).

## 12. Decisiones (ADR) y deuda técnica

- **ADR-006** (JWT access y refresh): se mantiene. Este informe añade la recomendación de exigir secretos en todos los entornos (S-01) y, opcionalmente, comprobar el estado del usuario en las rutas ADMIN (S-07).
- **ADR-005** (stock): correcto en el código; falta la prueba real (D-05).
- **Deuda:** Zod 3 → 4; Vitest 2 → 5; `npm audit fix` (`deepmerge-ts`); límites por cuenta; auditoría de cambios de catálogo; cancelación de pedidos (decisión de negocio).
