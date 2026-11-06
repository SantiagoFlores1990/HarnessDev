# HarnessDev — Plantilla de fábrica de software con Claude Code

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
