# Cómo contribuir

## Dos tipos de trabajo
1. **Usar la plantilla** para construir tu aplicación: clona, ejecuta `node scripts/setup.js` y lanza `/build-app`. Haz tu aplicación en una rama o en un fork propio.
2. **Mejorar la plantilla** (agentes, skills, hooks, plantillas de `docs/_templates/`): abre un pull request pequeño y enfocado.

## Reglas para mejorar la plantilla
- Mantén la plantilla **independiente del dominio**: sin ejemplos de una aplicación concreta ni rutas locales.
- Un agente = una etapa del SDLC, con `name`, `description`, `tools` mínimas y `model` justificado según `models/README.md`.
- Las skills van en `.claude/skills/<nombre>/SKILL.md` con `name` y `description` claros.
- Los hooks deben ser seguros por defecto: salir con código 0 ante errores inesperados y con 2 solo para bloquear a propósito.
- No agregues secretos, `.env*` reales ni binarios grandes.
- Documenta en español; identificadores de código en inglés.

## Antes de abrir un PR
```bash
node scripts/setup.js --check
cd backend && npm test && npm run lint
```
Si cambias un hook, pruébalo con una entrada JSON de ejemplo por stdin.

## Mensajes de commit
Formato `tipo: resumen` (`feat`, `fix`, `docs`, `chore`, `refactor`).
