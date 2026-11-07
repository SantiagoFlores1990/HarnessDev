# Entregable — Fase 9: Mantenimiento y documentación final

- **Proyecto:** Good Pizza (pizzería con pedidos personalizados; backend Node.js + frontend Flutter Windows)
- **Rama:** `testHarness` · **Fecha:** 2026-11-06
- **Agente responsable:** maintenance-docs
- **Versión:** 1.0

## 1. Objetivo de la fase

Cerrar el ciclo de vida del proyecto: documentar la operación, el estado real, el backlog priorizado, el registro de cambios y los entregables consolidados. Verificar los conteos y las afirmaciones contra el código y los informes, y dejar listadas (sin aplicar) las correcciones de las fases 02, 03, 04, 05 y 07, porque la regla del proyecto impide reescribir sus documentos desde esta fase.

## 2. Resumen ejecutivo

- La aplicación funciona de extremo a extremo según el código: 25 endpoints, motor de cálculo único, 15 tablas con 9 CHECK, cliente y administrador con las 13 pantallas. Seis ítems de prioridad P0 bloquean el uso en el local (ver sección 5).
- **Estado de verificación real:** backend 267 pruebas pasan y 22 se omiten (requieren PostgreSQL de pruebas); lint limpio; frontend 225 pruebas pasan, `flutter analyze` limpio, `integration_test` en Windows pasa y `flutter build windows` compila tras instalar ATL.
- **Veredictos:** QA, GO condicionado (falta ejecutar las 22 pruebas con base real). Seguridad, GO condicionado a la condición C1 (secretos JWT robustos o `NODE_ENV=production`). Hallazgo alto de aplicación S-01 y alto de entorno H-01.
- **Fase 8 omitida** por decisión del usuario: Docker no está instalado. No hay entregables de DevOps; figura como fuera de alcance en el CHANGELOG, el backlog (MF-02) y este documento.
- **Entregados en esta fase:** README raíz (guía original conservada y sección del proyecto), CHANGELOG 0.1.0, runbook, backlog priorizado (P0/P1/P2, deuda y mejoras), lista de correcciones pendientes (20 entradas) y los seis entregables de la skill.
- **No se ha tocado** `backend/.env.local`, ningún `.env*`, ninguna base de datos, `.claude/settings.json` ni los hooks. No se ha hecho commit ni push.
- **No se han vuelto a ejecutar pruebas** en esta fase: las cifras son las de los informes de cada fase y los estados verificados que comunicó el orquestador. Se indica la fuente en cada caso.

## 3. Artefactos producidos

| Artefacto               | Ruta                                             | Descripción                                                                                                                                |
| ----------------------- | ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| README raíz             | `README.md`                                      | Guía de la plantilla conservada íntegra y nueva sección "Proyecto Good Pizza (rama testHarness)"                                           |
| Changelog               | `CHANGELOG.md`                                   | Versión 0.1.0; fases 1 a 9; cambios, seguridad, omitido y pendiente                                                                        |
| Runbook                 | `docs/09-maintenance/runbook.md`                 | Operación local: arranque, salud, variables, rotación de secretos, respaldo y restauración, migraciones, esquema `test`, logs e incidentes |
| Backlog                 | `docs/09-maintenance/backlog.md`                 | Hallazgos de QA y seguridad, observaciones nuevas, deuda técnica y mejoras futuras, con responsable y criterio de cierre                   |
| Correcciones pendientes | `docs/09-maintenance/correcciones-pendientes.md` | 20 correcciones exactas (archivo, texto actual, texto correcto) para las fases 02, 03, 04, 05, 07 y `docs/DEMO.md`                         |
| Entregable              | `docs/09-maintenance/entregable.md`              | Este documento: resumen consolidado de todas las fases                                                                                     |
| Flujo                   | `docs/09-maintenance/flujo.md`                   | Proceso SDLC con estado, flujos de cliente, administrador, autenticación, confirmación transaccional y operación                           |
| Diagrama ER             | `docs/09-maintenance/diagrama-er.md`             | ER final consolidado, igual al `schema.prisma`, con diccionario de datos y CHECK                                                           |
| Pruebas                 | `docs/09-maintenance/pruebas-unitarias.md`       | Resultados reales consolidados por fase, con fuente y fecha                                                                                |
| Manual de usuario       | `docs/09-maintenance/manual-usuario.md`          | Manual en español para cliente y administrador, paso a paso                                                                                |
| Documentación técnica   | `docs/09-maintenance/documentacion-tecnica.md`   | Consolidado técnico: arquitectura, versiones, configuración, API, motor, datos, frontend, pruebas, operación y seguridad                   |

No se han modificado documentos de otras fases ni código de `backend/` o `frontend/`.

## 4. Decisiones y supuestos

- **Alcance documental:** las correcciones de otras fases se registran en `correcciones-pendientes.md`; las aplica el orquestador con ediciones puntuales.
- **Fuente de verdad:** prevalece el código y, después, el informe de QA y el de seguridad más recientes (fase 6 y fase 7). Las contradicciones se anotan (sección 7).
- **Versión:** el changelog usa `0.1.0` porque es la versión de `backend/package.json` y la indicada en el encargo. El frontend declara `1.0.0+1` en `pubspec.yaml`. Queda como pregunta abierta (N-05).
- **Fase 8:** omitida sin entregables. El README raíz de la plantilla menciona DevOps en la tabla de agentes; se conserva porque forma parte de la plantilla.
- **Datos de ejemplo:** las cifras de precios, stock y calorías del seed son ilustrativas. Se indica en el manual y en la documentación técnica.
- **Contraseñas:** no aparecen en ningún documento. En el runbook las credenciales se representan como `<USUARIO>`, `<CONTRASENA>` y `<SECRETO>`.
- **Idioma:** documentación en español; identificadores de código en inglés.

## 5. Riesgos y pendientes

Bloqueantes para operar en el local (P0 del backlog):

| ID        | Pendiente                                                                                                            | Responsable                                             |
| --------- | -------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------- |
| C1 / S-01 | Secretos JWT robustos (32 o más, distintos, no los de la plantilla) o `NODE_ENV=production` en `backend/.env.local`  | Usuario; backend-dev para validar en todos los entornos |
| D-05      | Definir `DATABASE_URL_TEST` (esquema `test`), ejecutar `npm run db:test:migrate` y `npm test`: 22 pruebas pendientes | Usuario; qa-engineer para registrar                     |
| H-01      | Permisos de Claude Code que permiten comandos destructivos sobre la base sin confirmación                            | Usuario                                                 |
| R-03      | Ejecutar `npm run db:seed` sobre `pizzeria` y guardar las contraseñas que imprime                                    | Usuario                                                 |
| G-12      | `flutter run -d windows` contra la API real con datos del seed (lista de humo)                                       | Usuario; qa-engineer para registrar                     |
| N-01      | `docs/DEMO.md` propone `prisma migrate reset` sobre la base del proyecto                                             | maintenance-docs (texto); usuario (aprobación)          |

Pendientes de decisión (P1): acceso en red (S-04), límites por IP en un PC (S-02), modelo de PC compartido (S-03), tope de pedidos y cancelación (S-06, MF-01), usuario desactivado 15 min (S-07), `npm audit fix` y migraciones de dependencias (S-08, S-09), política de contraseñas (S-10), ajustes de `.claude/settings.json` y hooks (H-02, H-03).

Riesgos operativos: no hay copia de seguridad automatizada, monitoreo ni gestión de usuarios (N-06, N-07). El runbook documenta los procedimientos manuales.

## 6. Criterios de aceptación de la fase

- [x] Flujo documentado (`flujo.md`)
- [x] Diagrama entidad-relación actualizado y coincidente con `schema.prisma` (`diagrama-er.md`)
- [x] Pruebas: resultados reales consolidados con fuente y fecha (`pruebas-unitarias.md`). Sin ejecución nueva en esta fase
- [x] Manual de usuario actualizado (`manual-usuario.md`)
- [x] Documentación técnica actualizada (`documentacion-tecnica.md`)
- [x] README raíz con la guía original conservada y la sección del proyecto
- [x] CHANGELOG 0.1.0 con fases 1 a 9 y lo omitido
- [x] Runbook y backlog con todos los hallazgos de QA (D-01..D-06, G-11..G-13) y seguridad (C1, C2, S-01..S-18, H-01..H-04, SEC-N01..N13)
- [x] Correcciones de otras fases listadas, no aplicadas
- [ ] Correcciones de otras fases aplicadas (pendiente del orquestador)
- [ ] Pruebas con PostgreSQL real ejecutadas (pendiente del usuario, D-05)
- [ ] Revisión y aprobación por el responsable del producto

## 7. Contradicciones detectadas

| #   | Contradicción                                                                                                                   | Fuente de verdad                            | Corrección                 |
| --- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------- | -------------------------- |
| 1   | `API_BASE_URL` (fases 2 y 3) frente a `API_URL` (código y fase 5)                                                               | Código: `API_URL`                           | Correcciones 13, 17 y 19   |
| 2   | Fase 5 dice que `flutter build windows` falla por ATL; hoy compila tras instalar el componente                                  | Fase 6 (QA, D-01)                           | Correcciones 1 a 7         |
| 3   | Conteos de pruebas de las fases 4 y 5 (190 y 221) frente a la ejecución de QA (289 en total; 225 Flutter)                       | Fase 6 (QA, D-02)                           | Correcciones 2 a 5, 8 a 10 |
| 4   | Arquitectura §4: "en operaciones sensibles se verifica que el usuario siga activo"; el código solo lo hace en unas pocas rutas  | Código y S-07                               | Corrección 14              |
| 5   | Arquitectura §2.2 y §3.2: estructura propuesta (`*.routes.js`, `presets`) frente a la real (`routes/index.js`, `preset_pizzas`) | Código y `docs/04`, `docs/05`               | Corrección 16              |
| 6   | Arquitectura §5: `NODE_ENV` y `PORT` obligatorias; el código tiene valores por defecto                                          | Código (`env.js`)                           | Corrección 15              |
| 7   | Fase 2, R-06: los CHECK se añadirían en la migración inicial; se añadieron en una migración posterior                           | Migraciones y `docs/04`                     | Corrección 18              |
| 8   | Contrato §3: el ADMIN "ve todos" en listados; el texto exige `includeInactive=true`                                             | Código y PA-B1                              | Corrección 20              |
| 9   | `docs/DEMO.md` propone `prisma migrate reset` sobre la base; la regla del proyecto prohíbe borrar `pizzeria`                    | Prompt del proyecto                         | Corrección 12              |
| 10  | `docs/04-backend/README.md` presenta `db:migrate` como forma de aplicar migraciones; en el local debe usarse `db:deploy`        | `package.json` y buenas prácticas de Prisma | Corrección 11              |
| 11  | Versiones: backend `0.1.0` y frontend `1.0.0+1`                                                                                 | `package.json` y `pubspec.yaml`             | Pregunta abierta N-05      |
| 12  | `env.template` trae `change-me` como ejemplo; el arranque en `development` los acepta                                           | Código y S-01                               | C1 en backlog              |

## 8. Resumen consolidado de todas las fases (estado real)

| Fase            | Agente            | Estado                    | Entregables                                                                                               | Resultado real                                                                                   | Pendiente                                                |
| --------------- | ----------------- | ------------------------- | --------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | -------------------------------------------------------- |
| 1 Requisitos    | requirements      | Completada                | 6 + `requirements.md`, `user-stories.md`, `glossary.md`                                                   | 29 RF, 10 RNF, 23 US, supuestos S-01..S-26                                                       | Ninguno                                                  |
| 2 Arquitectura  | architect         | Completada                | 6 + `architecture.md`, `data-model.md`, `api-contract.md`, 11 ADR                                         | 25 endpoints, 24 códigos, 15 entidades                                                           | Estructura y variables (correcciones 13 a 18)            |
| 3 Diseño UX     | ux-designer       | Completada                | 6 + `user-flows.md`, `screens.md`, `design-system.md`, `responsive.md`, `accesibilidad.md`, logotipos SVG | 13 pantallas, paleta azul marino, 45 pares de contraste (mínimo 4,94:1)                          | Confirmación de PA-UX-01..09                             |
| 4 Backend       | backend-dev       | Completada con pendientes | 6 + `README.md`, código, migraciones, seed, pruebas                                                       | 190 pruebas en la fecha de la fase; hoy 267 + 22 omitidas; lint limpio                           | Seed sobre `pizzeria` y pruebas de integración (usuario) |
| 5 Frontend      | flutter-dev       | Completada                | 6 + `README.md`, `frontend/`                                                                              | 221 pruebas en la fecha de la fase; hoy 225 + 1 de integración; compila con ATL                  | Arranque contra backend real (G-12)                      |
| 6 QA            | qa                | GO condicionado           | 6 + `test-plan.md`, `test-report.md`                                                                      | 267 pasan, 22 omitidas; Flutter 225 pasan; cobertura servicios 97,11 %; 6 hallazgos (D-01..D-06) | D-05 (base real); D-01..D-06 (correcciones y decisiones) |
| 7 Seguridad     | security-reviewer | GO condicionado           | 6 + `security-report.md`                                                                                  | 0 críticos; 1 alto de aplicación (S-01); 5 medias (S-02..S-06); H-01 alto de entorno             | C1; S-01..S-18; H-01..H-04                               |
| 8 DevOps        | devops-engineer   | **Omitida**               | Ninguno                                                                                                   | Docker no instalado; decisión del usuario                                                        | Fuera de alcance (MF-02)                                 |
| 9 Mantenimiento | maintenance-docs  | Completada                | 6 + README, CHANGELOG, runbook, backlog, correcciones                                                     | Documentación verificada contra código e informes                                                | Aplicar correcciones (orquestador)                       |

Nota de la fase 1: `pruebas-unitarias.md` contiene casos de aceptación Given/When/Then (no se ejecutan). En la fase 3, los casos de widget previstos se ejecutaron después como WT-01..WT-30 en la fase 5.

## 9. Preguntas abiertas consolidadas

Decisiones registradas en los entregables anteriores (no requieren acción): PA-01 (pruebas de integración en el esquema `test`, opción A; `docs/04`), PA-05 (solo el rol CLIENT confirma pedidos) y PA-06 (el catálogo del cliente incluye el stock), según el entregable de la fase 4. Las reglas S-17..S-26 de los requisitos son firmes.

PA-02, PA-03 y PA-04 (baja lógica de predefinidas; la receta no cambia masa ni salsa; una sola masa y una sola salsa por pizza) mantienen el supuesto aplicado en la fase 2. Ese supuesto es coherente con ADR-010 y con las reglas firmes, pero no consta como confirmado por el usuario de forma explícita.

Abiertas o con supuesto aplicado que requiere confirmación:

| ID                                                                           | Fase | Pregunta                                                                                                         | Supuesto vigente                                       |
| ---------------------------------------------------------------------------- | ---- | ---------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| PA-UX-01                                                                     | 3    | Separador decimal: punto o coma                                                                                  | Punto (`$ 7.50`)                                       |
| PA-UX-02                                                                     | 3    | Tamaño mínimo de ventana                                                                                         | Recomendado 1024 × 680, sin forzarlo                   |
| PA-UX-05                                                                     | 3    | Endpoint específico para la vista previa de predefinidas                                                         | Se usa `quote`; MF-06                                  |
| PA-UX-07                                                                     | 3    | Actualización automática del estado del pedido del cliente                                                       | Manual (MF-05)                                         |
| PA-UX-09                                                                     | 3    | Pie del comprobante "No es una factura electrónica"                                                              | Sí                                                     |
| PA-B1 / D-06                                                                 | 4, 6 | ¿El ADMIN ve todos o solo activos por defecto en listados?                                                       | Solo activos; `includeInactive=true` (correcciones 20) |
| PA-B2                                                                        | 4    | Snapshot del código de predefinida                                                                               | `null` si desaparece                                   |
| PA-B3                                                                        | 4    | `code` en `quote.stock[]`                                                                                        | Contrato literal                                       |
| PA-B4                                                                        | 4    | `search` de pedidos para CLIENT                                                                                  | Se ignora                                              |
| PA-B5                                                                        | 4    | Orden de 422 y 409                                                                                               | Reglas, luego stock, luego precio                      |
| PA-F1                                                                        | 5    | ¿Listas admin con inactivos visibles?                                                                            | Sí                                                     |
| PA-F3                                                                        | 5    | Botón ☰ y tecla F6                                                                                              | No incluidos (MF-08)                                   |
| PA-F4                                                                        | 5    | Mensaje de stock de masa o salsa en predefinidas                                                                 | Servidor valida                                        |
| D-03 / S-07                                                                  | 6, 7 | Usuario desactivado con acceso de lectura hasta 15 min                                                           | Aceptado mientras no se decida otra cosa               |
| 1 a 7                                                                        | 7    | Preguntas de seguridad: C1, modelo de PC compartido, red, tope de pedidos, desactivación, `npm audit fix`, hooks | Sin decidir                                            |
| N-03 a N-05, N-09, N-10                                                      | 9    | Clave foránea de `replaced_by_id`, versión de entrega, almacén de límites en memoria, datos del esquema `test`   | Sin decidir                                            |
| RPO, RTO, copias, rotación, cambio de contraseña de administrador, monitoreo | 9    | Preguntas operativas                                                                                             | Ver `runbook.md` sección 13                            |

## 10. Comandos de ejecución (resumen para el usuario)

```bash
# 1. Preparar el entorno (raíz del repositorio, rama testHarness)
git switch testHarness
node scripts/setup.js                 # crea backend/.env.local si no existe

# 2. Editar backend/.env.local (no se versiona): DATABASE_URL, JWT_SECRET y JWT_REFRESH_SECRET
#    robustos y distintos, NODE_ENV=production en el local. Opcional: SEED_*_PASSWORD.

# 3. Backend
cd backend
npm install
npm run db:deploy                     # aplicar migraciones existentes (sin crear nuevas)
npm run db:seed                       # datos de ejemplo; las contraseñas generadas se muestran una vez
npm start                             # API en http://localhost:3000/api/v1 (o npm run dev)
curl http://localhost:3000/api/v1/health

# 4. Pruebas de backend
npm test                              # 267 pasan, 22 omitidas sin DATABASE_URL_TEST
npm run lint

# 5. Pruebas de integración con PostgreSQL (pendiente)
#    En backend/.env.local añadir DATABASE_URL_TEST con ?schema=test, y luego:
npm run db:test:migrate
npm test                              # debe ejecutar las 22 pruebas

# 6. Aplicación Windows
cd ../frontend
flutter pub get
flutter run -d windows                                                        # API local por defecto
flutter run -d windows --dart-define=API_URL=http://localhost:3000/api/v1
flutter build windows --release --dart-define=API_URL=http://localhost:3000/api/v1
flutter analyze
flutter test
flutter test integration_test/app_flow_test.dart -d windows
```

Documentación de consulta: `README.md`, `CHANGELOG.md`, `docs/09-maintenance/runbook.md`, `docs/09-maintenance/backlog.md` y `docs/09-maintenance/manual-usuario.md`.

## 11. Aprobación

| Rol                                   | Nombre               | Fecha      |
| ------------------------------------- | -------------------- | ---------- |
| Responsable de mantenimiento (agente) | maintenance-docs     | 2026-11-06 |
| Responsable del producto              | (pendiente: usuario) |            |
| Revisión de seguridad (C1 y S-01)     | (pendiente: usuario) |            |
