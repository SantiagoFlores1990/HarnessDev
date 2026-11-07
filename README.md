# HarnessDev — Plantilla de fábrica de software con Claude Code

> Rama `testHarness`: la aplicación generada es **Good Pizza**. Ver la sección [Proyecto Good Pizza (rama testHarness)](#proyecto-good-pizza-rama-testharness) al final de este documento.

Plantilla para construir aplicaciones **full stack monolíticas** (backend Node.js + frontend Flutter móvil y desktop) con agentes de Claude Code. Cada agente es una etapa del ciclo de vida del software y deja sus entregables documentados. La plantilla no contiene ninguna aplicación: la describes tú en un prompt.

## Requisitos

| Herramienta                                      | Versión              | Para qué             |
| ------------------------------------------------ | -------------------- | -------------------- |
| Node.js + npm                                    | 20+                  | Backend y hooks      |
| Git                                              | cualquiera           | Control de versiones |
| PostgreSQL                                       | 15+ (probado con 17) | Base de datos        |
| Flutter SDK                                      | estable reciente     | Frontend             |
| Visual Studio con "Desktop development with C++" | 2022                 | Flutter en Windows   |
| Android Studio / Android SDK                     | SDK 36               | Flutter en Android   |
| Claude Code                                      | con sesión iniciada  | Ejecutar los agentes |

Xcode (macOS) es necesario solo para iOS/macOS; Linux desktop necesita las dependencias de GTK de Flutter.

## Inicio rápido

```bash
git clone <url-del-repositorio> mi-proyecto
cd mi-proyecto
node scripts/setup.js        # verifica herramientas, instala dependencias, crea backend/.env.local
```

1. Edita `backend/.env.local` (`DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DATABASE_URL`, secretos JWT).
2. Crea la base de datos: `psql -U <usuario> -h localhost -c "CREATE DATABASE <nombre>;"`
3. Si usarás Flutter, corre `flutter doctor` y resuelve lo que aparezca en rojo.
4. Abre Claude Code en la raíz (`claude`) y pide tu aplicación:

```
/build-app <describe aquí tu aplicación>
```

`node scripts/setup.js --check` solo verifica herramientas, sin modificar nada.

## Qué hace `/build-app`

Ejecuta los agentes en orden; cada uno lee `docs/` de la etapa anterior y escribe en su carpeta:

| #   | Agente               | Modelo | Salida                            |
| --- | -------------------- | ------ | --------------------------------- |
| 1   | requirements-analyst | Sonnet | `docs/01-requirements/`           |
| 2   | solution-architect   | Opus   | `docs/02-architecture/`           |
| 3   | ux-designer          | Sonnet | `docs/03-design/`                 |
| 4   | backend-dev          | Sonnet | `backend/` + `docs/04-backend/`   |
| 5   | flutter-dev          | Sonnet | `frontend/` + `docs/05-frontend/` |
| 6   | qa-engineer          | Sonnet | `docs/06-qa/`                     |
| 7   | security-reviewer    | Opus   | `docs/07-security/`               |
| 8   | devops-engineer      | Sonnet | Docker, CI, `docs/08-devops/`     |
| 9   | maintenance-docs     | Haiku  | README final, runbook, backlog    |

Cada fase genera 6 entregables (plantillas en `docs/_templates/`): entregable, flujo, diagrama entidad-relación, pruebas unitarias, manual de usuario y documentación técnica. También puedes ejecutar una sola etapa con `/run-stage <agente>`.

## Estructura

```
├── CLAUDE.md                contexto que Claude lee en cada sesión
├── models/                  guía de modelos (sonnet, opus, haiku, fable) y política
├── .claude/
│   ├── settings.json        permisos y hooks
│   ├── agents/              un agente por etapa del SDLC
│   ├── skills/              conocimiento reutilizable (<skill>/SKILL.md)
│   ├── commands/            /build-app, /run-stage
│   └── hooks/               scripts de seguridad, formato y bitácora
├── docs/_templates/         plantillas de entregables
├── docs/01..09-*/           salida de cada etapa
├── backend/                 Node.js + Express + Prisma (+ env.template)
├── frontend/                Flutter (lo genera flutter-dev)
└── scripts/setup.js         configuración del ambiente
```

## Hooks incluidos

| Evento                                 | Script              | Función                                                 |
| -------------------------------------- | ------------------- | ------------------------------------------------------- |
| SessionStart                           | `session-start.js`  | Muestra el avance por etapa                             |
| UserPromptSubmit / Stop / SubagentStop | `log-event.js`      | Bitácora en `.claude/logs/events.jsonl` (no versionada) |
| PreToolUse Bash                        | `guard-bash.js`     | Bloquea comandos destructivos y lectura de `.env`       |
| PreToolUse Edit/Write                  | `protect-files.js`  | Protege `.env*`, `.git`, lockfiles, llaves y los hooks  |
| PostToolUse Edit/Write                 | `format-on-edit.js` | `dart format` / Prettier si están disponibles           |

## Seguridad

- `backend/.env.local` está en `.gitignore`; **nunca** subas credenciales. Solo se versiona `backend/env.template`.
- `settings.json` impide a Claude leer `.env.local`. Los scripts npm lo cargan con `dotenv-cli`.
- Cada desarrollador usa su propia base de datos y sus propios secretos.

## Personalización

- **Otro stack o reglas:** edita `CLAUDE.md`, los agentes en `.claude/agents/` y las skills en `.claude/skills/`.
- **Otro modelo por agente:** cambia `model:` en el frontmatter del agente (ver `models/README.md`).
- **Permisos locales propios:** crea `.claude/settings.local.json` (ignorado por git).

Consulta [CONTRIBUTING.md](CONTRIBUTING.md) para colaborar en la plantilla.

## Licencia

[MIT](LICENSE) © 2026 Santiago Flores.

---

## Proyecto Good Pizza (rama testHarness)

### Qué es

Good Pizza es una aplicación de escritorio para **Windows** (Flutter, Material 3, interfaz en español) con un backend **Node.js + Express + Prisma** sobre **PostgreSQL** (base `pizzeria`). Permite a una pizzería:

- Vender **pizzas predefinidas** (Margarita, Pepperoni, Hawaiana, Vegetariana, 4 Quesos) o **armar una pizza** eligiendo tamaño (Individual, Mediana, Familiar), masa, salsa e ingredientes con cantidad (máximo 3 porciones por ingrediente).
- Ver en vivo **calorías** y **precio** (USD, sin IVA), y en el resumen el IVA desglosado en **Subtotal 15 %**, **Subtotal 0 %**, **IVA 15 %** y **TOTAL**.
- Descontar **stock** al confirmar, con snapshots de precios, calorías e IVA en cada pedido.
- Gestionar el estado del pedido: **Pendiente → En preparación → Entregado** (solo el administrador lo cambia).

El consumo es solo en el local: no hay delivery, pasarela de pago ni cancelación por el cliente. Los datos de ejemplo del seed **no son precios reales**.

**Estado del proyecto:** fases 1 a 7 y 9 completadas. La fase 8 (DevOps/Docker/CI) está **omitida por decisión del usuario** porque Docker no está instalado. Detalle en [CHANGELOG.md](CHANGELOG.md) y en [docs/09-maintenance/entregable.md](docs/09-maintenance/entregable.md).

### Requisitos

| Requisito                        | Detalle                                                                                                                                              |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| Sistema                          | Windows 10/11 de 64 bits (la app solo se compila y ejecuta en Windows)                                                                               |
| Node.js                          | 20 o superior (probado con Node 24.13.1)                                                                                                             |
| PostgreSQL                       | 17, con la base `pizzeria` ya creada y un usuario con permisos sobre ella                                                                            |
| Flutter                          | 3.47.9 (stable) y Dart 3.13.7, con soporte Windows (`flutter doctor` sin errores en rojo)                                                            |
| Visual Studio 2022 o Build Tools | Carga de trabajo **Desarrollo para el escritorio con C++** y el componente **C++ ATL para las últimas herramientas de compilación v143 (x86 y x64)** |
| Modo desarrollador de Windows    | Necesario para los enlaces simbólicos de los plugins de Flutter                                                                                      |

Si `flutter` no está en el PATH, se usa la ruta completa de su instalación (en el equipo de desarrollo: `C:\src\flutter\bin\flutter.bat`).

### Instalación paso a paso

Todos los comandos se ejecutan desde la raíz del repositorio salvo que se indique otra carpeta.

**1. Cambiar a la rama y preparar el entorno**

```bash
git switch testHarness
node scripts/setup.js          # verifica herramientas, instala dependencias y crea backend/.env.local
node scripts/setup.js --check  # alternativa: solo verifica herramientas, no modifica nada
```

`setup.js` crea `backend/.env.local` copiando `backend/env.template` solo si el archivo no existe.

**2. Configurar `backend/.env.local`** (no se versiona; no lo abras con herramientas de IA)

Rellena, como mínimo:

- `DATABASE_URL="postgresql://USUARIO:CONTRASENA@localhost:5432/pizzeria?schema=public"`. Si la contraseña tiene caracteres especiales (`@ : / # %`), codifícalos en URL. Las variables `DB_*` son informativas: Prisma usa `DATABASE_URL`.
- `JWT_SECRET` y `JWT_REFRESH_SECRET`: valores **aleatorios, distintos y de 32 caracteres o más**. Puedes generarlos con:

  ```bash
  node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"
  ```

- `NODE_ENV=production` en el PC del local. Con `production` el arranque rechaza secretos cortos, iguales o los de la plantilla (condición C1 del informe de seguridad; ver "Estado" más abajo).
- Opcional: `SEED_ADMIN_PASSWORD` y `SEED_CLIENT_PASSWORD` (si no existen, el seed genera contraseñas y las imprime **una sola vez**).
- Opcional: `DATABASE_URL_TEST` (ver "Cómo correr las pruebas").

Si falta una variable obligatoria o es inválida, la API termina mostrando solo el **nombre** de la variable.

**3. Migraciones de la base `pizzeria`**

```bash
cd backend
npm install                 # si setup.js no lo hizo
npm run db:generate         # genera el cliente Prisma (db:migrate también lo hace)
npm run db:deploy           # aplica las migraciones existentes sin crear nuevas (uso recomendado en el local)
```

`npm run db:migrate` ejecuta `prisma migrate dev`: sirve para **crear** migraciones durante el desarrollo, no para aplicarlas en el local. Las tres migraciones del proyecto (`init`, `init` vacía y `add_check_constraints`) ya están aplicadas en `pizzeria`. No ejecutes `prisma migrate reset` sobre `pizzeria`.

**4. Datos de ejemplo (seed)**

```bash
cd backend
npm run db:seed
```

El seed es idempotente: crea 2 roles, 3 tamaños, 6 categorías, tarifas de IVA 15 % y 0 %, **20 ingredientes de ejemplo**, las **5 predefinidas**, 1 administrador y 1 cliente. No pisa precios ni stock ya editados, ni cambia la contraseña de un usuario existente. Si no definiste `SEED_*_PASSWORD`, las contraseñas generadas aparecen en consola **una sola vez**: guárdalas.

**5. Arrancar la API**

```bash
cd backend
npm run dev                 # con recarga (node --watch)
# o bien: npm start        # sin recarga
```

La API queda en `http://localhost:3000/api/v1`. Comprobación rápida:

```bash
curl http://localhost:3000/api/v1/health
# -> {"data":{"status":"ok","database":"ok","version":"0.1.0","time":"..."}}
```

**6. Ejecutar la aplicación Windows**

```bash
cd frontend
flutter pub get
flutter run -d windows                                                        # API en http://localhost:3000/api/v1
flutter run -d windows --dart-define=API_URL=http://192.168.1.50:3000/api/v1  # otra API (ejemplo)
flutter build windows --release --dart-define=API_URL=http://localhost:3000/api/v1
```

El ejecutable de `build windows` queda en `frontend/build/windows/x64/runner/Release/good_pizza.exe`. La variable `API_URL` (con `/api/v1` incluido) se lee con `String.fromEnvironment`; por defecto es `http://localhost:3000/api/v1`.

### Usuarios de ejemplo

| Rol           | Email por defecto                                        | Contraseña                                                                  |
| ------------- | -------------------------------------------------------- | --------------------------------------------------------------------------- |
| Administrador | `admin@goodpizza.local` (variable `SEED_ADMIN_EMAIL`)    | La que definiste en `SEED_ADMIN_PASSWORD` o la impresa una vez por el seed  |
| Cliente       | `cliente@goodpizza.local` (variable `SEED_CLIENT_EMAIL`) | La que definiste en `SEED_CLIENT_PASSWORD` o la impresa una vez por el seed |

Cualquier persona puede crear una cuenta de cliente desde la pantalla "Crear cuenta". Las cuentas de administrador solo se crean con el seed.

### Cómo correr las pruebas

**Backend** (desde `backend/`):

```bash
npm test                    # Vitest + Supertest
npm run lint                # ESLint
```

Sin `DATABASE_URL_TEST`, las **22 pruebas de integración con PostgreSQL real** se omiten con un aviso; el resto se ejecuta sin base de datos. Resultado real de la ejecución de QA (fase 6): **267 pruebas pasan, 22 omitidas, 0 fallos**; cobertura de `src/services` 97,11 %.

Para ejecutar también las de integración (concurrencia de stock, secuencia diaria, CHECK, criterios de aceptación contra la base):

1. En `backend/.env.local` añade `DATABASE_URL_TEST` con **tus mismas credenciales** y el esquema `test`:
   `DATABASE_URL_TEST="postgresql://USUARIO:CONTRASENA@localhost:5432/pizzeria?schema=test"`
2. Crea y migra el esquema de pruebas: `npm run db:test:migrate`. Solo toca el esquema `test`: el script se niega si la URL no termina en `?schema=test`.
3. `npm test`.

Las pruebas de integración nunca escriben en `public`: abortan si la URL no apunta a `test` o si `current_schema()` no es `test`.

**Frontend** (desde `frontend/`):

```bash
flutter analyze                                              # sin incidencias
flutter test                                                 # 225 pruebas (unitarias, de widget y de flujo)
flutter test --coverage                                      # cobertura en coverage/lcov.info
flutter test integration_test/app_flow_test.dart -d windows  # 1 prueba de escritorio (repositorios falsos)
```

Las pruebas de frontend no necesitan backend ni base de datos: usan repositorios falsos.

### Estructura del repositorio

```
backend/
  src/                  app.js, server.js, config/, lib/, middlewares/, routes/, controllers/,
                        schemas/ (Zod), services/ (incluye pricing-engine/), utils/
  prisma/               schema.prisma, migrations/ (3), seed.js, seed-lib.js
  scripts/              db-test-migrate.js (migra el esquema test)
  tests/                unit/, api/, integration/, helpers/
  env.template          nombres de variables (sin valores)
frontend/
  lib/                  main.dart, app.dart, core/ (api, config, storage, theme, router, widgets),
                        features/ (auth, catalog, preset_pizzas, pizza_builder, cart, orders, admin)
  assets/brand/         logotipo SVG
  test/, integration_test/
docs/
  01-requirements .. 07-security   entregables de cada fase (6 archivos cada una)
  08-devops                        fase omitida (sin entregables)
  09-maintenance                   entregables finales, runbook, backlog y correcciones pendientes
  prompt-proyecto.md               especificación original (manda)
```

### Arquitectura resumida

- **Monolito** en un repositorio con dos piezas en el mismo PC: la app Windows (Flutter) y la API (Node.js 20, Express, prefijo `/api/v1`).
- **Backend en capas**: `routes → controllers → services → Prisma`. Middlewares: `helmet`, `cors` con lista blanca, `express-rate-limit` (global y de autenticación), límite de 100 KB en el cuerpo, `requireAuth`, `requireRole` y validación con Zod estricta.
- **Motor de cálculo único** (`services/pricing-engine/`, funciones puras): precio, calorías, IVA 15 %/0 % con redondeo half-up sobre el subtotal, reglas de armado y stock. Lo usan la cotización (`POST /orders/quote`), la confirmación (`POST /orders`) y el catálogo de predefinidas. El frontend no reimplementa reglas.
- **Confirmación de pedido** en una transacción: bloqueo `SELECT … FOR UPDATE` ordenado, descuento de stock condicionado (`stock >= n`), número `GP-AAAAMMDD-NNNN` con secuencia diaria y snapshots de precio, calorías e IVA.
- **Autenticación**: JWT de acceso (15 min) y refresh rotativo (7 días) con hash SHA-256 en base de datos; autorización por rol y por dueño del pedido (un pedido ajeno responde 404).
- **Base de datos**: 15 tablas, 3 enums y 9 restricciones CHECK (incluido `stock >= 0`). Dinero en `Decimal`, nunca en `Float`.
- **Frontend**: Riverpod, go_router con guardas por rol, dio con interceptor de autenticación, `flutter_secure_storage` para los tokens, Material 3 en modo claro con paleta azul marino.

Documentación completa: [docs/04-backend/documentacion-tecnica.md](docs/04-backend/documentacion-tecnica.md), [docs/05-frontend/documentacion-tecnica.md](docs/05-frontend/documentacion-tecnica.md) y [docs/09-maintenance/documentacion-tecnica.md](docs/09-maintenance/documentacion-tecnica.md) (consolidado).

### Estado y limitaciones (honesto)

- **Pruebas con PostgreSQL real sin ejecutar**: las 22 de integración se omiten hasta definir `DATABASE_URL_TEST` y ejecutar `npm run db:test:migrate`. La concurrencia real de stock y la secuencia diaria contra la base **no están verificadas**.
- **Seed**: no se ha ejecutado sobre `pizzeria` en el repositorio; el usuario debe ejecutar `npm run db:seed`.
- **`flutter run -d windows` contra el backend real** con datos del seed: no verificado. La compilación de Windows sí funciona (`flutter build windows --debug`) tras instalar el componente ATL; el arranque se verificó con `integration_test` y repositorios falsos.
- **Solo Windows**. Móvil, web, Linux y macOS están fuera de alcance.
- **Sin Docker, DevOps ni CI**: fase 8 omitida.
- **Veredictos**: QA, **GO condicionado** (falta ejecutar las 22 pruebas con BD real). Seguridad, **GO condicionado**: los secretos JWT de `backend/.env.local` deben ser robustos (32 caracteres o más, distintos y no los de la plantilla), o usar `NODE_ENV=production`. El hallazgo de severidad alta de la aplicación es S-01.
- **Seguridad, otros puntos abiertos**: la API escucha en todas las interfaces por HTTP (S-04), los límites de peticiones son por IP y compartidos en un mismo PC (S-02), y la sesión persiste en el equipo (S-03). Las decisiones pendientes están en [docs/09-maintenance/backlog.md](docs/09-maintenance/backlog.md).
- **Entorno de Claude Code**: H-01 (permisos que permiten comandos destructivos sobre la base sin pedir confirmación). No afecta a la aplicación desplegada, pero conviene corregirlo antes de la siguiente sesión con agentes.
- **Datos de ejemplo**: IVA y precios del seed son ilustrativos; revísalos antes de operar.
- **Sin cancelación de pedidos ni devolución de stock** (decisión S-20 de los requisitos).

### Documentación del proyecto

| Documento                              | Ruta                                                                           |
| -------------------------------------- | ------------------------------------------------------------------------------ |
| Especificación original                | `docs/prompt-proyecto.md`                                                      |
| Requisitos y supuestos                 | `docs/01-requirements/requirements.md`                                         |
| Arquitectura y contrato de API         | `docs/02-architecture/architecture.md`, `docs/02-architecture/api-contract.md` |
| Diseño de pantallas                    | `docs/03-design/screens.md`                                                    |
| Informes de QA y seguridad             | `docs/06-qa/test-report.md`, `docs/07-security/security-report.md`             |
| Runbook de operación                   | `docs/09-maintenance/runbook.md`                                               |
| Backlog priorizado                     | `docs/09-maintenance/backlog.md`                                               |
| Correcciones pendientes en otras fases | `docs/09-maintenance/correcciones-pendientes.md`                               |
| Historial de cambios                   | `CHANGELOG.md`                                                                 |
| Guía de demostración                   | `docs/DEMO.md`                                                                 |
