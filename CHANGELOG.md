# Changelog — Good Pizza (rama `testHarness`)

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/). Versionado semántico.
La versión del backend está en `backend/package.json` (`0.1.0`). La del frontend, en `frontend/pubspec.yaml`, es `1.0.0+1`; ver "Preguntas abiertas" en `docs/09-maintenance/entregable.md`.

Todas las cifras de este documento proceden de los entregables y los informes de cada fase (QA y seguridad en su fecha de ejecución). No se han vuelto a ejecutar pruebas al redactar este registro.

## [0.1.0] - 2026-11-06

Primera versión completa del sistema de venta de pizzas con ingredientes personalizados. Entrega del ciclo SDLC en fases 1 a 7 y 9. La fase 8 (DevOps/Docker/CI) queda **omitida** por decisión del usuario, porque Docker no está instalado.

### Añadido

**Fase 1 — Requisitos** (`docs/01-requirements/`)

- 29 requisitos funcionales (RF-01..RF-29) y 10 no funcionales (RNF-01..RNF-10), priorizados con MoSCoW.
- 23 historias de usuario (US-01..US-23) con criterios Given/When/Then.
- Supuestos S-01..S-26, incluidas las decisiones confirmadas por el usuario (S-17..S-26).
- Glosario del dominio y alcance fuera de alcance explícito.

**Fase 2 — Arquitectura** (`docs/02-architecture/`)

- Arquitectura monolítica (backend Node.js/Express + Prisma + PostgreSQL; frontend Flutter Windows).
- Contrato de API `/api/v1` con 25 endpoints, 24 códigos de error y matriz de permisos.
- Modelo de datos y 11 ADR (001 a 011): capas y monolito, motor de cálculo único, snapshots, secuencia diaria de número de orden, concurrencia de stock, JWT access/refresh, frontend Riverpod/go_router, dinero Decimal, catálogos como tablas, baja lógica, estrategia de pruebas sin tocar datos.

**Fase 3 — Diseño UX/UI** (`docs/03-design/`)

- 13 pantallas (S-01..S-13): 7 de cliente y 6 de administrador, más diálogos compartidos.
- Sistema de diseño con paleta azul marino en modo claro, 45 pares de contraste calculados (mínimo texto 4,94:1).
- Logotipo SVG de Good Pizza en tres variantes (color, monocromo y horizontal para documentación).
- Accesibilidad, comportamiento de escritorio y atajos de teclado.

**Fase 4 — Backend** (`backend/`, `docs/04-backend/`)

- API REST `/api/v1` con los 25 endpoints, formato de error uniforme `{ error: { code, message, details } }`, validación con Zod estricta, JWT, bcrypt, helmet, cors con lista blanca, rate limit global y de autenticación, pino con redacción de secretos.
- Motor de cálculo puro (`services/pricing-engine/`): precio, calorías, IVA 15 %/0 % con half-up, reglas de armado y stock.
- Confirmación de pedido transaccional: bloqueo `FOR UPDATE`, descuento de stock condicionado, número `GP-AAAAMMDD-NNNN` y snapshots.
- Modelo Prisma con 15 modelos, 3 enums y migraciones `20261106185922_init`, `20261106185930_init` (vacía) y `20261106190500_add_check_constraints` (9 CHECK).
- Seed idempotente: 2 roles, 3 tamaños, 6 categorías, tarifas IVA 15 %/0 %, 20 ingredientes de ejemplo, 5 pizzas predefinidas, 1 administrador y 1 cliente. Las contraseñas vienen de `SEED_*_PASSWORD` o se generan y se imprimen una sola vez.
- Scripts npm: `dev`, `start`, `test`, `lint`, `db:generate`, `db:migrate`, `db:deploy`, `db:seed`, `db:test:migrate`, `db:studio`.
- `backend/env.template` con todas las variables, sin valores reales.

**Fase 5 — Frontend Windows** (`frontend/`, `docs/05-frontend/`)

- Aplicación Flutter para Windows, nombre visible "Good Pizza", con las 13 pantallas, NavigationRail, Material 3 en español y tema azul marino.
- Riverpod, go_router con guardas por rol, dio con interceptor de autenticación y un único refresh serializado, `flutter_secure_storage` para los tokens.
- El frontend no calcula precios ni reglas: consulta `POST /orders/quote` con debounce de 150 ms.
- Comprobante en pantalla con el diseño del prompt (sin PDF ni impresión).
- Atajos de teclado y ayuda `F1`.

**Fase 6 — QA** (`docs/06-qa/`, `backend/tests/`, `frontend/test/`, `frontend/integration_test/`)

- Plan de pruebas con trazabilidad US/RF/RNF y los 4 criterios de aceptación; informe de pruebas con veredicto.
- 99 pruebas nuevas en el backend (motor en casos límite, flujos HTTP en proceso, servicios, seed) y 4 de flujo en Flutter.
- Prueba de escritorio `integration_test` (IT-F01) que compila y lanza `good_pizza.exe` con repositorios falsos.
- Cobertura: `@vitest/coverage-v8` como devDependency; `integration_test` en `dev_dependencies`.

**Fase 7 — Seguridad** (`docs/07-security/`)

- Informe de seguridad con veredicto **GO condicionado**, revisión OWASP Top 10 y 18 hallazgos de aplicación (S-01..S-18), 4 del entorno de desarrollo (H-01..H-04) y dos condiciones (C1 y C2).
- Auditoría de dependencias: `npm audit` y `flutter pub outdated`.

**Fase 9 — Mantenimiento y documentación final** (`docs/09-maintenance/`, `README.md`, `CHANGELOG.md`)

- README raíz con la guía de la plantilla conservada y la sección del proyecto.
- Runbook de operación, backlog priorizado y lista de correcciones pendientes en otras fases.
- Entregables consolidados de la fase 9 (entregable, flujo, ER final, pruebas, manual de usuario y documentación técnica).

### Cambiado

- Los conteos de pruebas se actualizaron con la ejecución de QA (fase 6). Backend: 267 pasan y 22 omitidas. Frontend: 225 pasan, más 1 de integración de escritorio. Las cifras de las fases 4 y 5 (190 y 221) corresponden a sus fechas.
- La migración de restricciones CHECK se añadió como migración posterior (`add_check_constraints`), porque la migración `init` ya estaba aplicada. El resultado en base de datos es el mismo.
- La compilación `flutter build windows` funciona tras instalar el componente "C++ ATL" de Visual Studio Build Tools. Las notas de la fase 5 que lo daban por fallido quedan superadas (D-01 de QA).
- Por decisión de implementación, el tope técnico de stock por ingrediente es 1 000 000 porciones (para no desbordar INT4).
- El JSON mal formado o un cuerpo mayor de 100 KB responden `400 VALIDATION_ERROR`, porque el contrato no define 413.

### Corregido

- En la fase 6 no se corrigió código de producción: no hubo defectos funcionales en lo ejecutado.
- La prueba de rendimiento de `POST /orders/quote` se midió en proceso (p95 de 6,50 ms con 1 línea y 9,16 ms con 10 líneas, frente al límite de 200 ms). No incluye latencia de PostgreSQL.

### Seguridad

- Sin vulnerabilidades críticas en la aplicación.
- **Alta abierta (S-01):** fuera de `production` se aceptan secretos JWT débiles o los de la plantilla. Condición C1 para el GO.
- **Medias abiertas (S-02..S-06):** límites de peticiones por IP compartidos en un PC; sesión persistente en equipo compartido; API escuchando en todas las interfaces por HTTP; amplificación de errores de validación; agotamiento de stock con pedidos sin límite.
- `npm audit --omit=dev`: 4 avisos altos (zod 3.25.76 y deepmerge-ts vía Prisma CLI). `npm audit` completo: 3 críticos, 5 altos y 6 moderados; los críticos y la mayoría de los demás son de dependencias de pruebas.
- Controles verificados: bcrypt con coste mínimo 12, JWT con algoritmo fijado, refresh rotativo con detección de reutilización, autorización por rol y dueño (25 de 25 rutas), SQL parametrizado, `CHECK (stock >= 0)`, helmet, CORS con lista blanca, errores sin stack.

### Omitido (fuera de alcance de esta versión)

- **Fase 8 — DevOps/Docker/CI**: omitida por decisión del usuario (Docker no está instalado). No hay `Dockerfile`, `docker-compose`, pipeline de CI ni entregables en `docs/08-devops/` (solo `.gitkeep`).
- Cancelación de pedidos por el cliente y devolución de stock (S-20).
- Delivery, pasarela de pago, exportación o impresión (PDF) del comprobante (S-22), factura electrónica, multi-sucursal, recuperación de contraseña, notificaciones.
- Plataformas distintas de Windows (móvil, web, Linux, macOS).
- Modo oscuro (D-UX-01), botón ☰ y tecla `F6` (PA-F3).
- Servir el frontend como estático desde el backend (no implementado).

### Pendiente antes de usar en el local

- Definir `DATABASE_URL_TEST` (esquema `test`) y ejecutar `npm run db:test:migrate` y `npm test` para las 22 pruebas de integración (D-05).
- Ejecutar `npm run db:seed` sobre `pizzeria` (las contraseñas generadas se muestran una sola vez).
- Definir secretos JWT robustos (32 caracteres o más, distintos, no los de la plantilla) o usar `NODE_ENV=production` (C1, S-01).
- Verificar `flutter run -d windows` contra el backend real con datos del seed.
- Decidir las preguntas abiertas de seguridad (acceso en red, PC compartido, cancelación y devolución de stock, usuario desactivado 15 min, `npm audit fix`, ajustes de `.claude/settings.json` y hooks).
