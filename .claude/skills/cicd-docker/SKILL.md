---
name: cicd-docker
description: Empaquetado con Docker multi-stage y pipelines de CI/CD (GitHub Actions) para el monolito Node + Flutter.
---
# Docker y CI/CD

- Dockerfile multi-stage: (1) imagen `ghcr.io/cirruslabs/flutter` → `flutter build web --release`; (2) `node:20-alpine` instala deps de producción y copia `build/web` a `backend/public`.
- Usuario no root, `HEALTHCHECK` contra `/api/health`, `.dockerignore` completo.
- `docker-compose.yml`: servicio `app` + `postgres:16` con volumen y variables desde `.env`.
- CI: jobs paralelos `backend` (lint + test), `flutter` (analyze + test), luego `docker build`.
- Release: builds desktop (Windows/Linux/macOS en sus runners) y APK como artefactos.
- Migraciones: `prisma migrate deploy` al arrancar el contenedor.
