# Entregable — Fase 2: Arquitectura

- **Proyecto:** Good Pizza — sistema de venta de pizzas con ingredientes personalizados
- **Fecha:** 2026-11-06
- **Agente responsable:** architect
- **Versión:** 1.0

## 1. Objetivo de la fase

Definir la arquitectura del monolito (backend Node.js/Express + Prisma + PostgreSQL `pizzeria`; frontend Flutter Windows), el modelo de datos lógico con su esquema Prisma propuesto, el contrato REST `/api/v1` que comparten backend-dev y flutter-dev, y las decisiones arquitectónicas (ADR), cubriendo RF-01..RF-29 y RNF-01..RNF-10 de la fase 1.

## 2. Resumen ejecutivo

- Backend en capas routes → controllers → services → Prisma, con un **motor de cálculo puro único** (`services/pricing-engine`) para precio, calorías, IVA por componente con half-up y reglas de armado.
- El frontend no duplica reglas: usa `POST /api/v1/orders/quote` (cotización sin efectos, con `valid`/`violations`) para el cálculo en vivo y el resumen del pedido.
- La confirmación (`POST /orders`) es una transacción: bloqueo `FOR UPDATE` de ingredientes, mismo motor, descuento de stock con `CHECK stock >= 0`, número `GP-AAAAMMDD-NNNN` con secuencia diaria transaccional y snapshots completos.
- 15 modelos Prisma (catálogos como tablas, estado como enum), dinero `Decimal`, `onDelete` explícito, ingredientes y predefinidas con baja lógica.
- Autenticación JWT access (15 min) + refresh rotativo (7 días) con hash en BD; autorización por rol y por dueño (pedido ajeno → 404).
- Frontend feature-first con Riverpod, go_router (NavigationRail por rol), dio y flutter_secure_storage.
- 25 endpoints documentados con payloads y formato de error uniforme `{error:{code,message,details}}`.
- 11 ADR; 6 preguntas abiertas no bloqueantes con supuesto por defecto.

## 3. Artefactos producidos

| Artefacto             | Ruta                                            | Descripción                                                                                                                                                                 |
| --------------------- | ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Arquitectura          | `docs/02-architecture/architecture.md`          | Diagramas, capas, estructura backend/frontend, motor de cálculo, auth, configuración por entorno.                                                                           |
| Modelo de datos       | `docs/02-architecture/data-model.md`            | Entidades, relaciones, ERD, esquema Prisma completo, CHECK, seed, consultas críticas.                                                                                       |
| Contrato de API       | `docs/02-architecture/api-contract.md`          | 25 endpoints `/api/v1`, modelos, errores, matriz de permisos, ejemplo de referencia.                                                                                        |
| ADR-001..011          | `docs/02-architecture/adr/`                     | Monolito y capas; motor único y cotización; snapshots; secuencia diaria; concurrencia de stock; JWT; frontend; dinero; catálogos/enums; baja lógica; estrategia de pruebas. |
| Entregable            | `docs/02-architecture/entregable.md`            | Este documento.                                                                                                                                                             |
| Flujo                 | `docs/02-architecture/flujo.md`                 | Proceso de la fase, flujos de pantalla y secuencias de confirmación/estado.                                                                                                 |
| Diagrama ER           | `docs/02-architecture/diagrama-er.md`           | ER lógico completo + diccionario de datos.                                                                                                                                  |
| Pruebas               | `docs/02-architecture/pruebas-unitarias.md`     | Verificaciones de consistencia del contrato y del diseño.                                                                                                                   |
| Manual de usuario     | `docs/02-architecture/manual-usuario.md`        | Funcionalidades por rol según la arquitectura.                                                                                                                              |
| Documentación técnica | `docs/02-architecture/documentacion-tecnica.md` | Visión técnica consolidada.                                                                                                                                                 |

## 4. Decisiones y supuestos

Decisiones (detalle en ADR):

- D-01 Motor de cálculo único en backend + `/orders/quote` (ADR-002).
- D-02 Masa y salsa como componentes `portions = 1`; toppings/extras no pueden ser de categoría masa/salsa (ADR-002).
- D-03 Snapshots en tres niveles; comprobante solo desde snapshots (ADR-003).
- D-04 Secuencia diaria con upsert transaccional; fecha en zona horaria del proceso Node (ADR-004, S-24).
- D-05 Bloqueo pesimista ordenado + UPDATE condicional + CHECK (ADR-005).
- D-06 JWT access + refresh rotativo con hash en BD (ADR-006).
- D-07 Riverpod + go_router + dio + secure storage, feature-first (ADR-007).
- D-08 Importes como string decimal en JSON; único redondeo: IVA half-up sobre el subtotal 15 % del pedido (ADR-008, S-19).
- D-09 Catálogos en tablas; estado como enum + historial (ADR-009).
- D-10 Baja lógica de ingredientes y predefinidas (ADR-010).
- D-11 Pruebas sin escribir en `pizzeria` (ADR-011).
- D-12 `expectedTotal` opcional en `POST /orders` → `409 PRICE_CHANGED` si el precio cambió desde la cotización.
- D-13 Solo CLIENT confirma pedidos; ADMIN puede cotizar y ver cualquier pedido.
- D-14 Límites técnicos de esquema: hasta 50 líneas por pedido y 30 toppings/extras por pizza (protección de la API).

Supuestos heredados: S-01..S-26 de `docs/01-requirements/requirements.md` sin cambios.

## 5. Riesgos y pendientes

Riesgos:

| ID   | Riesgo                                                                            | Mitigación                                                                       |
| ---- | --------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| R-01 | Latencia de la cotización en vivo > 200 ms (RNF-01).                              | API en la misma máquina/LAN, debounce 150 ms, cancelación, mostrar último valor. |
| R-02 | Stock mostrado al armar se agota antes de confirmar.                              | 409 con detalle por ingrediente; la UI recotiza el carrito.                      |
| R-03 | Precio cambia entre cotización y confirmación.                                    | `expectedTotal` → 409 `PRICE_CHANGED` con nueva cotización.                      |
| R-04 | La concurrencia de stock no se verifica contra PostgreSQL real sin BD de pruebas. | ADR-011; PA-01.                                                                  |
| R-05 | Cambio de zona horaria del servidor altera la fecha de negocio.                   | Documentado (S-24).                                                              |
| R-06 | Prisma no modela CHECK; podrían perderse al regenerar migraciones.                | Se añadieron en la migración `20261106190500_add_check_constraints`, porque la migración inicial ya estaba aplicada (ver `docs/04-backend/README.md`). QA verifica su existencia. |

Preguntas abiertas (no bloquean; se aplica el supuesto indicado hasta que el usuario responda):

| ID    | Pregunta                                                                                                                                                                | Supuesto aplicado                                                                                                |
| ----- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| PA-01 | ¿Se puede usar una base o esquema de pruebas distinto (p. ej. `DATABASE_URL_TEST` con `?schema=test`) para las pruebas de integración de stock concurrente y secuencia? | Sin él, esas pruebas se omiten y el resto usa dobles; nunca se escribe en los datos de `pizzeria`.               |
| PA-02 | "CRUD de pizzas predefinidas": ¿el borrado puede ser desactivación (como los ingredientes)?                                                                             | Sí: solo desactivación, sin `DELETE`.                                                                            |
| PA-03 | Al personalizar una predefinida, ¿el cliente puede cambiar la masa o la salsa de la receta?                                                                             | No: cambiar equivale a quitar (S-06); solo se agregan toppings o porciones.                                      |
| PA-04 | ¿Puede agregarse una segunda salsa (o masa) como ingrediente adicional?                                                                                                 | No: masa y salsa son exactamente 1 por pizza; los extras son de queso, carne, vegetal u otros.                   |
| PA-05 | ¿Puede el administrador registrar pedidos (p. ej. para un cliente en mostrador)?                                                                                        | No: solo el rol Cliente confirma pedidos (el prompt dice que el registro del cliente es obligatorio para pedir). |
| PA-06 | ¿Es aceptable mostrar al cliente la cantidad de stock disponible por ingrediente (US-06 lo sugiere)?                                                                    | Sí: el catálogo para clientes incluye `stock`.                                                                   |

Pendientes para fases siguientes: UX define paleta, logo SVG y pantallas (fase 3); backend aplica el esquema, migraciones con CHECK, seed y `env.template` con las variables de `architecture.md` §5 (fase 4).

## 6. Criterios de aceptación de la fase

- [x] Flujo documentado (`flujo.md`)
- [x] Diagrama entidad-relación actualizado (ER lógico completo, coherente con el esquema Prisma propuesto)
- [x] Pruebas unitarias ejecutadas (en esta fase: verificaciones de consistencia del contrato y el diseño, realizadas por revisión; no hay código ejecutable)
- [x] Manual de usuario actualizado
- [x] Documentación técnica actualizada
- [x] Contrato de API completo con `/api/v1/health` y formato de error uniforme
- [x] ADR de cálculo en backend, snapshots, secuencia, concurrencia, JWT y estado del frontend

## 7. Aprobación

| Rol                 | Nombre      | Fecha      |
| ------------------- | ----------- | ---------- |
| Arquitecto (agente) | architect   | 2026-11-06 |
| Product owner       | (pendiente) |            |
