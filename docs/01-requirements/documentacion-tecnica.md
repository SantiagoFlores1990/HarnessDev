# Documentación técnica — Fase 1 (restricciones de partida)

## 1. Visión técnica

Monolito en un repositorio: backend Node.js (API REST `/api/v1`) y frontend Flutter solo Windows, con PostgreSQL `pizzeria`. Detalles de diseño se definen en la fase de arquitectura; no hay código aún.

## 2. Arquitectura y componentes

- Flutter (Windows, Material 3, NavigationRail) → API Express → Prisma → PostgreSQL.
- El servidor es la fuente de verdad: valida reglas y recalcula precio, calorías e IVA.
- Reglas técnicas derivadas de las decisiones confirmadas: IVA sobre cada subtotal con redondeo half-up a 2 decimales; fecha y número de orden con la zona horaria del servidor; sin endpoint de cancelación ni de borrado de ingredientes; sin exportación de comprobante; contraseña de mínimo 8 caracteres validada con Zod; cantidad por línea entre 1 y 20.

## 3. Tecnologías y versiones

| Componente    | Tecnología                                                            | Versión                        |
| ------------- | --------------------------------------------------------------------- | ------------------------------ |
| Backend       | Node.js + Express, Prisma, Zod, JWT, bcrypt, helmet, cors, rate limit | Node 20+                       |
| Base de datos | PostgreSQL                                                            | 17 (base `pizzeria` existente) |
| Frontend      | Flutter (Windows)                                                     | Por definir en arquitectura    |
| Pruebas       | Vitest + Supertest; flutter test                                      | Por definir                    |

## 4. Estructura de carpetas

`backend/`, `frontend/` (creado con `flutter create --org com.pizzeria --project-name good_pizza --platforms=windows .`), `docs/NN-*`.

## 5. Configuración y variables de entorno

- `backend/.env.local` (no versionado, no se lee): credenciales de BD y secretos.
- `SEED_ADMIN_PASSWORD`, `SEED_CLIENT_PASSWORD`: contraseñas opcionales del seed.
- Nuevas variables se agregan a `backend/env.template`.

## 6. API / Interfaces

Contrato por definir en arquitectura. Requisito de partida:

| Método | Ruta             | Auth | Request | Response | Errores |
| ------ | ---------------- | ---- | ------- | -------- | ------- |
| GET    | `/api/v1/health` | No   | —       | 200 OK   | —       |

## 7. Base de datos

Todo el modelo se crea con migraciones Prisma; no borrar ni recrear la base. Dinero en Decimal. Los ingredientes se desactivan, no se borran. Ver `diagrama-er.md` (conceptual).

## 8. Instalación y ejecución

Comandos npm `db:migrate`, `db:seed`, `dev` (cargan `.env.local` con dotenv-cli) y `flutter run -d windows`; se concretan en fases posteriores.

## 9. Pruebas

Ver `pruebas-unitarias.md` (casos de aceptación UT-01 a UT-28).

## 10. Seguridad

bcrypt, JWT, helmet, cors, rate limit, validación Zod, autorización por rol y por dueño, sin secretos en el repo.

## 11. Despliegue y operación

Fuera de alcance (sin Docker/CI/DevOps).

## 12. Decisiones (ADR) y deuda técnica

Supuestos S-01 a S-26 en `requirements.md`. Sin preguntas abiertas. Sin devolución de stock por diseño (S-20).
