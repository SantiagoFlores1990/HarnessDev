# HarnessDev — Plantilla de fábrica de software con Claude Code

Plantilla para generar un monolito full stack con agentes de Claude Code, uno por etapa del ciclo de vida (SDLC). Es independiente del dominio: la aplicación concreta la define el prompt de `/build-app`.

## Stack
- **Backend:** Node.js 20+ (Express) en `backend/` — API REST + (opcional) servir Flutter web. Un solo deployable.
- **Frontend:** Flutter en `frontend/` — Android, iOS, Windows, Linux, macOS (+ web).
- **BD:** PostgreSQL 17 en todos los entornos, vía Prisma (`backend/prisma`).
- **Credenciales:** `backend/.env.local` (no versionado). Plantilla: `backend/env.template`.

## Mapa del repositorio
- `.claude/agents/`   → agentes (1 por etapa SDLC)
- `.claude/skills/`   → skills reutilizables (`<nombre>/SKILL.md`)
- `.claude/commands/` → slash commands (`/build-app`, `/run-stage`)
- `.claude/hooks/`    → scripts Node usados por `.claude/settings.json`
- `models/`           → guía de cada modelo y política de uso
- `docs/_templates/`  → plantillas de entregables por fase
- `docs/NN-etapa/`    → artefactos que produce cada agente
- `scripts/`          → `setup.js` (configuración del ambiente)

## Flujo
`/build-app <descripción>`: requirements → architect → ux-designer → backend-dev → flutter-dev → qa → security → devops → maintenance-docs.
Cada agente lee `docs/` de la etapa previa, escribe en su carpeta `docs/NN-*` y genera los 6 entregables de la skill `phase-deliverables`.

## Reglas generales
- Documentar en español; código e identificadores en inglés.
- Nunca leer ni escribir `.env*` con credenciales (hay deny rules y hooks). Usar `backend/env.template`.
- Los scripts npm (`dev`, `db:migrate`, `db:seed`) cargan `.env.local` con dotenv-cli; no abras el archivo.
- Cambios pequeños y verificables; correr tests antes de cerrar una etapa.
- Elegir modelo según `models/README.md`.
