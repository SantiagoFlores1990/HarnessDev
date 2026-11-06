# Guía para repetir la demostración

La rama `demo-base` contiene todo listo **antes** de generar el proyecto: agentes, skills, hooks, plantillas y el prompt en `docs/prompt-proyecto.md`. No se construye nada en ella: cada demostración se hace en una rama nueva.

## Preparación (una vez por equipo)

Requisitos: Node 20+, Git, PostgreSQL, Flutter con soporte Windows (`flutter doctor` sin errores) y Claude Code con sesión iniciada. Detalle en el `README.md`.

## Pasos de cada demostración

```bash
git clone https://github.com/SantiagoFlores1990/HarnessDev.git
cd HarnessDev
git switch demo-base
git switch -c demo-<fecha-o-lugar>        # ejemplo: demo-salon-b
node scripts/setup.js                     # instala dependencias y crea backend/.env.local
```

1. Edita `backend/.env.local` (`DB_NAME=pizzeria`, usuario, contraseña y `DATABASE_URL`). Opcional: `SEED_ADMIN_PASSWORD` y `SEED_CLIENT_PASSWORD`.
2. Crea la base: `psql -U <usuario> -h localhost -c "CREATE DATABASE pizzeria;"`
3. Abre Claude Code en la raíz (`claude`) y ejecuta:

```
/build-app Lee docs/prompt-proyecto.md y construye exactamente lo que describe, siguiendo sus reglas de trabajo.
```

4. Al terminar, la app arranca con `flutter run -d windows` dentro de `frontend/`.

## Volver al estado inicial

```bash
git restore .                 # descarta cambios sin commit
git clean -fd                 # borra archivos nuevos no versionados (revisa antes con: git clean -nd)
git switch demo-base
```

`git clean` no toca `backend/.env.local` porque está ignorado por git.

Para reutilizar la misma base de datos, vacíala antes de la siguiente demo. Esto **borra todos los datos** de la base indicada en `.env.local`:

```bash
cd backend
npx dotenv -e .env.local -- prisma migrate reset
```

Solo funciona después de que el agente cree el esquema de Prisma. Alternativa más simple: crea una base distinta por demostración (`pizzeria_demo2`) y cambia `DB_NAME` y `DATABASE_URL`.

## Qué esperar

- La generación completa recorre 8 fases con varios agentes y puede tardar bastante y consumir muchos tokens. Ensáyala antes de la exposición.
- Si se queda sin tiempo, ejecuta una sola fase con `/run-stage <agente>` (por ejemplo `requirements-analyst`) para mostrar el flujo.
- Los datos del seed son de ejemplo.
