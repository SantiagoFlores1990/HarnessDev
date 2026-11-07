# Runbook — Good Pizza (operación local)

- **Proyecto:** Good Pizza · rama `testHarness` · **Versión:** 0.1.0 · **Fecha:** 2026-11-06
- **Audiencia:** responsable del PC del local (operador) y desarrollador de mantenimiento.
- **Alcance:** operación de la API Node.js, la base PostgreSQL `pizzeria` y la app Flutter para Windows, todo en **un mismo PC**. No cubre Docker, CI ni despliegue en la nube (fase 8 omitida, fuera de alcance).

> **Regla general:** nunca copies valores de `backend/.env.local` (contraseñas, secretos JWT, URLs con credenciales) a chats, tickets, capturas ni logs. En este runbook las credenciales aparecen como `<USUARIO>`, `<CONTRASENA>` y `<SECRETO>`.

---

## 1. Componentes y orden de arranque

| Componente     | Dónde vive                               | Cómo se opera                                                                    |
| -------------- | ---------------------------------------- | -------------------------------------------------------------------------------- |
| PostgreSQL 17  | Servicio de Windows en el PC del local   | Administrado por el sistema operativo (nombre del servicio según tu instalación) |
| API Good Pizza | `backend/` (Node.js 20+, Express)        | `npm start` (producción local) o `npm run dev` (desarrollo)                      |
| App Windows    | `frontend/` (Flutter) o `good_pizza.exe` | Se abre en la sesión del usuario; apunta a la API por `API_URL`                  |

**Orden:** 1) PostgreSQL → 2) API (comprobar `health`) → 3) app Windows.
**Orden inverso para parar:** 1) cerrar la app → 2) parar la API (Ctrl+C) → 3) PostgreSQL solo si hace falta (mantenimiento).

---

## 2. Arranque y parada

### 2.1 Arrancar la API

```bash
cd backend
npm start
```

- `npm start` ejecuta `dotenv -e .env.local -- node src/server.js`: carga `backend/.env.local` y arranca sin recarga automática.
- En el PC del local usa `NODE_ENV=production` en `.env.local` (condición C1 de seguridad: la validación de secretos JWT solo se aplica en `production`).
- Mensaje de arranque correcto (log JSON por stdout): `Good Pizza API escuchando en /api/v1`, con `port` y `env`.
- Si la configuración es inválida, el proceso termina con código 1 y muestra `Configuración inválida ...` seguido de los **nombres** de las variables afectadas. Nunca muestra valores.

### 2.2 Parar la API

- En la ventana de la API: **Ctrl+C**. El proceso captura `SIGINT`/`SIGTERM`, cierra el servidor HTTP y desconecta Prisma antes de salir.
- Si el proceso no responde, cerrar la ventana de terminal es el último recurso. Las transacciones en curso se revierten en PostgreSQL.

### 2.3 Arrancar la app Windows

- Desarrollo: `cd frontend` y `flutter run -d windows`.
- Ejecutable: `frontend\build\windows\x64\runner\Release\good_pizza.exe` (generado con `flutter build windows --release --dart-define=API_URL=...`).
- La URL de la API se fija al compilar (`API_URL`, por defecto `http://localhost:3000/api/v1`). Si cambia la IP o el puerto del PC de la API, hay que recompilar.

### 2.4 Arrancar PostgreSQL

Usa el servicio de Windows de tu instalación (Servicios → `postgresql-x64-17` o el nombre que aparezca en tu equipo). Comprobar que escucha en el puerto `5432` del host `localhost`.

---

## 3. Salud del servicio

### 3.1 Endpoint de salud

`GET http://localhost:3000/api/v1/health` (público, sin token).

| Situación                              | HTTP | Respuesta                                                                                         |
| -------------------------------------- | ---- | ------------------------------------------------------------------------------------------------- |
| API y base de datos correctas          | 200  | `{"data":{"status":"ok","database":"ok","version":"0.1.0","time":"<ISO-8601>"}}`                  |
| La base no responde (`SELECT 1` falla) | 503  | `{"error":{"code":"SERVICE_UNAVAILABLE","message":"La base de datos no responde.","details":[]}}` |
| La API no está levantada               | —    | La conexión falla (la app muestra "No se pudo conectar con el servidor…")                         |

Comprobación desde PowerShell (no requiere credenciales):

```powershell
Invoke-RestMethod http://localhost:3000/api/v1/health
```

### 3.2 Comprobaciones rápidas

- Ruta inexistente o método no definido: `404 ROUTE_NOT_FOUND`. Es el comportamiento correcto (no hay `DELETE` de ingredientes ni de predefinidas).
- Puerto ocupado (`EADDRINUSE`): localizar el proceso con `netstat -ano | findstr :3000` y cerrarlo, o cambiar `PORT` en `.env.local` y recompilar la app con el nuevo `API_URL`.

### 3.3 Monitoreo (estado actual)

No hay herramienta de monitoreo ni alertas integradas. Lo que existe hoy:

- El endpoint `/health` (sondear manualmente o con el Programador de tareas de Windows con `Invoke-RestMethod`; no está configurado en el repositorio).
- Los logs de la API (sección 9).
- El estado del servicio de PostgreSQL en Servicios de Windows.
- Espacio libre en disco para las copias de seguridad (sección 6).

La automatización del monitoreo está en el backlog (`docs/09-maintenance/backlog.md`, deuda técnica).

---

## 4. Variables de entorno

Las variables se definen en `backend/.env.local`, creado a partir de `backend/env.template`. El archivo **no se versiona** y **no se lee con herramientas de IA**. Para cambiar un valor, edítalo con un editor de texto.

| Variable                                       | Obligatoria             | Valor de referencia (sin secretos)                                          | Notas operativas                                                             |
| ---------------------------------------------- | ----------------------- | --------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `NODE_ENV`                                     | no (def. `development`) | `production` en el PC del local                                             | Con `production` se exigen secretos JWT de 32 o más caracteres y distintos.  |
| `PORT`                                         | no (def. `3000`)        | `3000`                                                                      | Cambiarlo obliga a recompilar la app con el nuevo `API_URL`.                 |
| `DATABASE_URL`                                 | **sí**                  | `postgresql://<USUARIO>:<CONTRASENA>@localhost:5432/pizzeria?schema=public` | Si la contraseña tiene `@ : / # %`, codifícala en la URL.                    |
| `DATABASE_URL_TEST`                            | solo pruebas con BD     | `postgresql://<USUARIO>:<CONTRASENA>@localhost:5432/pizzeria?schema=test`   | Debe terminar en `?schema=test`. Nunca `public`.                             |
| `JWT_SECRET`                                   | **sí**                  | `<SECRETO>` (aleatorio, ≥ 32 caracteres)                                    | Firma los access tokens. Ver sección 5.                                      |
| `JWT_REFRESH_SECRET`                           | **sí**                  | `<SECRETO>` distinto de `JWT_SECRET`                                        | Firma los refresh tokens. Ver sección 5.                                     |
| `JWT_ACCESS_EXPIRES_IN`                        | no (def. `15m`)         | `15m`                                                                       | Vida del access token.                                                       |
| `JWT_REFRESH_EXPIRES_IN`                       | no (def. `7d`)          | `7d`                                                                        | Vida de la sesión renovable.                                                 |
| `BCRYPT_COST`                                  | no (def. `12`)          | `12`                                                                        | Mínimo 12 fuera de pruebas.                                                  |
| `CORS_ORIGINS`                                 | no                      | `http://localhost:3000`                                                     | Lista blanca para navegadores. La app Windows no envía `Origin` y se acepta. |
| `RATE_LIMIT_WINDOW_MS`                         | no (def. `900000`)      | `900000`                                                                    | Ventana de 15 minutos.                                                       |
| `RATE_LIMIT_MAX`                               | no (def. `300`)         | `300`                                                                       | Límite global **por IP**; en un PC todos comparten la IP (S-02).             |
| `AUTH_RATE_LIMIT_MAX`                          | no (def. `10`)          | `10`                                                                        | Límite de login, registro y refresh **por IP** (S-02).                       |
| `LOG_LEVEL`                                    | no (def. `info`)        | `info`                                                                      | `fatal`, `error`, `warn`, `info`, `debug`, `trace` o `silent`.               |
| `SEED_ADMIN_EMAIL` / `SEED_CLIENT_EMAIL`       | no                      | `admin@goodpizza.local` / `cliente@goodpizza.local`                         | Solo los usa el seed.                                                        |
| `SEED_ADMIN_PASSWORD` / `SEED_CLIENT_PASSWORD` | no                      | `<CONTRASENA>`                                                              | Solo los usa el seed. Si faltan, el seed genera contraseñas aleatorias.      |

Variables informativas (`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_SCHEMA`): Prisma no las usa. Mantenlas coherentes con `DATABASE_URL` para no confundir a quien opere el sistema.

---

## 5. Rotación de secretos

### 5.1 Secretos JWT (`JWT_SECRET`, `JWT_REFRESH_SECRET`)

**Efecto:** cambiar cualquiera de los dos secretos invalida **todos** los tokens emitidos. Todos los usuarios deben iniciar sesión de nuevo. Es el procedimiento ante una sospecha de filtración.

**Procedimiento:**

1. Generar dos valores nuevos, distintos entre sí (ejecuta el comando dos veces y no los guardes en ningún archivo del repositorio):
   ```bash
   node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
   ```
2. Parar la API (sección 2.2).
3. Editar `backend/.env.local` y reemplazar `JWT_SECRET` y `JWT_REFRESH_SECRET`. Confirmar que `NODE_ENV=production`.
4. Arrancar la API (`npm start`) y comprobar `health` (sección 3.1).
5. Cerrar y volver a abrir la app Windows: el usuario verá "Tu sesión expiró. Inicia sesión de nuevo".
6. Anotar la fecha de la rotación en el registro de operación (fuera del repositorio).

**Qué NO hacer:** no reutilizar los valores de `env.template` (`change-me`, `change-me-too`), no usar el mismo valor en ambos secretos, y no acortarlos por debajo de 32 caracteres.

**Periodicidad:** no está definida (pregunta abierta, sección 12).

### 5.2 Contraseña de PostgreSQL

1. Cambiar la contraseña del rol en PostgreSQL con el procedimiento de tu administración de la base. No escribas la contraseña nueva en el historial del terminal: usa `\password` dentro de `psql`, que la pide de forma interactiva.
2. Actualizar `DATABASE_URL` (y `DATABASE_URL_TEST` si existe) en `.env.local`.
3. Reiniciar la API y comprobar `health`.

### 5.3 Contraseñas de usuario

- **No hay funcionalidad de cambio de contraseña ni de gestión de usuarios** en la API ni en la app (fuera de alcance del contrato). La contraseña de un usuario existente no la cambia el seed.
- El procedimiento actual para el administrador es una intervención controlada sobre la base de datos, pendiente de definir (backlog). Mientras tanto, no se debe improvisar un `UPDATE` sobre `users`.

---

## 6. Respaldo y restauración de PostgreSQL

### 6.1 Qué respaldar

- Esquema **`public`**: datos reales del local (pedidos, catálogo, usuarios con hash de contraseña, historial de estados, tabla `_prisma_migrations`).
- Esquema **`test`**: datos de pruebas. **No es necesario respaldarlo** y se puede recrear (sección 8).

Los respaldos contienen datos personales (nombres, emails) y hashes de contraseña. Guárdalos en una ubicación restringida y con acceso solo para el responsable.

### 6.2 Contraseña sin escribirla

Usa una de estas dos opciones; ninguna deja la contraseña en el código, en `.env.local` ni en el historial de comandos:

- **Opción A (recomendada):** `pg_dump` con `-W`. Pedirá la contraseña en el terminal.
- **Opción B:** archivo `pgpass.conf` de tu usuario de Windows (`%APPDATA%\postgresql\pgpass.conf`), con una línea con el formato `localhost:5432:pizzeria:<USUARIO>:<CONTRASENA>`. Crea el archivo tú; no lo guardes en el repositorio.

Si `pg_dump`, `pg_restore` o `psql` no se reconocen, añade la carpeta `bin` de PostgreSQL al `PATH` (por ejemplo `C:\Program Files\PostgreSQL\17\bin`; ajusta la ruta a tu instalación).

### 6.3 Copia de seguridad (formato personalizado, comprimido)

```powershell
pg_dump -h localhost -p 5432 -U <USUARIO> -d pizzeria -n public -Fc -W -f "D:\respaldos\goodpizza\pizzeria_public_AAAAMMDD_HHMM.dump"
```

- `-n public` excluye el esquema `test`.
- `-Fc` genera un archivo binario comprimido, restaurable con `pg_restore`.
- Crea antes la carpeta de destino.

**Verificar la copia** (lista el contenido sin restaurar nada):

```powershell
pg_restore --list "D:\respaldos\goodpizza\pizzeria_public_AAAAMMDD_HHMM.dump" | Select-Object -First 20
```

**Copia en texto plano (alternativa):**

```powershell
pg_dump -h localhost -p 5432 -U <USUARIO> -d pizzeria -n public -W -f "D:\respaldos\goodpizza\pizzeria_public_AAAAMMDD_HHMM.sql"
```

### 6.4 Restauración de prueba (recomendada periódicamente)

Restaura siempre en una base **nueva**, nunca sobre `pizzeria`, para comprobar que el respaldo sirve:

```powershell
createdb -h localhost -p 5432 -U <USUARIO> -W pizzeria_restore_check
pg_restore -h localhost -p 5432 -U <USUARIO> -W -d pizzeria_restore_check --no-owner "D:\respaldos\goodpizza\pizzeria_public_AAAAMMDD_HHMM.dump"
```

Para la versión en texto plano: `psql -h localhost -p 5432 -U <USUARIO> -W -d pizzeria_restore_check -f "...\pizzeria_public_AAAAMMDD_HHMM.sql"`.

Comprobaciones tras la restauración de prueba: `\dt` debe listar las 15 tablas del modelo más `_prisma_migrations`; `SELECT count(*) FROM ingredients;` debe devolver el número esperado. Después borra la base de prueba con `dropdb -h localhost -U <USUARIO> -W pizzeria_restore_check`.

### 6.5 Restauración real (solo con autorización del responsable)

Es una operación destructiva. Solo se hace si el responsable lo decide por escrito:

1. Parar la API y cerrar las apps Windows.
2. Hacer una copia del estado actual (sección 6.3), aunque esté dañado.
3. Restaurar **solo el esquema `public`** con las opciones de limpieza, sobre `pizzeria`. Ejemplo: `pg_restore --clean --if-exists -n public -h localhost -U <USUARIO> -W -d pizzeria "<archivo>.dump"`. Revisa antes la salida de `pg_restore --list`.
4. Verificar: `GET /api/v1/health` y un inicio de sesión con un usuario conocido.
5. Anotar el incidente (sección 10).

---

## 7. Migraciones de Prisma

### 7.1 Estado actual

- Migraciones del repositorio: `20261106185922_init`, `20261106185930_init` (vacía, ya aplicada) y `20261106190500_add_check_constraints`. Las tres están aplicadas en `pizzeria` según el entregable de la fase 4.
- Verificar el estado sin modificar nada:

  ```bash
  cd backend
  npx dotenv -e .env.local -- prisma migrate status
  ```

### 7.2 Aplicar migraciones en el local

```bash
cd backend
npm run db:deploy
```

`db:deploy` aplica solo las migraciones pendientes. Es la opción correcta para el PC del local. Antes de aplicar, haz una copia de seguridad (sección 6.3).

### 7.3 Crear migraciones (solo en desarrollo)

`npm run db:migrate` ejecuta `prisma migrate dev`. Crea migraciones nuevas y puede proponer un reset si detecta divergencias. **En el local, responde no a cualquier propuesta de reset.** Crear una migración nueva exige revisarla y probarla antes, en la base de pruebas (sección 8).

### 7.4 Reglas

- **No edites una migración ya aplicada.** La migración de CHECK se añadió como migración nueva porque `init` ya estaba aplicada: esa es la práctica a seguir.
- No ejecutes `prisma migrate reset` sobre `pizzeria`.
- Si una migración falla a medias, no la reintentes a ciegas: revisa el error, decide con el responsable y, si es necesario, restaura desde la copia (sección 6.5).

---

## 8. Esquema de pruebas `test`

### 8.1 Qué es

El esquema `test` vive dentro de la misma base `pizzeria` y lo usan solo las pruebas de integración. Las pruebas comprueban que la URL termina en `?schema=test` y que `current_schema()` es `test` antes de tocar nada. Con esas barreras, la base `public` no se modifica.

### 8.2 Crear o actualizar el esquema de pruebas

```bash
cd backend
npm run db:test:migrate
```

El script se niega a ejecutarse si `DATABASE_URL_TEST` no existe o no apunta a `?schema=test`.

### 8.3 Reiniciar el esquema de pruebas

Úsalo cuando el esquema de pruebas quede inconsistente. No suele hacer falta: cada ejecución de las pruebas de integración vacía sus tablas.

1. Comprobar que el nombre del esquema es exactamente `test`:
   ```powershell
   psql -h localhost -p 5432 -U <USUARIO> -W -d pizzeria -c "\dn"
   ```
2. Eliminar **solo** el esquema `test` y recrearlo vacío:
   ```powershell
   psql -h localhost -p 5432 -U <USUARIO> -W -d pizzeria -c "DROP SCHEMA test CASCADE;" -c "CREATE SCHEMA test;"
   ```
3. Volver a migrar: `npm run db:test:migrate`.
4. Ejecutar `npm test` en `backend/`.

**Nunca** sustituyas `test` por `public` en estos comandos. Si la lista de `\dn` no muestra `test` con certeza, no ejecutes el paso 2.

---

## 9. Logs

### 9.1 Dónde están

- La API escribe **JSON por la salida estándar** (pino). No hay fichero de logs ni rotación.
- Para guardarlos, arranca así (sustituye la ruta):
  ```powershell
  npm start *>> "D:\logs\goodpizza\api.log"
  ```
  Crea la carpeta antes. Vigila el tamaño del fichero: no hay rotación.

### 9.2 Qué contienen

- Arranque (`Good Pizza API escuchando en /api/v1`) y cierre (`Cerrando servidor`).
- Errores no controlados: `Error no controlado`, con `err.name`, `err.message`, `err.stack` y `path`. El `stack` puede incluir fragmentos de consultas (S-12).
- Lo que **no** se registra: cabeceras, cuerpos ni query strings de las peticiones. Pino redacta `authorization`, `password`, `refreshToken` y `accessToken`.

### 9.3 Buscar incidencias

```powershell
Select-String -Path "D:\logs\goodpizza\api.log" -Pattern "Error no controlado" | Select-Object -Last 20
```

Nivel de log: `LOG_LEVEL=info` es el valor normal. Usa `debug` solo durante una incidencia y vuelve a `info` después. No compartas logs con `stack` fuera del equipo.

### 9.4 Otros registros

- `.claude/logs/events.jsonl` es la bitácora de Claude Code, no de la aplicación. No está versionada.
- Los errores de la app Windows se muestran en pantalla; no se escriben en disco.

---

## 10. Incidentes típicos y solución

| Síntoma                                                                       | Causa probable                                                               | Diagnóstico                                                | Solución                                                                                                           |
| ----------------------------------------------------------------------------- | ---------------------------------------------------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| La API no arranca y muestra `Configuración inválida ... (falta)`              | Falta una variable obligatoria en `.env.local`                               | El mensaje indica el **nombre** de la variable             | Añadir la variable (ver sección 4). No copiar valores en tickets.                                                  |
| La API no arranca: `mínimo 32 caracteres` o `debe ser distinto de JWT_SECRET` | `NODE_ENV=production` con secretos débiles                                   | Mensaje con el nombre del secreto                          | Generar secretos nuevos (sección 5.1).                                                                             |
| `health` responde 503 `SERVICE_UNAVAILABLE`                                   | PostgreSQL parado, host, puerto o credenciales incorrectos en `DATABASE_URL` | Revisar el servicio de PostgreSQL y la URL (sin mostrarla) | Iniciar PostgreSQL; corregir `DATABASE_URL`; reiniciar la API.                                                     |
| `EADDRINUSE` al arrancar                                                      | Otro proceso usa el puerto (3000 por defecto)                                | `netstat -ano \| findstr :3000`                            | Cerrar el proceso o cambiar `PORT` y recompilar la app.                                                            |
| La app muestra "No se pudo conectar con el servidor"                          | La API no está levantada, o `API_URL` apunta a otro sitio                    | `Invoke-RestMethod <API_URL>/health`                       | Arrancar la API o recompilar con el `API_URL` correcto.                                                            |
| Todos los usuarios reciben `429 RATE_LIMITED`                                 | Límite por IP compartido en un PC (S-02)                                     | Cabecera de límite; muchos intentos de login               | Esperar 15 minutos o reiniciar la API (el contador está en memoria). Ver backlog S-02.                             |
| "Email o contraseña incorrectos"                                              | Contraseña errónea (mensaje genérico, por diseño)                            | Verificar el email y la contraseña                         | Si se ha olvidado la contraseña del administrador, ver sección 5.3. No hay recuperación por email.                 |
| "Tu sesión expiró. Inicia sesión de nuevo."                                   | Refresh caducado (7 días), revocado o secretos rotados                       | Esperado tras rotar secretos                               | Iniciar sesión de nuevo.                                                                                           |
| Varias sesiones cerradas a la vez en un usuario                               | Se reutilizó un refresh token (se revocan todos los del usuario)             | Revisar logs y la actividad del usuario                    | Tratar como posible robo de sesión: rotar `JWT_*` (sección 5.1) y revisar la cuenta.                               |
| `403 FORBIDDEN` "Tu cuenta está desactivada"                                  | Usuario con `active = false`                                                 | Consulta de la cuenta en la base (solo lectura)            | Reactivar con el procedimiento aprobado. No hay endpoint de gestión de usuarios.                                   |
| `409 INSUFFICIENT_STOCK` al confirmar                                         | Stock agotado (o pedido concurrente)                                         | El mensaje indica ingrediente, solicitado y disponible     | Ajustar el stock desde Ingredientes (Ajustar stock) o pedir al cliente que ajuste el pedido.                       |
| `409 PRICE_CHANGED` al confirmar                                              | Cambió el precio entre la cotización y la confirmación                       | Es el comportamiento esperado                              | El cliente revisa el pedido y acepta el nuevo total.                                                               |
| `422 MISSING_SIZE_VALUES` al activar un ingrediente                           | Faltan precio o calorías de algún tamaño                                     | Mensaje con el tamaño afectado                             | Completar los tres tamaños en Editar ingrediente.                                                                  |
| `500 INTERNAL_ERROR`                                                          | Error no controlado                                                          | Buscar `Error no controlado` en el log (sección 9.3)       | Corregir la causa; si se repite, abrir incidencia en el backlog.                                                   |
| `404 ROUTE_NOT_FOUND`                                                         | Ruta o método que no existen                                                 | Revisar la petición                                        | Esperado para `DELETE`. No es un fallo.                                                                            |
| `seed` falla con `Error en el seed`                                           | Base sin migrar, o variable de seed incorrecta                               | Leer el mensaje del error                                  | Ejecutar `npm run db:deploy` antes; revisar `SEED_*`.                                                              |
| Las pruebas muestran 22 omitidas                                              | `DATABASE_URL_TEST` no definida                                              | Aviso `[AVISO] DATABASE_URL_TEST no está definida`         | Sección 8 (definir la variable y `db:test:migrate`). Es el estado actual.                                          |
| Pruebas de integración fallan con "aborta: no es schema test"                 | URL de prueba sin `?schema=test`                                             | Mensaje del setup                                          | Corregir `DATABASE_URL_TEST`. El fallo es la barrera de seguridad funcionando.                                     |
| `migrate deploy` falla o queda una migración a medias                         | Error de SQL o de permisos                                                   | Revisar `prisma migrate status`                            | No reintentar a ciegas. Decidir con el responsable; restaurar si es necesario (sección 6.5).                       |
| La fecha o el número de orden no corresponden al día                          | Zona horaria del sistema operativo (S-24)                                    | `Get-TimeZone`                                             | Ajustar la zona horaria de Windows; el número usa la fecha del servidor.                                           |
| La app no compila: `atlstr.h`                                                 | Falta el componente ATL de Visual Studio                                     | Error `C1083` al compilar `flutter_secure_storage_windows` | Instalar "C++ ATL para las últimas herramientas de compilación v143 (x86 y x64)", luego `flutter clean` y repetir. |
| `Building with plugins requires symlink support`                              | Modo desarrollador desactivado                                               | Mensaje de Flutter                                         | Activar el modo desarrollador en Windows y reabrir la terminal.                                                    |
| En un PC compartido, el siguiente usuario ve la sesión anterior               | Sesión persistente (S-03)                                                    | La app abre directamente                                   | El usuario anterior debe cerrar sesión (Ctrl+Shift+Q). Decisión pendiente en el backlog.                           |

---

## 11. Qué NO hacer sobre la base `public`

- No ejecutar `prisma migrate reset`, `prisma db push --force-reset` ni `DROP SCHEMA public`.
- No ejecutar `TRUNCATE` ni `DELETE` sobre tablas del modelo (pedidos, catálogo, usuarios) salvo que el responsable lo apruebe por escrito y exista copia de seguridad.
- No ejecutar `npm run db:seed` como "reinicio": es idempotente, pero no restaura datos editados ni cambia contraseñas de usuarios existentes.
- No apuntar `DATABASE_URL_TEST` ni las pruebas a `public`.
- No borrar ingredientes: los ingredientes solo se desactivan (S-23). Las claves foráneas lo impiden de todos modos (`onDelete: Restrict`).
- No editar una migración que ya está aplicada.
- No usar los agentes de Claude Code para operar sobre la base real mientras no se corrija H-01 (los permisos actuales permiten ejecutar `prisma migrate reset`, `db push` y `npm run db:seed` sin confirmación).
- No compartir `backend/.env.local`, ni capturas que muestren sus valores, ni copias de seguridad fuera del equipo sin cifrar.

---

## 12. Mantenimiento periódico

| Tarea                                        | Frecuencia sugerida                     | Comando o acción                                                 | Responsable                                |
| -------------------------------------------- | --------------------------------------- | ---------------------------------------------------------------- | ------------------------------------------ |
| Copia de seguridad de `public`               | Diaria (propuesta; no hay programación) | Sección 6.3                                                      | Operador del local                         |
| Restauración de prueba en base nueva         | Mensual (propuesta)                     | Sección 6.4                                                      | Responsable técnico                        |
| Revisión de `health` y logs de errores       | Semanal (propuesta)                     | Secciones 3 y 9                                                  | Operador                                   |
| Auditoría de dependencias                    | Por cada cambio de dependencias         | `npm audit` en `backend/`; `flutter pub outdated` en `frontend/` | Desarrollador                              |
| Revisión de avisos de seguridad (S-08, S-09) | Según backlog                           | Ver `docs/09-maintenance/backlog.md`                             | Desarrollador con autorización del usuario |
| Rotación de secretos JWT                     | Ante sospecha; periodicidad pendiente   | Sección 5.1                                                      | Responsable                                |

Las frecuencias marcadas como "propuesta" no están aprobadas por el usuario.

---

## 13. Preguntas abiertas (operación)

1. **Objetivos de recuperación:** ¿cuánto dato se puede perder (RPO) y cuánto tiempo puede estar parado el servicio (RTO)?
2. **Copias:** ¿dónde se guardan, cuánto tiempo se conservan y si deben salir del PC (copia externa cifrada)?
3. **Periodicidad de rotación de secretos JWT** y de contraseñas de la base.
4. **Cambio de contraseña del administrador:** ¿se necesita una función en la app o basta un procedimiento controlado sobre la base?
5. **Modelo de operación:** ¿los clientes usan un PC compartido, y el administrador comparte cuenta de Windows con ellos? Afecta a la sesión persistente (S-03) y a los incidentes de sesión.
6. **Red:** ¿la API debe ser accesible desde otros equipos del local? Afecta al puerto, al firewall y a `API_URL` (S-04).
7. **Monitoreo:** ¿se quiere alerta automática cuando `health` no responda?
