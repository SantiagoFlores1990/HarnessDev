---
name: prisma-database
description: Modelado de datos con Prisma sobre PostgreSQL, migraciones, seeds y buenas prácticas de consultas.
---
# Prisma

- Esquema en `backend/prisma/schema.prisma` con `provider = "postgresql"` y `url = env("DATABASE_URL")`.
- Los scripts npm (`db:migrate`, `db:seed`, `dev`) cargan `backend/.env.local` con `dotenv-cli`; no leas ese archivo, solo ejecuta los scripts.
- Dinero como `Decimal` (nunca `Float`); fechas `DateTime`; ids `cuid()` o `uuid()`.
- Índices en claves foráneas y campos de búsqueda; `onDelete` explícito.
- Una migración por cambio: `prisma migrate dev --name <accion>`; no editar migraciones aplicadas.
- Seed idempotente (`upsert`) en `prisma/seed.js`.
- Transacciones (`$transaction`) para operaciones multi-tabla (ej. crear pedido + ítems).
- Evitar N+1: usar `include`/`select` explícitos; paginar listados.
