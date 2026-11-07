# Entregable — Fase 6: Aseguramiento de calidad (QA)

- **Proyecto:** Good Pizza (monolito Node.js + Flutter Windows)
- **Fecha:** 2026-11-06
- **Agente responsable:** qa
- **Versión:** 1.0

## 1. Objetivo de la fase

Verificar que el backend y el frontend cumplen las historias US-01..US-23 y los criterios de aceptación del prompt: trazar cada historia a casos de prueba, completar las pruebas que faltaban, ejecutar todo, medir cobertura y rendimiento, y emitir un veredicto con los defectos encontrados.

## 2. Resumen ejecutivo

1. Veredicto: **GO condicionado**. Sin defectos funcionales ni bloqueantes en lo ejecutable; la condición es verificar las 22 pruebas con PostgreSQL real, omitidas por falta de `DATABASE_URL_TEST`.
2. Backend: 267 pruebas pasan y 22 se omiten (289); `npm run lint` limpio. Eran 168 pasando al inicio (+99 nuevas).
3. Frontend: `flutter analyze` sin problemas; `flutter test` 225 pasan (+4); `integration_test` en Windows pasa (compila y lanza el `.exe`).
4. Cobertura: servicios del backend 97.11 % (criterio ≥ 70 %; antes 73.17 %); backend total 96.13 %; frontend 93.3 % de líneas.
5. Rendimiento de `POST /orders/quote` en proceso (sin BD real): p95 6.50 ms (1 línea) y 9.16 ms (10 líneas) frente a 200 ms.
6. Huecos cerrados: half-up exhaustivo (20 001 casos), snapshots inmutables en proceso, flujos HTTP completos, matriz de permisos, seed, flujos de UI cliente y administrador, prueba E2E de escritorio.
7. Defectos: 6 de severidad baja o media (documentación desactualizada, observaciones de seguridad y robustez, prueba de BD omitida). Ninguno exigió cambiar código de producción.
8. Coherencia: 25 endpoints, 24 códigos de error y 15 entidades del ER coinciden entre contrato, código y documentos; los conteos de pruebas y el estado de la compilación Windows en los docs de las fases 4 y 5 están desactualizados.

## 3. Artefactos producidos

| Artefacto                                    | Ruta                                                   | Descripción                                                                  |
| -------------------------------------------- | ------------------------------------------------------ | ---------------------------------------------------------------------------- |
| Plan de pruebas y trazabilidad               | `docs/06-qa/test-plan.md`                              | US-01..US-23, RF/RNF y los 4 criterios de aceptación -> casos y huecos       |
| Informe de pruebas                           | `docs/06-qa/test-report.md`                            | Resultados reales, cobertura, rendimiento, defectos, coherencia, veredicto   |
| Pruebas del motor (casos límite)             | `backend/tests/unit/pricingEngine.edge.test.js`        | 24 pruebas                                                                   |
| Flujos HTTP en proceso                       | `backend/tests/api/flows.inprocess.test.js`            | 45 pruebas, incluye rendimiento                                              |
| Pruebas de servicios                         | `backend/tests/unit/services.qa.test.js`               | 22 pruebas                                                                   |
| Pruebas del seed                             | `backend/tests/unit/seed.qa.test.js`                   | 8 pruebas                                                                    |
| Flujos de UI                                 | `frontend/test/flows/journeys_flow_test.dart`          | 4 pruebas                                                                    |
| Prueba E2E de escritorio                     | `frontend/integration_test/app_flow_test.dart`         | 1 prueba (Windows)                                                           |
| Dependencias de prueba                       | `backend/package.json`, `frontend/pubspec.yaml`        | `@vitest/coverage-v8`, `integration_test`                                    |
| Entregables de fase                          | `docs/06-qa/`                                          | flujo, diagrama ER, pruebas unitarias, manual de usuario, documentación técnica |

## 4. Decisiones y supuestos

- Se mantienen las decisiones de las fases 1-5 (mínimo de 3 distintos solo en personalizadas, máximo 3 porciones, IVA 15 %/0 % half-up por subtotal, 20 pizzas por línea, sin cancelación, predefinidas solo suman ingredientes, el admin envía `includeInactive=true`, separador decimal punto).
- Las pruebas con BD real solo usan el esquema `test`; sin `DATABASE_URL_TEST` se omiten y así se reporta (no se derivó la URL).
- El rendimiento se mide con el motor y el servicio en proceso, con Prisma sustituido por un doble; no incluye latencia de PostgreSQL.
- No se modificó código de producción ni el comportamiento del contrato; no se debilitó ni borró ninguna prueba.

## 5. Riesgos y pendientes

| ID   | Riesgo / pendiente                                                                                          | Responsable                                      |
| ---- | ----------------------------------------------------------------------------------------------------------- | ------------------------------------------------ |
| D-05 | 22 pruebas con PostgreSQL (concurrencia de stock, secuencia diaria, CHECK, criterios 1-3 contra BD) omitidas | Usuario: definir `DATABASE_URL_TEST` y `npm run db:test:migrate` |
| D-01 | Docs de la fase 5 dicen que la compilación Windows falla por ATL; ya compila                               | flutter-dev / mantenimiento                      |
| D-02 | Conteos de pruebas desactualizados en docs 04 y 05                                                         | mantenimiento                                    |
| D-03 | Usuario desactivado conserva lectura hasta que caduca el access token (15 min)                              | backend-dev / seguridad                          |
| D-04 | IVA siempre al 15 % si hubiera tarifas distintas de 0 y 15 (hoy imposible sin endpoint de tarifas)          | backend-dev (sin acción)                         |
| D-06 | PA-B1: matriz de permisos dice "todos" y el texto exige `includeInactive`                                  | architect                                        |
| —    | `flutter run -d windows` contra el backend real y seed ejecutado: no verificados                           | Usuario                                          |

## 6. Criterios de aceptación de la fase

- [x] Flujo documentado (`flujo.md`)
- [x] Diagrama entidad-relación consolidado y coherente con `schema.prisma` (`diagrama-er.md`)
- [x] Pruebas unitarias ejecutadas (resultados reales adjuntos en `pruebas-unitarias.md`)
- [x] Manual de usuario actualizado (`manual-usuario.md`)
- [x] Documentación técnica actualizada (`documentacion-tecnica.md`)
- [x] `test-plan.md` y `test-report.md` con resultados reales
- [ ] Pruebas con PostgreSQL real ejecutadas (pendiente: D-05)

## 7. Aprobación

| Rol           | Nombre | Fecha |
| ------------- | ------ | ----- |
| QA            |        |       |
| Usuario final |        |       |
