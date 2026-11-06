# Política de modelos

| Archivo | Modelo | ID | Uso en el flujo |
|---|---|---|---|
| [opus.md](opus.md) | Claude Opus 5.5 | `claude-opus-5-5` | Razonamiento profundo: arquitectura, seguridad |
| [sonnet.md](sonnet.md) | Claude Sonnet 5.5 | `claude-sonnet-5-5` | Implementación diaria: backend, Flutter, QA |
| [haiku.md](haiku.md) | Claude Haiku 5.5 | `claude-haiku-5-5` | Tareas rápidas/baratas: docs, logs, formato |
| [fable.md](fable.md) | Claude Fable 5.1 | `claude-fable-5-1` | Opcional: tareas de máxima capacidad / creativas |

En los agentes se declara con `model: opus | sonnet | haiku` en el frontmatter (`.claude/agents/*.md`).
Verifica IDs vigentes en la documentación de Anthropic antes de fijar versiones en código.

## Asignación por etapa
| Etapa | Agente | Modelo |
|---|---|---|
| 1 Requisitos | requirements-analyst | sonnet |
| 2 Arquitectura | solution-architect | opus |
| 3 Diseño UX | ux-designer | sonnet |
| 4 Backend | backend-dev | sonnet |
| 5 Frontend | flutter-dev | sonnet |
| 6 QA | qa-engineer | sonnet |
| 7 Seguridad | security-reviewer | opus |
| 8 DevOps | devops-engineer | sonnet |
| 9 Mantenimiento/Docs | maintenance-docs | haiku |
