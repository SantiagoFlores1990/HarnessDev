# Informe de seguridad — Good Pizza (Fase 7)

- **Fecha:** 2026-11-06 · **Rama:** `testHarness` · **Revisor:** security-reviewer (fase 7)
- **Alcance:** `backend/src`, `backend/prisma`, `backend/scripts`, `backend/env.template`, `backend/tests` (solo lectura), `frontend/lib`, `frontend/pubspec.yaml` / `pubspec.lock`, `.gitignore`, `.claude/settings.json` y `.claude/hooks/*`.
- **Método:** revisión manual del código contra OWASP Top 10 (2021) y la skill `security-checklist`; contraste con `docs/02-architecture/api-contract.md` (matriz §2), ADR-005/006 y `docs/06-qa/test-report.md` (D-03, D-04, D-06, PA-B1); `npm audit`, `flutter pub outdated`; ejecución de las pruebas de seguridad existentes; dos microensayos en proceso (sin BD ni red) para medir el impacto de un aviso de Zod.
- **Restricciones respetadas:** no se leyó ni se cargó `backend/.env.local`; no se ejecutaron seed ni migraciones; no se escribió en ninguna base de datos; no se modificó código de `backend/` ni de `frontend/`; sin commit ni push.

## 1. Veredicto

**GO CONDICIONADO para la aplicación. Si la condición C1 no se confirma, el veredicto pasa a NO-GO.**

Criterio aplicado: es **NO-GO** si queda alguna vulnerabilidad Crítica, o una Alta explotable y sin mitigar en el despliegue real (el PC del local). Es **GO** si no hay ninguna de las dos.

- Críticas: **0**.
- Altas en la aplicación: **1** (S-01). Solo se puede explotar si `backend/.env.local` usa secretos JWT débiles o los de la plantilla, porque el servidor no corre con `NODE_ENV=production` (la plantilla trae `development` y la documentación no pide otra cosa). No pude comprobarlo: el archivo está protegido y no se debe leer.
- Altas en el entorno de desarrollo: **1** (H-01, hooks y permisos de Claude Code). No afecta a la app en producción, pero pone en riesgo los datos reales del esquema `public` mientras se sigan usando agentes. Se recomienda corregirla antes de la próxima sesión con agentes.

Condiciones:

| ID  | Condición                                                                                                                                                                                                                                                                                                                           | Responsable               | Hallazgo |
| --- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------- | -------- |
| C1  | Confirmar que `JWT_SECRET` y `JWT_REFRESH_SECRET` de `backend/.env.local` son aleatorios, distintos y de **32 caracteres o más** (no `change-me` ni `change-me-too`). Hay dos formas de cumplirla: fijar `NODE_ENV=production` en el local, o que backend-dev aplique la validación de secretos en todos los entornos salvo `test`. | **usuario** / backend-dev | S-01     |
| C2  | (Recomendada, no bloqueante) Que la API escuche solo en `127.0.0.1` o que el firewall de Windows bloquee el puerto 3000 desde la red. Hoy escucha en todas las interfaces y por HTTP.                                                                                                                                               | usuario / backend-dev     | S-04     |

## 2. Resumen de hallazgos

| Severidad | Aplicación                       | Entorno de desarrollo (Claude Code) | Total |
| --------- | -------------------------------- | ----------------------------------- | ----- |
| Crítica   | 0                                | 0                                   | 0     |
| Alta      | 1 (S-01)                         | 1 (H-01)                            | 2     |
| Media     | 5 (S-02, S-03, S-04, S-05, S-06) | 1 (H-02)                            | 6     |
| Baja      | 8 (S-07 a S-13, S-17)            | 2 (H-03, H-04)                      | 10    |
| Info      | 4 (S-14, S-15, S-16, S-18)       | 0                                   | 4     |

## 3. Hallazgos de la aplicación

### S-01 · Alta · Fuera de `production` se aceptan secretos JWT débiles o los de la plantilla

- **Archivo:línea:** `backend/src/config/env.js:9-10` (`JWT_SECRET`/`JWT_REFRESH_SECRET` con `min(1)`), `backend/src/config/env.js:50-57` (largo mínimo de 32 y secretos distintos **solo** si `NODE_ENV === 'production'`), `backend/env.template:4` (`NODE_ENV=development`), `backend/env.template:26-27` (`change-me` / `change-me-too`), `backend/src/middlewares/requireAuth.js:11-14` (confía en `sub` y `role` sin consultar la BD).
- **Impacto:** el repositorio es público, así que los valores de la plantilla son conocidos. Si el local ejecuta la API en `development` (es lo que trae la plantilla y nada indica cambiarlo) y no se cambiaron los secretos, cualquiera puede firmar un access token HS256 con `role: "ADMIN"` y un `sub` cualquiera. `requireAuth` no comprueba que el usuario exista, así que ese token sirve para:
  - crear y editar ingredientes, precios, IVA y stock;
  - ver todos los pedidos con nombre y email de los clientes;
  - ver los pedidos de cualquier cliente, usando un `sub` con su UUID.

  Avanzar el estado de un pedido con un `sub` inexistente falla por la FK de `changed_by_id`, pero el resto funciona.

- **Escenario:** un atacante con acceso a la red del local (agravado por S-04) o al PC firma el JWT con `change-me` y llama a `PUT /api/v1/ingredients/:id` para fijar precios a 0, o a `GET /api/v1/orders` para descargar los datos de los clientes.
- **Corrección sugerida:**
  1. En `loadEnv`, aplicar las reglas de largo de 32 o más, secretos distintos y rechazo de valores conocidos (`change-me`, `change-me-too`, `secret`, `changeme`) en todo entorno salvo `test`.
  2. Documentar `NODE_ENV=production` para el PC del local.
  3. En la plantilla, dejar `JWT_SECRET=` vacío con la instrucción de generarlo, por ejemplo con `node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"`.
- **Responsable:** backend-dev (validación) y **usuario** (verificar `.env.local`).

### S-02 · Media · Los límites de peticiones van por IP y en un solo PC todos comparten la misma

- **Archivo:línea:** `backend/src/middlewares/rateLimiters.js:28-32`, `backend/src/routes/index.js:25,31-48` (una sola instancia de `authLimiter` para `register`, `login` y `refresh`), `backend/src/app.js:25` (límite global de 300 peticiones cada 15 minutos).
- **Impacto:** según la arquitectura (`docs/02-architecture/architecture.md` §1), la app y la API corren en la misma máquina. Todas las peticiones llegan desde `127.0.0.1` y comparten un único contador:
  - **10 operaciones de autenticación cada 15 minutos para todo el local**, sumando registro, login y refresh de todos los clientes y del administrador;
  - **300 peticiones cada 15 minutos para todos**, aunque la cotización en vivo dispara una petición por cada cambio en el armado (con debounce de 150 ms).
- **Escenario:** basta con 10 intentos de login fallidos (de un cliente que no recuerda su contraseña o de alguien malintencionado) para bloquear el login, el registro y la renovación de sesión de todos, incluido el administrador, durante 15 minutos. En horas punta el límite global puede agotarse solo con uso normal. Al revés, si hubiera varios PCs, no hay bloqueo por cuenta: el límite por IP no frena un ataque distribuido.
- **Corrección sugerida:**
  - Limitador propio para `/auth/refresh`, más alto.
  - Limitador de login con `keyGenerator` por IP más email normalizado y `skipSuccessfulRequests: true`.
  - Revisar `RATE_LIMIT_MAX` con datos reales de uso.
  - Retraso progresivo por cuenta tras N fallos.
- **Responsable:** backend-dev (con el dato de cuántos puestos hay; ver Preguntas abiertas).

### S-03 · Media · La sesión persiste en un equipo compartido y se restaura sola

- **Archivo:línea:** `frontend/lib/features/auth/presentation/session_provider.dart:11-23` (al arrancar, restaura la sesión si hay tokens), `frontend/lib/core/storage/token_storage.dart:35-38` (guarda access y refresh), `backend/env.template:29` (refresh de 7 días).
- **Impacto:** los tokens se guardan bien, en `flutter_secure_storage` (`flutter_secure_storage_windows` 4.2.2, protegido por el usuario de Windows). El riesgo es otro: en un PC compartido, quien abra la app hereda la última sesión durante 7 días, porque el refresh rota y se renueva. No hay cierre por inactividad. Si el administrador no cierra sesión, el siguiente cliente entra con rol ADMIN. Además, cualquier proceso que corra con el mismo usuario de Windows puede leer esos tokens.
- **Escenario:** el administrador avanza pedidos y se va. Un cliente se acerca al PC, la app sigue en `/admin/ingredients` (o la reabre) y cambia precios o stock.
- **Corrección sugerida:**
  - Cierre de sesión automático por inactividad (por ejemplo, 5 minutos para cliente y 10 para administrador).
  - Para el rol CLIENT, no persistir los tokens entre reinicios (solo en memoria) o cerrar sesión al salir.
  - Administrador en una cuenta de Windows separada.
  - Valorar un refresh más corto para ADMIN.
- **Responsable:** flutter-dev y **usuario** (definir el modelo de operación).

### S-04 · Media · La API escucha en todas las interfaces y por HTTP sin TLS

- **Archivo:línea:** `backend/src/server.js:21` (`app.listen(env.PORT)` sin host, es decir, `0.0.0.0`/`::`), `frontend/lib/core/config/app_config.dart:4-7` (URL `http://` por defecto, sin validar el esquema), `docs/05-frontend/README.md:21` (ejemplo `http://192.168.1.50:3000`).
- **Impacto:** la arquitectura prevé una sola máquina, pero la API queda accesible desde la red del local, incluida una posible Wi-Fi de clientes. Si se usa desde otro PC como sugiere el README, contraseñas y tokens viajan en claro. Combinado con S-01, permite tomar el control a distancia.
- **Corrección sugerida:**
  - Nueva variable `HOST` (por defecto `127.0.0.1`), con `app.listen(env.PORT, env.HOST)`.
  - Si se necesita red local: proxy inverso con TLS y `trust proxy` configurado, más una regla de firewall.
  - En la app, en `release`, rechazar `http://` salvo `localhost`/`127.0.0.1`.
- **Responsable:** backend-dev, flutter-dev y usuario (firewall).

### S-05 · Media · Los errores de validación se amplifican (respuesta 50 veces mayor que la petición y CPU)

- **Archivo:línea:** `backend/src/middlewares/errorHandler.js:11-16,25-31` (`details` incluye **todas** las incidencias de Zod, sin límite), `backend/src/schemas/order.schemas.js:27,37,44` (`.max()` de arreglos; Zod 3 valida todos los elementos aunque el arreglo supere el máximo), aviso GHSA-mrhx-c7xc-m3w5 (`zod@3.25.76`).
- **Medición real** (en proceso, esquema `quoteBody` real, sin BD ni red; script en el scratchpad de la sesión):

  ```
  empty-objects   bytes= 99011 len= 33000 ms= 79.5 heapDeltaMB= 17.8 issues= 33001
  numbers         bytes= 98011 len= 49000 ms= 44.5 heapDeltaMB= 33.9 issues= 49001
  nested-toppings bytes= 72075 len= 1     ms= 55.6 heapDeltaMB= 60.0 issues= 48001
  requestBytes= 72075 responseBytes= 3625922 ratio= 50.3
  ```

- **Impacto:** cualquier cliente autenticado (el registro es público) puede, con cada petición de 72 KB, bloquear el event loop unos 50-80 ms, consumir unos 60 MB de heap transitorio y forzar una respuesta de 3,6 MB. El límite global (300 peticiones cada 15 minutos por IP) lo acota, pero no lo elimina.
- **Corrección sugerida:**
  - Recortar `details` a las primeras 20 incidencias en `errorHandler` (y también en `zodDetails`).
  - Antes de validar elementos, rechazar arreglos que superen el máximo (`z.preprocess` o `superRefine` sobre `length`, o una comprobación previa en `validate`).
  - Planificar la migración a Zod 4 (la corrección del aviso está en `zod@4.6.6` o superior).
- **Responsable:** backend-dev.

### S-06 · Media · Se puede agotar el stock con pedidos sin pago ni cancelación

- **Archivo:línea:** `backend/src/services/order.service.js:37-149` (descuenta stock al confirmar), `backend/src/schemas/order.schemas.js:19,44` (hasta 50 líneas de 20 pizzas cada una), `backend/src/routes/index.js:150-156` (sin límite propio).
- **Impacto:** cualquier cuenta registrada puede confirmar pedidos de hasta 1000 pizzas y repetir. El stock se descuenta en el acto, no hay pago ni cancelación (S-20 del contrato) y no hay forma de reponer de manera trazable salvo un ajuste manual. Resultado: denegación de servicio del inventario y pedidos falsos en la cola de cocina.
- **Corrección sugerida:**
  - Tope de pizzas por pedido (suma de cantidades, por ejemplo 20) y de pedidos pendientes por cliente.
  - Limitador por usuario en `POST /orders`.
  - Valorar una cancelación por el administrador que devuelva el stock en una transacción. Esto requiere decisión del usuario.
- **Responsable:** backend-dev y **usuario** (decisión de negocio).

### S-07 · Baja · `requireAuth` no consulta la BD (observación D-03 de QA)

- **Archivo:línea:** `backend/src/middlewares/requireAuth.js:11-14`; solo `POST /orders` (`order.service.js:40-42`), login, refresh y `/auth/me` comprueban `active`.
- **Impacto:** un usuario desactivado, o con el rol cambiado, conserva acceso de lectura (y de escritura en catálogo si era ADMIN) hasta que caduca el access token, como máximo 15 minutos. Hoy no hay endpoint para desactivar usuarios: solo se puede hacer por SQL directo. Este mismo diseño amplifica S-01, porque acepta un `sub` inexistente.
- **Decisión recomendada:** aceptable con un access token de 15 minutos **si se corrige S-01**. Como defensa adicional, comprobar existencia y `active` del usuario (con caché de unos 30 segundos) en las rutas de ADMIN y en las escrituras.
- **Responsable:** backend-dev (con decisión del usuario, ver Preguntas abiertas).

### S-08 · Baja · Dependencias de producción con avisos altos (impacto real bajo)

- **Detalle:** `npm audit --omit=dev` informa 4 vulnerabilidades altas. Por paquete:
  - **`zod@3.25.76`** (GHSA-mrhx-c7xc-m3w5): se puede alcanzar desde HTTP; se trata en S-05.
  - **`deepmerge-ts@7.1.5`** (GHSA-ggr8-5vv4-36mx), que llega por `@prisma/config` dentro de `prisma@6.19.3`. Aparece como dependencia de producción porque `@prisma/client` declara `prisma` como peer. Solo se usa al cargar la configuración de la CLI de Prisma; ninguna entrada HTTP llega a él.
- **Corrección sugerida:** `npm audit fix` (no rompe nada para `deepmerge-ts`; modifica `package-lock.json`, que está protegido por hook, así que necesita autorización) y planificar Zod 4.
- **Responsable:** backend-dev con autorización del usuario.

### S-09 · Baja · Dependencias de desarrollo con avisos críticos y moderados

- **Detalle:** `npm audit` completo informa 14 vulnerabilidades (3 críticas, 5 altas, 6 moderadas):
  - `tinypool` (crítica, RCE por contaminación de prototipo), `vitest`, `@vitest/mocker`, `vite`, `vite-node`, `esbuild`, `@vitest/coverage-v8`, `test-exclude`, `glob` y `minimatch`: **solo se usan para pruebas**, no se distribuyen ni corren con la API. Explotarlas exige controlar la configuración de pruebas o el servidor de desarrollo de Vite, que no se usa.
  - Las demás (`zod`, `deepmerge-ts` y su cadena hasta `prisma`) son las de producción descritas en S-08.
- **Corrección sugerida:** actualizar `vitest` y `@vitest/coverage-v8` a la versión corregida (`5.1.0` según `npm audit`; cambio mayor) cuando haya ventana, y volver a ejecutar las pruebas.
- **Responsable:** backend-dev.

### S-10 · Baja · Política de contraseñas mínima; el seed no exige largo ni coste

- **Archivo:línea:** `backend/src/schemas/auth.schemas.js:8-11` (8 a 72 caracteres, sin lista de contraseñas comunes), `backend/prisma/seed-lib.js:424-429` (acepta cualquier `SEED_ADMIN_PASSWORD` no vacía, incluso de 1 carácter), `backend/prisma/seed.js:23` (`BCRYPT_COST` sin el mínimo de 12 que impone `env.js`).
- **Impacto:** el administrador podría quedar con una contraseña trivial. El seed podría hashear con un coste bajo si la variable está mal puesta.
- **Corrección sugerida:**
  - En el seed, exigir 12 caracteres o más para `SEED_ADMIN_PASSWORD` y aplicar `Math.max(12, cost)`.
  - En el registro, rechazar contraseñas comunes (lista local pequeña).
- **Responsable:** backend-dev y usuario (elegir una contraseña robusta).

### S-11 · Baja · El registro revela si un email existe

- **Archivo:línea:** `backend/src/services/auth.service.js:59-65` (`409 EMAIL_ALREADY_EXISTS`).
- **Impacto:** permite saber qué emails tienen cuenta. Lo exige el contrato (§1.2) y lo acota el limitador de autenticación. El login **no** revela nada: usa un hash de relleno y un mensaje genérico (`auth.service.js:85-96`).
- **Corrección sugerida:** aceptar el riesgo (decisión de UX documentada), o responder igual en ambos casos si algún día hay verificación por email.
- **Responsable:** architect (decisión).

### S-12 · Baja · El registro de errores no controlados puede incluir datos de la consulta

- **Archivo:línea:** `backend/src/middlewares/errorHandler.js:60-66` (registra `err.message` y `err.stack` completos); la redacción de pino (`backend/src/lib/logger.js:6-16`) no cubre `err.message`.
- **Impacto:** los mensajes de `PrismaClientValidationError` suelen incluir la invocación con sus argumentos (emails o hashes, por ejemplo). Solo queda en el log local, no en la respuesta (la respuesta 500 es genérica y sin stack, comprobado en la prueba `endpoints.test.js:133`). No lo verifiqué con un error real de Prisma.
- **Corrección sugerida:** en `production`, registrar `err.name`, `err.code` y un mensaje truncado; el stack solo con `LOG_LEVEL=debug`.
- **Responsable:** backend-dev.

### S-13 · Baja · `page` no tiene máximo y el listado de ingredientes sin `page` no tiene límite

- **Archivo:línea:** `backend/src/schemas/common.js:30` (`page` sin `max`), `backend/src/services/ingredient.service.js:78-85` (sin `page` devuelve todos).
- **Impacto:** `?page=1e15` genera un `skip` enorme. Lo probable es una consulta lenta o un 500 de Prisma (no lo verifiqué). La tabla de ingredientes es pequeña, así que el listado completo es aceptable hoy.
- **Corrección sugerida:** `page` con `max(100000)` o un `skip` acotado.
- **Responsable:** backend-dev.

### S-14 · Info · Los importes del administrador pueden desbordar las columnas de snapshot

- **Archivo:línea:** `backend/src/schemas/common.js:17-24` (admite hasta 99 999 999,99), `backend/prisma/schema.prisma:249,253,198` (`Decimal(10,2)` y `Decimal(12,2)`).
- **Impacto:** con precios extremos (solo los puede fijar el ADMIN), el precio unitario de una pizza (hasta 32 componentes de 3 porciones) supera `Decimal(10,2)` y la confirmación falla con un 500. No es explotable por un cliente.
- **Corrección sugerida:** limitar el precio por porción a un rango de negocio, por ejemplo 9 999,99.
- **Responsable:** backend-dev.

### S-15 · Info · El access token sigue vivo tras el logout y el cliente ve datos del administrador

- **Archivo:línea:** ADR-006 (decisión aceptada), `backend/src/services/auth.service.js:165-170`, `backend/src/services/orderView.js:92-97` (`statusHistory[].changedBy` incluye `id` y `fullName` del administrador en el comprobante del cliente).
- **Impacto:** el access token vale hasta 15 minutos después del logout. El cliente conoce el nombre y el UUID del administrador que cambió el estado.
- **Corrección sugerida:** aceptar el primero (ADR). Para el cliente, mostrar solo `toStatus` y `changedAt`, o un rol genérico.
- **Responsable:** architect / backend-dev.

### S-16 · Info · Los comodines `%` y `_` en `search`

- **Archivo:línea:** `backend/src/services/ingredient.service.js:71-76`, `backend/src/services/order.service.js:160-167` (Prisma `contains`).
- **Impacto:** no hay inyección (Prisma parametriza). Es posible que `%` o `_` amplíen la búsqueda; no verifiqué si Prisma 6 los escapa. `search` en pedidos solo lo aplica el ADMIN.
- **Responsable:** ninguno (informativo).

### S-17 · Baja · El aislamiento del esquema `test` depende solo del código

- **Archivo:línea:** `backend/env.template:20-23` (mismas credenciales para `public` y `test`).
- **Controles existentes (bien hechos):**
  - `backend/tests/helpers/setup.js:4-7`: fuerza `DATABASE_URL` a `DATABASE_URL_TEST` o a una URL inválida.
  - `backend/scripts/db-test-migrate.js:23-28`: aborta si `schema` no es `test`.
  - `backend/tests/integration/db.test.js:92-104`: comprueba `?schema=test` **y** `current_schema() = 'test'` antes del `TRUNCATE`.
  - `vitest.config.js`: fija secretos de prueba y desactiva el rate limit solo en pruebas.
- **Impacto:** el rol de la BD que usan las pruebas tiene permisos sobre `public`. Un error futuro en los controles, o una URL mal formada, podría tocar datos reales. No hay defensa a nivel de privilegios.
- **Corrección sugerida:** un rol de PostgreSQL dedicado a pruebas, con permisos solo sobre el esquema `test`. Un rol de ejecución de la app sin DDL (solo DML sobre `public`), distinto del rol de migraciones.
- **Responsable:** usuario (administración de PostgreSQL).

### S-18 · Info · Tarifas de IVA distintas de 0 % y 15 % (observación D-04 de QA)

- **Archivo:línea:** `backend/src/services/pricing-engine/calculatePizza.js:33-38`, `backend/src/services/pricing-engine/calculateOrder.js:13`, migración `add_check_constraints` línea 9.
- **Impacto en seguridad:** ninguno hoy. No hay endpoint para crear tarifas, solo existen `VAT_15` y `VAT_0`, y `vatRateCode` se valida contra la tabla. Si en el futuro se admitieran otras tarifas, el IVA quedaría mal calculado (integridad del dinero).
- **Responsable:** backend-dev (sin acción ahora).

## 4. Hallazgos del entorno de desarrollo (Claude Code)

Solo informo; no modifiqué nada.

### H-01 · Alta (entorno de desarrollo) · Comandos que pueden destruir o escribir en la BD real se aprueban sin preguntar

- **Archivo:línea:** `.claude/settings.json:5` (`Bash(npm run *)`), `:7` (`Bash(npx prisma *)`), `:8` (`Bash(node *)`); `.claude/hooks/guard-bash.js:19` (solo bloquea el texto `drop database|table`).
- **Impacto:** un agente puede ejecutar sin confirmación cualquiera de estos comandos contra el esquema real `pizzeria.public`:
  - `npx prisma migrate reset --force` (borra y recrea el esquema);
  - `npx prisma db push --force-reset`;
  - `npx prisma db execute --stdin` con `TRUNCATE` o `DELETE`;
  - `npm run db:seed`;
  - `node -e "..."` con un `PrismaClient`.

  Ninguna regla de `guard-bash` lo impide.

- **Corrección sugerida:**
  - Sacar `npx prisma *`, `node *` y `npm run *` de `allow` y permitir solo comandos concretos (`npm run lint`, `npm test`, `npx prisma generate`, `npx prisma validate`).
  - Añadir reglas `deny` y patrones en `guard-bash` para `migrate reset`, `db push`, `--force-reset`, `db execute`, `truncate`, `delete from` y `db:seed`.
- **Responsable:** usuario.

### H-02 · Media · Leer `.env.local` por Bash es fácil

- **Archivo:línea:** `.claude/hooks/guard-bash.js:20` (solo `cat|type|Get-Content|less|more`), `.claude/settings.json:20-23` (`deny` solo para la herramienta Read y solo en `./` y `./backend/`).
- **Impacto:** nada bloquea `head`, `tail`, `grep`, `sed`, `awk`, `findstr`, `Select-String`, `cp`, `base64` o `node -e "require('fs').readFileSync('backend/.env.local','utf8')"`. Tampoco `npx dotenv -e .env.local -- node -e "console.log(process.env)"`, y `node *` además está auto-aprobado. La regla del proyecto ("nunca leer `.env*`") depende de la disciplina del agente.
- **Corrección sugerida:**
  - En `guard-bash`, bloquear cualquier comando que mencione `\.env(\.|$)` salvo `env.template`, y cualquier `dotenv … -- node -e` o `printenv`.
  - Añadir `deny` con `Read(**/.env*)`. Verificar en la documentación de Claude Code si las reglas `Read()` también aplican a Grep y Glob; no lo verifiqué.
- **Responsable:** usuario.

### H-03 · Baja · `protect-files` solo cubre Edit/Write y distingue mayúsculas

- **Archivo:línea:** `.claude/settings.json:49` (matcher `Edit|Write`), `.claude/hooks/protect-files.js:15` (regex sensible a mayúsculas).
- **Impacto:**
  - Las escrituras por Bash (`echo … > backend/.env.local`, `sed -i`) no pasan por este hook.
  - En Windows, `backend/.ENV.LOCAL` apunta al mismo archivo y no coincide con la regex.
  - Otras herramientas de edición (si existieran, como NotebookEdit) tampoco quedan cubiertas.
- **Corrección sugerida:** regex con la bandera `i`; matcher `Edit|Write|MultiEdit|NotebookEdit`; en `guard-bash`, bloquear redirecciones (`>`, `>>`, `tee`, `Set-Content`, `Out-File`) hacia `.env`.
- **Responsable:** usuario.

### H-04 · Baja · Falsos positivos y huecos en `guard-bash`

- **Archivo:línea:** `.claude/hooks/guard-bash.js:22` y `:15`.
- **Impacto:**
  - `/(format|diskpart|mkfs)\b/i` bloquea cualquier comando con la palabra "format": `dart format` (permitido en `settings.json:14`), `npm run format`, `git log --format` e incluso leer `format-on-edit.js`. **Me pasó en esta revisión:** el comando `cat … format-on-edit.js` fue bloqueado.
  - La regla de `rm` no detecta `rm -r -f /`, `rm -fr ./` ni `rm -rf ../`.
  - La de `git push` no detecta `git push origin +main`.
- **Corrección sugerida:** anclar `format` a `^\s*format\s+[a-z]:` (el comando de Windows). Normalizar los flags de `rm` y cubrir `./` y `../`. Bloquear `+refspec` en push.
- **Responsable:** usuario.

## 5. Lo que está bien

| Área                   | Control verificado (archivo:línea)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Hash de contraseñas    | `bcryptjs` con coste `BCRYPT_COST` (mínimo 12 fuera de pruebas, máximo 15; `env.js:13-18`); 8 a 72 caracteres en el registro (`auth.schemas.js:8-11`); el hash nunca se devuelve (`auth.service.js:20-25`).                                                                                                                                                                                                                                                                                                                                                                    |
| Login sin enumeración  | Hash de relleno cuando el usuario no existe, para igualar tiempos, y mensaje genérico `INVALID_CREDENTIALS` (`auth.service.js:85-96`); `active` se comprueba después de la contraseña.                                                                                                                                                                                                                                                                                                                                                                                         |
| JWT                    | Algoritmo fijado en firma y verificación (`HS256`, `algorithms: ["HS256"]`, `token.service.js:5,24-26,51-53`), lo que impide `alg:none` y la confusión de algoritmos. Claim `type` (`access`/`refresh`) comprobado. Secretos distintos para access y refresh. Expiración de 15 minutos y 7 días.                                                                                                                                                                                                                                                                               |
| Refresh rotativo       | En la BD solo se guarda el SHA-256 (`token.service.js:60-61`). Rotación atómica con `updateMany … revokedAt: null` y comprobación de `count`, sin carrera (`auth.service.js:136-155`). Reutilizar un token revoca todos los del usuario (`:123-127,152-155`). Logout idempotente. Purga de tokens caducados.                                                                                                                                                                                                                                                                   |
| Autorización por rol   | `requireAuth` + `requireRole` en cada ruta, coherente con la matriz del contrato §2 (25 de 25 rutas revisadas en `routes/index.js:27-175`). El ADMIN no puede crear pedidos (`:150-156`). Solo el ADMIN cambia estados (`:169-175`). `/vat-rates` solo ADMIN.                                                                                                                                                                                                                                                                                                                  |
| IDOR                   | `GET /orders` filtra por `userId` cuando el rol es CLIENT (`order.service.js:153`). `GET /orders/:id` usa `findFirst({id, userId})` y responde 404 sin revelar si existe (`:184-191`). `search` solo para ADMIN (`:160`). Ingredientes y predefinidas inactivos ocultos al cliente (`ingredient.service.js:69,108`; `presetPizza.service.js:93-94,115`).                                                                                                                                                                                                                       |
| Validación             | Zod `.strict()` en todos los bodies, queries y params (`schemas/*.js`); UUID en `:id`. No hay asignación masiva: `role`, `stock` o `active` en el body de registro o de `PUT` dan 400 (con pruebas). Los precios **nunca** los manda el cliente: el servidor recalcula y `expectedTotal` solo sirve para detectar cambios (`order.service.js:58-68`).                                                                                                                                                                                                                          |
| Inyección SQL          | Solo hay 3 `$queryRaw` en `src/`, todos con plantillas etiquetadas parametrizadas: `catalogLoader.service.js:88` (`ANY(${idList}::uuid[]) … FOR UPDATE`), `orderNumber.service.js:10-15` (`${ymd}::date`), `health.service.js:9`. No hay `$queryRawUnsafe` ni `$executeRawUnsafe` en `src/`. El único `$executeRawUnsafe` está en `tests/integration/db.test.js:113`, con nombres de tabla constantes y protegido por la comprobación de esquema.                                                                                                                              |
| Stock y concurrencia   | `SELECT … FOR UPDATE` en orden determinista; descuento con `updateMany where stock >= n` y comprobación de 1 fila (`stock.service.js:30-51`); `CHECK (stock >= 0)` como última defensa; ajustes ADD atómicos (`ingredient.service.js:255-273`); avance de estado con `WHERE status = prev` (`order.service.js:213-223`).                                                                                                                                                                                                                                                       |
| Dinero                 | `decimal.js` con precisión 40 y half-up (`money.js:4-14`); columnas `Decimal`; CHECK `total = subtotales + IVA`; snapshots completos de precio, calorías, IVA, cliente y tamaño (`order.service.js:74-131`). Límites de abuso en el esquema y en la BD: 1 a 3 porciones, 1 a 20 de cantidad, 50 líneas, 30 extras.                                                                                                                                                                                                                                                             |
| Configuración HTTP     | `helmet()` (`app.js:16`), `x-powered-by` desactivado. CORS con lista blanca sin `credentials` y sin `*` (`app.js:17-23`; las peticiones sin `Origin`, como las de la app de escritorio, se aceptan y es correcto). Body JSON limitado a 100 KB (`app.js:26`). 404 y 500 con formato uniforme, sin stack (`errorHandler.js:67-71`).                                                                                                                                                                                                                                             |
| Logs                   | El `requestLogger` no registra cabeceras, cuerpo ni query (`requestLogger.js:3-19`); pino redacta `authorization`, `password`, `refreshToken` y `accessToken`. Los errores de entorno muestran solo el **nombre** de la variable, nunca el valor (`env.js:37-48`).                                                                                                                                                                                                                                                                                                             |
| Secretos y repositorio | `.gitignore` cubre `.env` y `.env.*` en cualquier nivel (`git check-ignore` confirma `backend/.env.local`). Ningún `.env*` versionado (`git ls-files`). El historial (3 commits) solo contiene los marcadores de `env.template`. Las búsquedas de URLs con credenciales, claves privadas, JWT y claves de API en el código, la documentación y las pruebas no encontraron nada real (solo contraseñas de prueba ficticias y la URL inválida de `setup.js`). El seed lee las contraseñas de variables o las genera al azar con `crypto.randomBytes` y las imprime una sola vez. |
| Frontend               | Tokens en `flutter_secure_storage`, nunca en `shared_preferences` (`token_storage.dart:11-45`). Sin `print`, `debugPrint` ni `LogInterceptor`. Sin `badCertificateCallback`. Un solo refresh serializado. Cierra la sesión si el refresh es rechazado y la conserva ante un fallo de red. El logout revoca el refresh en el servidor y limpia el almacenamiento. Los guards del router son solo UX: el servidor aplica la autorización en todos los casos. Contraseña oculta con `obscureText`.                                                                                |
| Esquema de BD          | `onDelete: Restrict` en usuarios, roles, catálogos e ingredientes usados en pedidos; `Cascade` solo para hijos del propio pedido y para refresh tokens; `SetNull` en la predefinida (el snapshot conserva el nombre). 9 CHECK.                                                                                                                                                                                                                                                                                                                                                 |

## 6. Matriz de permisos verificada (contrato §2 frente al código)

| #     | Ruta                                               | Contrato                            | Código (`routes/index.js`)                | Coincide                                                                            |
| ----- | -------------------------------------------------- | ----------------------------------- | ----------------------------------------- | ----------------------------------------------------------------------------------- |
| 1     | GET `/health`                                      | Pública                             | sin middlewares (`:28`)                   | Sí                                                                                  |
| 2-4   | POST `/auth/register`, `/login`, `/refresh`        | Pública                             | `authLimiter` + Zod (`:31-48`)            | Sí                                                                                  |
| 5     | POST `/auth/logout`                                | Pública (refresh)                   | Zod, sin limitador (`:49-53`)             | Sí                                                                                  |
| 6-8   | GET `/auth/me`, `/sizes`, `/ingredient-categories` | Auth                                | `requireAuth`                             | Sí                                                                                  |
| 9     | GET `/vat-rates`                                   | ADMIN                               | `requireAuth`, `requireRole(ADMIN)`       | Sí                                                                                  |
| 10-11 | GET `/ingredients[/:id]`                           | Auth (el cliente solo ve activos)   | `requireAuth` + filtro en el servicio     | Sí (D-06/PA-B1: el ADMIN necesita `includeInactive=true`; no afecta a la seguridad) |
| 12-15 | POST/PUT/PATCH `/ingredients…`                     | ADMIN                               | `requireRole(ADMIN)`                      | Sí                                                                                  |
| 16-17 | GET `/preset-pizzas[/:id]`                         | Auth                                | `requireAuth` + filtro                    | Sí                                                                                  |
| 18-20 | POST/PUT/PATCH `/preset-pizzas…`                   | ADMIN                               | `requireRole(ADMIN)`                      | Sí                                                                                  |
| 21    | POST `/orders/quote`                               | Auth                                | `requireAuth`                             | Sí                                                                                  |
| 22    | POST `/orders`                                     | CLIENT                              | `requireRole(CLIENT)` + `active` en la BD | Sí                                                                                  |
| 23    | GET `/orders`                                      | Auth (el cliente solo ve los suyos) | filtro `userId` en el servicio            | Sí                                                                                  |
| 24    | GET `/orders/:id`                                  | Dueño o ADMIN                       | `findFirst({id,userId})` → 404            | Sí                                                                                  |
| 25    | PATCH `/orders/:id/status`                         | ADMIN                               | `requireRole(ADMIN)` + transiciones       | Sí                                                                                  |

## 7. Resultados reales de las herramientas

### 7.1 `cd backend && npm audit` (exit 1)

```
@vitest/mocker  <=4.1.11        Severity: moderate  (GHSA-82fw-gwwq-j7x9, GHSA-qxg6-89mg-rqv8)
  vitest  <=4.1.10 ; @vitest/coverage-v8  <=3.2.7
deepmerge-ts  <8.0.0            Severity: high      (GHSA-ggr8-5vv4-36mx)  fix available via `npm audit fix`
  @prisma/config 6.13.0-dev.1 - 7.10.0 ; prisma 6.13.0-dev.1 - 7.10.0
esbuild  <=0.24.2               Severity: moderate  (GHSA-67mh-4wv8-2f99)
  vite <=6.4.3 ; vite-node <=2.2.0-beta.2
glob  9.0.0 - 14.0.1            Severity: moderate  (GHSA-3g3m-2fjr-6pw4)
  test-exclude >=7.0.0
minimatch  7.0.0 - 11.0.0       Severity: moderate  (GHSA-g3hv-75wg-m249)
tinypool  <=2.1.1               Severity: critical  (GHSA-5gmw-xhrv-c9v3, GHSA-85c8-ppgw-ccpr)
zod  <4.6.6                     Severity: high      (GHSA-mrhx-c7xc-m3w5)  fix: zod@4.6.7 (breaking)

14 vulnerabilities (6 moderate, 5 high, 3 critical)
```

### 7.2 `cd backend && npm audit --omit=dev` (exit 1)

```
deepmerge-ts  <8.0.0   Severity: high  (GHSA-ggr8-5vv4-36mx)  fix available via `npm audit fix`
  @prisma/config 6.13.0-dev.1 - 7.10.0 || 8.1.0-dev.1 - 8.1.0-dev.4
    prisma 6.13.0-dev.1 - 7.10.0 || 8.0.0-rc.3 - 8.1.0-dev.4
zod  <4.6.6            Severity: high  (GHSA-mrhx-c7xc-m3w5)  fix: zod@4.6.7 (breaking)

4 high severity vulnerabilities
```

Versiones instaladas (`npm ls`): `express@4.22.3`, `helmet@8.3.0`, `cors@2.8.6`, `express-rate-limit@7.5.1`, `jsonwebtoken@9.0.3`, `bcryptjs@2.4.3`, `pino@9.14.0`, `@prisma/client@6.19.3`, `prisma@6.19.3`, `zod@3.25.76`, `deepmerge-ts@7.1.5`. Node `v24.13.1`.

**Clasificación por alcance real:**

| Paquete                                               | Severidad npm      | Alcance                                       | Se alcanza desde HTTP        | Severidad efectiva |
| ----------------------------------------------------- | ------------------ | --------------------------------------------- | ---------------------------- | ------------------ |
| zod 3.25.76                                           | Alta               | Producción                                    | Sí, con autenticación (S-05) | Media              |
| deepmerge-ts 7.1.5 (prisma CLI)                       | Alta               | CLI (aparece como producción por el peer)     | No                           | Baja               |
| tinypool, vitest, @vitest/mocker, @vitest/coverage-v8 | Crítica / moderada | Solo pruebas                                  | No                           | Baja               |
| vite, vite-node, esbuild                              | Moderada           | Solo pruebas (no se levanta servidor de Vite) | No                           | Info               |
| glob, minimatch, test-exclude                         | Moderada           | Solo cobertura                                | No                           | Info               |

### 7.3 `cd frontend && flutter pub outdated` (exit 0)

```
Package Name              Current  Upgradable  Resolvable  Latest
direct dependencies: all up-to-date.
dev_dependencies: all up-to-date.
transitive dependencies:
code_assets               *1.2.1   2.2.0       2.2.0       2.2.0
hooks                     *2.0.2   2.2.0       2.2.0       2.2.0
material_color_utilities  *0.13.0  *0.13.0     *0.13.0     0.13.1
meta                      *1.18.3  1.19.0      1.19.0      1.19.0
objective_c               *9.5.0   9.6.3       9.6.3       9.6.3
petitparser               *7.0.2   7.1.0       7.1.0       7.1.0
record_use                *0.6.0   1.1.1       1.1.1       1.1.1
test_api                  *0.7.12  *0.7.12     *0.7.12     0.7.15
vector_math               *2.4.0   2.4.4       2.4.4       2.4.4
xml                       *7.0.1   *7.0.1      *7.0.1      7.1.0
7 upgradable dependencies are locked (in pubspec.lock) to older versions.
```

Conclusión: todas las dependencias directas (`flutter_riverpod`, `go_router`, `dio`, `flutter_secure_storage` 11.2.0 / `_windows` 4.2.2, `flutter_svg`, `intl`) están al día. Las transitivas desactualizadas son de build o de pruebas y no tienen avisos conocidos (no hay un `audit` oficial para pub; no lo pude contrastar con una base de avisos). Recomendación: `flutter pub upgrade` en la próxima ventana de mantenimiento.

### 7.4 Pruebas de seguridad existentes, ejecutadas en esta fase

```
$ cd backend && npx vitest run tests/api/security.test.js tests/api/endpoints.test.js tests/api/flows.inprocess.test.js tests/unit/auth.service.test.js tests/unit/utils.test.js
 ✓ tests/api/endpoints.test.js (60 tests)
 ✓ tests/api/flows.inprocess.test.js (45 tests)
 ✓ tests/unit/auth.service.test.js (12 tests)
 ✓ tests/unit/utils.test.js (12 tests)
 ✓ tests/api/security.test.js (5 tests)
 Test Files  5 passed (5)
      Tests  134 passed (134)

$ cd frontend && flutter test test/core/auth_interceptor_test.dart test/core/router_test.dart
00:03 +19: All tests passed!
```

(Se ejecutó `npx vitest` directamente, no `npm test`, para **no** cargar `.env.local`: `vitest.config.js` aporta valores fijos de prueba y `setup.js` fuerza una URL de BD inválida.)

## 8. Lo que NO pude verificar

- Los valores reales de `backend/.env.local` (secretos JWT, `NODE_ENV`, `CORS_ORIGINS`, límites): son la base de C1 y S-01.
- Los privilegios del rol de PostgreSQL usado por la app y por las pruebas (S-17).
- La concurrencia y el SQL real (`FOR UPDATE`, CHECK, secuencia): las 22 pruebas de integración se omiten sin `DATABASE_URL_TEST` (D-05 de QA). La revisión del código no encontró defectos, pero no hay prueba ejecutada contra PostgreSQL.
- Dónde guarda `flutter_secure_storage_windows` 4.2.2 los datos (Credential Manager o archivo cifrado con DPAPI) ni si otro usuario de Windows puede leerlos; no se ejecutó la app real.
- Si Prisma 6 escapa `%` y `_` en `contains` (S-16) y qué contiene exactamente un `PrismaClientValidationError` registrado (S-12).
- El comportamiento real con `?page` enorme (S-13).
- Si las reglas `deny` de `Read()` en `settings.json` también aplican a las herramientas Grep y Glob (H-02).
- Avisos de seguridad de los paquetes pub (no hay `audit` oficial).
- Copias de seguridad de la BD y su cifrado (fuera del repositorio).

## 9. Preguntas abiertas

1. **C1:** ¿`backend/.env.local` tiene secretos JWT aleatorios de 32 caracteres o más y distintos? ¿Se ejecutará la API con `NODE_ENV=production` en el local?
2. **Modelo de operación (S-02/S-03):** ¿los clientes se registran y piden en **un solo PC compartido** del local, en el mismo usuario de Windows que el administrador, o cada cliente usa su propio dispositivo? ¿Cuántos puestos hay? De esto dependen el ajuste de los límites y el cierre de sesión por inactividad.
3. **Red (S-04):** ¿la API debe ser accesible desde otros equipos de la red del local o basta con `localhost`?
4. **S-06:** ¿se acepta un tope de pizzas por pedido y por cliente? ¿Se quiere que el administrador pueda cancelar un pedido y devolver el stock? Hoy el contrato (S-20) lo excluye.
5. **D-03 / S-07:** ¿es aceptable que un usuario desactivado conserve acceso hasta 15 minutos, dado que no existe endpoint de desactivación?
6. **S-08/S-09:** ¿se autoriza `npm audit fix` (modifica `package-lock.json`, protegido por hook) y planificar la migración a Zod 4 y Vitest 5?
7. **H-01..H-04:** ¿se autoriza ajustar `.claude/settings.json` y los hooks? Requiere decisión del usuario; ningún agente debe hacerlo por su cuenta.
