# Pruebas unitarias — Fase 7: Seguridad

## Alcance

Esta fase **no añade código de pruebas**: el revisor no modifica `backend/` ni `frontend/`. Consolida los casos de abuso y seguridad que ya existen (fases 4 a 6), los vuelve a ejecutar y propone los que faltan, cada uno ligado a un hallazgo de `security-report.md`.

## Casos de seguridad ya cubiertos (ejecutados en esta fase)

| ID      | Riesgo     | Descripción                                                                                     | Archivo                                                 | Resultado esperado     | Resultado real                         | Estado    |
| ------- | ---------- | ----------------------------------------------------------------------------------------------- | ------------------------------------------------------- | ---------------------- | -------------------------------------- | --------- |
| SEC-01  | A07        | Sin cabecera, con token basura o con esquema `Basic`: 401 `UNAUTHENTICATED`                     | `backend/tests/api/endpoints.test.js:366-381`           | 401                    | 401                                    | OK        |
| SEC-02  | A07        | Access token caducado: 401 `TOKEN_EXPIRED`                                                      | `endpoints.test.js:383`                                 | 401                    | 401                                    | OK        |
| SEC-03  | A07        | Login con contraseña errónea o email inexistente: el mismo 401 genérico                         | `tests/unit/auth.service.test.js:129`                   | Mismo código y mensaje | Igual                                  | OK        |
| SEC-04  | A07        | Login de usuario desactivado: 403                                                               | `auth.service.test.js:140`, `endpoints.test.js:294`     | 403                    | 403                                    | OK        |
| SEC-05  | A07        | Refresh rota, revoca el anterior y encadena `replacedById`                                      | `auth.service.test.js:148`                              | Rotación               | Rotación                               | OK        |
| SEC-06  | A07        | Reutilizar un refresh ya rotado revoca **todos** los del usuario                                | `auth.service.test.js:163`                              | 401 + revocación total | Igual                                  | OK        |
| SEC-07  | A07        | Refresh firmado con otro secreto, o basura: 401                                                 | `auth.service.test.js:176`                              | 401                    | 401                                    | OK        |
| SEC-08  | A07        | Un access token no sirve como refresh                                                           | `auth.service.test.js:182`                              | 401                    | 401                                    | OK        |
| SEC-09  | A02        | La contraseña se guarda con bcrypt, nunca en claro; en la BD solo el hash del refresh           | `auth.service.test.js:93,111`                           | Hash                   | Hash                                   | OK        |
| SEC-10  | A04        | Un campo `role` en el registro da 400 (siempre se crea CLIENT)                                  | `endpoints.test.js:219`                                 | 400                    | 400                                    | OK        |
| SEC-11  | A01        | CLIENT en rutas de ADMIN (ingredientes, predefinidas, IVA, estado): 403                         | `endpoints.test.js:413,553,590,690,825,862,1227`        | 403                    | 403                                    | OK        |
| SEC-12  | A01        | ADMIN no puede confirmar pedidos: 403                                                           | `endpoints.test.js:1041`, `flows.inprocess.test.js:354` | 403                    | 403                                    | OK        |
| SEC-13  | A01 (IDOR) | Otro cliente recibe 404 por id y no ve el pedido en su lista                                    | `flows.inprocess.test.js:208`, `endpoints.test.js:1181` | 404                    | 404                                    | OK        |
| SEC-14  | A01        | `search` en pedidos lo ignora un CLIENT, que solo ve lo suyo                                    | `flows.inprocess.test.js:247`                           | Solo propios           | Solo propios                           | OK        |
| SEC-15  | A04        | Precios del cliente: los campos extra dan 400; `expectedTotal` desfasado da 409                 | `flows.inprocess.test.js:78`                            | 400 / 409              | Igual                                  | OK        |
| SEC-16  | A04        | Transiciones de estado inválidas dan 422; el cliente no cambia estado                           | `flows.inprocess.test.js:226,261`                       | 422 / 403              | Igual                                  | OK        |
| SEC-17  | A05        | Cuerpo mayor de 100 KB: 400                                                                     | `endpoints.test.js:127`                                 | 400                    | 400                                    | OK        |
| SEC-18  | A05        | Error inesperado: 500 sin stack ni detalles                                                     | `endpoints.test.js:133`                                 | Sin stack              | Sin stack                              | OK        |
| SEC-19  | A05        | Cabeceras de helmet presentes y sin `X-Powered-By`                                              | `endpoints.test.js:142`                                 | Presentes              | Presentes                              | OK        |
| SEC-20  | A05        | Rate limit: 429 `RATE_LIMITED`; el limitador de autenticación aplica a `/auth/login`            | `tests/api/security.test.js:19-43`                      | 429                    | 429                                    | OK        |
| SEC-21  | A05        | CORS: origen permitido recibe la cabecera, uno no permitido no, y sin `Origin` funciona         | `security.test.js:45-64`                                | Lista blanca           | Igual                                  | OK        |
| SEC-22  | A05        | `loadEnv`: no muestra valores; en producción exige secretos de 32 o más y distintos             | `tests/unit/utils.test.js:65,80,85`                       | Error sin valores      | Igual                                  | OK        |
| SEC-23  | A01        | Rutas inexistentes (DELETE, cancelación): 404 `ROUTE_NOT_FOUND`                                 | `endpoints.test.js:87-108`                              | 404                    | 404                                    | OK        |
| SEC-F01 | Sesión     | El interceptor añade el Bearer y no lo envía en peticiones `skipAuth`                           | `frontend/test/core/auth_interceptor_test.dart:73,80`   | —                      | OK                                     | OK        |
| SEC-F02 | Sesión     | Un solo refresh concurrente; refresh rechazado cierra la sesión; un fallo de red no; sin bucles | `auth_interceptor_test.dart:87-140`                     | —                      | OK                                     | OK        |
| SEC-F03 | UX/authz   | Guards: sin sesión va a `/login`; CLIENT en `/admin` va a `/presets`; el logout borra tokens    | `frontend/test/core/router_test.dart:12-71`             | —                      | OK                                     | OK        |
| SEC-DB  | Integridad | Concurrencia de stock, CHECK y secuencia contra PostgreSQL                                      | `backend/tests/integration/db.test.js`                  | —                      | **Omitidas** (sin `DATABASE_URL_TEST`) | PENDIENTE |

## Casos que faltan (propuestos, ligados a hallazgos)

| ID      | Hallazgo  | Caso propuesto                                                                                                         | Responsable |
| ------- | --------- | ---------------------------------------------------------------------------------------------------------------------- | ----------- |
| SEC-N01 | S-01      | `loadEnv` en `development` con `JWT_SECRET=change-me` debe fallar. Hoy pasa: el caso **fallaría** con el código actual | backend-dev |
| SEC-N02 | S-01      | Un token con `alg: none` o firmado HS512/RS256 da 401 (hoy lo cubre `algorithms`, pero no hay prueba)                  | backend-dev |
| SEC-N03 | S-01/S-07 | Un refresh token presentado como Bearer da 401 (`type` distinto)                                                       | backend-dev |
| SEC-N04 | S-07      | Un access token de un usuario inexistente o desactivado en rutas ADMIN (si se adopta la comprobación)                  | backend-dev |
| SEC-N05 | S-02      | Un login fallido de un email no agota el cupo de otro email; refresh con limitador propio                              | backend-dev |
| SEC-N06 | S-05      | Un arreglo `items` o `toppings` de 20 000 elementos responde 400 con `details.length <= 20` y respuesta menor de 10 KB | backend-dev |
| SEC-N07 | S-06      | Un pedido que supere el tope total de pizzas (si se aprueba) da 400/422                                                | backend-dev |
| SEC-N08 | S-13      | `?page=1e15` da 400                                                                                                    | backend-dev |
| SEC-N09 | S-12      | El log de un error no controlado no contiene `password`, `passwordHash`, `Authorization` ni el email                   | backend-dev |
| SEC-N10 | S-10      | El seed rechaza `SEED_ADMIN_PASSWORD` de menos de 12 caracteres y aplica coste 12 o más                                | backend-dev |
| SEC-N11 | S-04      | La app en `release` rechaza un `API_URL` `http://` que no sea loopback                                                 | flutter-dev |
| SEC-N12 | S-03      | Cierre de sesión por inactividad (widget test con reloj falso)                                                         | flutter-dev |
| SEC-N13 | SEC-DB    | Ejecutar las 22 pruebas de integración con `DATABASE_URL_TEST` (esquema `test`)                                        | usuario     |

## Ubicación del código de pruebas

- Backend: `backend/tests/api/{security,endpoints,flows.inprocess}.test.js`, `backend/tests/unit/{auth.service,utils}.test.js`, `backend/tests/integration/db.test.js`
- Flutter: `frontend/test/core/{auth_interceptor,router}_test.dart`

## Ejecución

```
cd backend && npx vitest run tests/api/security.test.js tests/api/endpoints.test.js tests/api/flows.inprocess.test.js tests/unit/auth.service.test.js tests/unit/utils.test.js
cd frontend && flutter test test/core/auth_interceptor_test.dart test/core/router_test.dart
```

Se usa `npx vitest` y no `npm test` para no cargar `backend/.env.local`: `vitest.config.js` trae valores fijos de prueba y `tests/helpers/setup.js` fuerza una URL de BD inválida si falta `DATABASE_URL_TEST`.

## Resultados (salida real, 2026-11-06)

```
 ✓ tests/api/endpoints.test.js (60 tests) 967ms
 ✓ tests/api/flows.inprocess.test.js (45 tests) 3238ms
 ✓ tests/unit/auth.service.test.js (12 tests) 51ms
 ✓ tests/unit/utils.test.js (12 tests) 9ms
 ✓ tests/api/security.test.js (5 tests) 157ms
 Test Files  5 passed (5)
      Tests  134 passed (134)
   Duration  7.28s
```

```
00:03 +19: All tests passed!
```

Microensayo de S-05 (en proceso, sin BD ni red):

```
empty-objects   bytes= 99011 len= 33000 ms= 79.5 heapDeltaMB= 17.8 issues= 33001
numbers         bytes= 98011 len= 49000 ms= 44.5 heapDeltaMB= 33.9 issues= 49001
nested-toppings bytes= 72075 len= 1     ms= 55.6 heapDeltaMB= 60.0 issues= 48001
requestBytes= 72075 responseBytes= 3625922 ratio= 50.3
```

## Cobertura

Sin cambios respecto a QA (`docs/06-qa/test-report.md` §4): `src/middlewares` 98,26 %, `auth.service.js` 92,5 %, `src/schemas` 99,49 %. `server.js`, donde está el `listen` de S-04, tiene 0 %. En Flutter, `core/storage/token_storage.dart` tiene 60 % y `dio_provider.dart` 0 %.
