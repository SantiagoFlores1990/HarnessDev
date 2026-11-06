---
name: nodejs-express-api
description: Convenciones para construir APIs REST con Node.js 20 y Express en este monolito (capas, errores, validación, auth JWT, logging).
---
# Node.js + Express

## Estructura (`backend/src`)
`config/` env y constantes · `routes/` solo enrutado · `controllers/` HTTP in/out · `services/` lógica de negocio · `middlewares/` auth, validate, error · `utils/`.

## Reglas
- ES Modules (`"type": "module"`), `async/await`, sin callbacks.
- Validar todo input con Zod en un middleware `validate(schema)`.
- Errores: clase `AppError(status, code, message)` + middleware final que responde `{ error: { code, message } }`.
- Auth: JWT access (15 min) + refresh; contraseñas con bcrypt (cost ≥ 12); middleware `requireAuth`/`requireRole`.
- Seguridad base: `helmet`, `cors` con lista blanca, `express-rate-limit`, límite de body.
- Logging con `pino`; nunca registrar contraseñas ni tokens.
- Config solo desde `process.env` validado al arrancar; `.env.example` versionado.
- Scripts npm: `dev`, `start`, `test`, `lint`, `db:migrate`, `db:seed`.
- `GET /api/health` obligatorio.
