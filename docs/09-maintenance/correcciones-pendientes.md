# Correcciones pendientes en otras fases

- **Proyecto:** Good Pizza · rama `testHarness` · **Fecha:** 2026-11-06
- **Propósito:** lista exacta de correcciones de documentación en las fases 02, 03, 04, 05 y 07, y en `docs/DEMO.md`. Según la regla del proyecto, la fase 9 **no reescribe** los documentos de otras fases: el orquestador las aplicará con ediciones puntuales.
- **Cómo se comprobó:** cada conteo y cada afirmación se contrastó con el código (`Grep`/`Glob` sobre `backend/` y `frontend/`), con `schema.prisma` y con los informes de QA (`docs/06-qa/test-report.md`) y de seguridad (`docs/07-security/security-report.md`).
- **Convención:** el texto actual aparece entre comillas invertidas tal como consta en el archivo. En tablas Markdown el espaciado de relleno puede diferir; la búsqueda debe hacerse por el fragmento de texto.

## Resumen

| #   | Archivo                                         | Corrección                                               | Origen          | Prioridad |
| --- | ----------------------------------------------- | -------------------------------------------------------- | --------------- | --------- |
| 1   | `docs/05-frontend/entregable.md`                | Compilación de Windows: deja de estar bloqueada          | D-01            | Alta      |
| 2   | `docs/05-frontend/README.md`                    | Conteo de pruebas Flutter                                | D-02            | Alta      |
| 3   | `docs/05-frontend/entregable.md`                | Conteo de pruebas y pie de resultados                    | D-02            | Alta      |
| 4   | `docs/05-frontend/documentacion-tecnica.md`     | Conteo, cobertura y estado de la compilación             | D-01, D-02      | Alta      |
| 5   | `docs/05-frontend/pruebas-unitarias.md`         | Estado de la compilación y conteo total                  | D-01, D-02      | Alta      |
| 6   | `docs/05-frontend/documentacion-tecnica.md`     | Paso de ejecución bloqueado por ATL                      | D-01            | Alta      |
| 7   | `docs/05-frontend/flujo.md`                     | Rama de decisión ATL                                     | D-01            | Media     |
| 8   | `docs/04-backend/entregable.md`                 | Conteo de pruebas de la fase 4 con nota de actualización | D-02            | Alta      |
| 9   | `docs/04-backend/pruebas-unitarias.md`          | Total de pruebas                                         | D-02            | Alta      |
| 10  | `docs/04-backend/documentacion-tecnica.md`      | Total de pruebas                                         | D-02            | Alta      |
| 11  | `docs/04-backend/README.md`                     | Scripts de migración (`db:deploy`)                       | Revisión fase 9 | Baja      |
| 12  | `docs/DEMO.md`                                  | `prisma migrate reset` sobre la base del proyecto        | N-01 (riesgo)   | Alta      |
| 13  | `docs/02-architecture/architecture.md`          | Nombre de la variable de la API en Flutter               | N-04            | Media     |
| 14  | `docs/02-architecture/architecture.md`          | Comprobación de "activo" en operaciones sensibles        | N-02            | Media     |
| 15  | `docs/02-architecture/architecture.md`          | Obligatoriedad de `NODE_ENV` y `PORT`                    | Revisión fase 9 | Baja      |
| 16  | `docs/02-architecture/architecture.md`          | Nota sobre la estructura propuesta frente a la real      | DT-05           | Baja      |
| 17  | `docs/02-architecture/documentacion-tecnica.md` | Nombre de la variable de la API (`API_BASE_URL`)         | N-04            | Media     |
| 18  | `docs/02-architecture/entregable.md`            | Mitigación R-06 de los CHECK                             | Revisión fase 9 | Baja      |
| 19  | `docs/03-design/documentacion-tecnica.md`       | Nombre de la variable de la API                          | N-04            | Media     |
| 20  | `docs/02-architecture/api-contract.md`          | Matriz de permisos de ADMIN en listados                  | D-06 / PA-B1    | Baja      |

---

## 1. `docs/05-frontend/entregable.md` (D-01)

**Ubicación:** §2 "Resumen ejecutivo", punto 8 (línea 21).

- **Texto actual:** `8. **Limitación del entorno:** \`flutter build windows --debug\` falla por falta de ATL en Visual Studio Build Tools (\`atlstr.h\`); no se pudo compilar ni arrancar el ejecutable. Acción requerida del usuario en §5.`
- **Texto correcto:** `8. **Requisito del entorno:** \`flutter build windows --debug\` compila con el componente ATL de Visual Studio Build Tools instalado (verificado en la fase 6: \`good_pizza.exe\`). Sin ATL falla con \`atlstr.h\`. El arranque del ejecutable contra el backend real queda pendiente (QA G-12).`

**Ubicación:** §5 "Riesgos y pendientes", primera fila de la tabla.

- **Texto actual:** `| **Bloqueante de entorno** | \`flutter build windows --debug\` falla: \`error C1083: ...'atlstr.h'\` ... | Instalar "C++ ATL ..." ... |`
- **Texto correcto:** tipo `Requisito de entorno (resuelto en la fase 6)`. Descripción: "`flutter build windows --debug` compila tras instalar el componente ATL. Sin él aparece `error C1083: No se puede abrir el archivo incluir: 'atlstr.h'`". Acción: "Mantener el componente ATL instalado; ver `docs/05-frontend/README.md`, sección Solución de problemas". Conservar el resto de la fila.

**Ubicación:** §6 "Criterios de aceptación", línea 79.

- **Texto actual:** `- [ ] \`flutter build windows --debug\` y \`flutter run -d windows\` (bloqueado por ATL; criterio de aceptación 4 del proyecto pendiente de verificar en el equipo del usuario)`
- **Texto correcto:** `- [x] \`flutter build windows --debug\` (compila tras instalar ATL; verificado en la fase 6)`y una segunda línea`- [ ] \`flutter run -d windows\` contra el backend real con datos del seed (pendiente; QA G-12)`.

**Ubicación:** §6, línea 76 (conteo, ver punto 3).

## 2. `docs/05-frontend/README.md` (D-02)

**Ubicación:** bloque de código de la sección "Pruebas", línea 44.

- **Texto actual:** `flutter test               # 221 pruebas (unitarias, de widget y de flujo)`
- **Texto correcto:** `flutter test               # 225 pruebas (unitarias, de widget y de flujo); verificado en la fase 6`
- **Línea adicional recomendada, bajo `flutter test --coverage`:** `flutter test integration_test/app_flow_test.dart -d windows   # 1 prueba de escritorio con repositorios falsos`

**Ubicación:** sección "Requisitos", fila "Visual Studio", línea 11.

- **Texto actual:** frase "Sin ATL, `flutter build windows` y `flutter run -d windows` fallan (ver \"Solución de problemas\")."
- **Texto correcto:** "Sin ATL, `flutter build windows` y `flutter run -d windows` fallan (ver \"Solución de problemas\"). Con el componente instalado, la compilación funciona (verificado en la fase 6)."

## 3. `docs/05-frontend/entregable.md` (D-02)

**Ubicación:** §2, punto 7 (línea 20).

- **Texto actual:** `7. 221 pruebas automatizadas (WT-01..WT-30 + flujo completo) con 93,2 % de cobertura de líneas; \`flutter analyze\` sin incidencias.`
- **Texto correcto:** `7. 221 pruebas automatizadas en esta fase (WT-01..WT-30 + flujo completo), con 93,2 % de cobertura de líneas. En la fase 6 pasan 225 pruebas de \`flutter test\` (93,3 %) y 1 de \`integration_test\` en Windows; \`flutter analyze\` sin incidencias.`

**Ubicación:** §6 "Criterios de aceptación", línea 76.

- **Texto actual:** `(resultados reales adjuntos en \`pruebas-unitarias.md\`: 221 pruebas OK, \`flutter analyze\` sin incidencias)`
- **Texto correcto:** `(resultados reales adjuntos en \`pruebas-unitarias.md\`: 221 pruebas OK en esta fase; 225 en la fase 6; \`flutter analyze\` sin incidencias)`

## 4. `docs/05-frontend/documentacion-tecnica.md` (D-01, D-02)

**Ubicación:** sección de pruebas, línea 149.

- **Texto actual:** `221 pruebas (\`flutter test\`), cobertura de líneas 93,2 %, \`flutter analyze\` sin incidencias.`
- **Texto correcto:** `225 pruebas (\`flutter test\`) en la fase 6 (221 en la fase 5), cobertura de líneas 93,3 %, \`flutter analyze\` sin incidencias, y 1 prueba de \`integration_test\` en Windows.`

**Ubicación:** lista de pendientes, línea 169.

- **Texto actual:** `- Compilar y ejecutar el \`.exe\` (bloqueado por ATL en el equipo de desarrollo).`
- **Texto correcto:** `- Ejecutar el \`.exe\` contra el backend real con datos del seed (la compilación funciona con ATL instalado; verificado en la fase 6).`

**Ubicación:** sección de ejecución, línea 145.

- **Texto actual:** frase "Requiere Visual Studio con C++ y **ATL**, y Modo desarrollador de Windows."
- **Texto correcto:** sin cambio funcional; añadir "(la compilación falla sin el componente ATL, que es el requisito de la fase 5)". Opcional.

## 5. `docs/05-frontend/pruebas-unitarias.md` (D-01, D-02)

**Ubicación:** línea 11, al inicio del documento.

- **Texto actual:** `- No se ejecutó la aplicación compilada: \`flutter build windows --debug\` falla por falta de ATL en el equipo (ver "Resultados"). Las pruebas no cubren ...`
- **Texto correcto:** `- La compilación de Windows funciona tras instalar el componente ATL (verificado en la fase 6: \`good_pizza.exe\`). No se ha ejecutado la aplicación contra el backend real. Las pruebas no cubren ...` (el resto de la frase se conserva).

**Ubicación:** línea 142, dentro de "Lo que no está verificado".

- **Texto actual:** `- Compilación y arranque del ejecutable de Windows (\`flutter build windows\` / \`flutter run -d windows\`): bloqueado por ATL.`
- **Texto correcto:** `- Arranque del ejecutable de Windows contra el backend real (\`flutter run -d windows\`): pendiente. La compilación sí funciona tras instalar ATL (fase 6).`

**Ubicación:** línea 109 (salida histórica "TOTAL 221 pruebas").

- **Corrección:** no reescribir la salida. Añadir inmediatamente debajo: `Nota (fase 9): salida de la fase 5. En la fase 6 la ejecución dio 225 pruebas pasando y 1 de integración en Windows.`

**Ubicación:** línea 121 (texto de entorno sin ATL).

- **Corrección:** conservar como registro histórico y añadir: `Nota (fase 9): este bloqueo quedó resuelto al instalar el componente ATL; ver la fase 6.`

## 6. `docs/05-frontend/documentacion-tecnica.md` (D-01)

Ver punto 4 (línea 169). La línea 145 se mantiene.

## 7. `docs/05-frontend/flujo.md` (D-01)

**Ubicación:** diagrama de la fase, línea 15.

- **Texto actual:** `    H -- "No: falta ATL (entorno)" --> I[Reportar error exacto y acción al usuario]`
- **Texto correcto:** `    H -- "No: falta ATL (entorno; resuelto en fase 6)" --> I[Reportar error exacto y acción al usuario]`

## 8. `docs/04-backend/entregable.md` (D-02)

**Ubicación:** §2 "Resumen ejecutivo", punto 6 (línea 19).

- **Texto actual:** `6. 190 pruebas (Vitest + Supertest): 168 pasan sin BD; 22 de integración usan solo el esquema \`test\` y pasaron (190/190) cuando se habilitaron; \`npm test\` actual las omite con aviso porque \`DATABASE_URL_TEST\` no está en \`.env.local\`. \`npm run lint\`: 0 errores, 0 advertencias.`
- **Texto correcto:** conservar el texto y añadir al final: ` [Cifra de la fase 4. Actualización de QA (fase 6): \`npm test\` da 267 pasan y 22 omitidas (289 en total); \`npm run lint\` limpio.]`

**Ubicación:** §6 "Criterios de aceptación", línea 76 (sin cambio de estado): mantener `[ ] Pruebas de integración habilitadas por defecto` y añadir la nota "pendiente del usuario (ver backlog D-05)".

## 9. `docs/04-backend/pruebas-unitarias.md` (D-02)

**Ubicación:** línea 15.

- **Texto actual:** `Total: 190 pruebas (168 sin BD + 22 de integración).`
- **Texto correcto:** `Total en la fase 4: 190 pruebas (168 sin BD + 22 de integración). Ejecución de QA en la fase 6: 289 (267 pasan + 22 omitidas sin DATABASE_URL_TEST).`

**Ubicación:** líneas 80 y 100 (salidas históricas de la fase 4: "Tests 168 passed | 22 skipped (190)" y "Tests 190 passed (190)").

- **Corrección:** no reescribir. Añadir una nota: `Nota (fase 9): salida de la fase 4. Para la última ejecución, ver docs/06-qa/test-report.md.`

## 10. `docs/04-backend/documentacion-tecnica.md` (D-02)

**Ubicación:** línea 127.

- **Texto actual:** `... Detalle y salida real en \`pruebas-unitarias.md\`: 190 pruebas (168 sin BD, 22 de integración solo en el esquema \`test\`).`
- **Texto correcto:** `... Detalle y salida real en \`pruebas-unitarias.md\`: 289 pruebas en la fase 6 (267 pasan sin BD; 22 de integración solo en el esquema \`test\`, que se omiten sin \`DATABASE_URL_TEST\`).`

## 11. `docs/04-backend/README.md` (revisión de la fase 9, prioridad baja)

**Ubicación:** bloque "Cómo correrlo", línea 12.

- **Texto actual:** `npm run db:migrate                 # aplica las migraciones a la base \`pizzeria\` (esquema public)`
- **Texto correcto:** `npm run db:deploy                  # aplica las migraciones existentes a \`pizzeria\` (esquema public); uso recomendado en el local`y añadir:`npm run db:migrate # prisma migrate dev: crea migraciones nuevas; solo en desarrollo`
- **Añadir también:** `npm run db:generate` (genera el cliente de Prisma) y `npm run db:studio` (explorador de datos; no lo ejecutes contra \`pizzeria\` sin necesidad).

## 12. `docs/DEMO.md` (N-01, riesgo alto)

**Ubicación:** línea 39.

- **Texto actual:** `Para reutilizar la misma base de datos, vacíala antes de la siguiente demo. Esto **borra todos los datos** de la base indicada en \`.env.local\`:`
- **Texto correcto:** `Para reutilizar la misma base de datos, vacíala antes de la siguiente demo. Esto **borra el esquema \`public\` completo** de la base indicada en \`.env.local\`. **No lo ejecutes nunca sobre \`pizzeria\`**, que es la base del proyecto y no debe borrarse ni recrearse:`

**Ubicación:** línea 46.

- **Texto actual:** `Solo funciona después de que el agente cree el esquema de Prisma. Alternativa más simple: crea una base distinta por demostración (\`pizzeria_demo2\`) y cambia \`DB_NAME\` y \`DATABASE_URL\`.`
- **Texto correcto:** `Alternativa recomendada, sin borrar nada: crea una base distinta por demostración (\`pizzeria_demo2\`) y cambia \`DB_NAME\` y \`DATABASE_URL\`. Revisa antes el nombre de la base con \`psql\` (\`\\l\`).`

## 13. `docs/02-architecture/architecture.md` (N-04)

**Ubicación:** §2.2, línea 240 (árbol de carpetas).

- **Texto actual:** `│   │   ├── config/app_config.dart       # API_BASE_URL vía --dart-define`
- **Texto correcto:** `│   │   ├── config/app_config.dart       # API_URL vía --dart-define (incluye /api/v1)`

**Ubicación:** §5, línea 337.

- **Texto actual:** `Frontend: \`API_BASE_URL\` por \`--dart-define\` (por defecto \`http://localhost:3000/api/v1\`), leído en \`core/config/app_config.dart\`. Sin secretos en el frontend.`
- **Texto correcto:** `Frontend: \`API_URL\` por \`--dart-define\` (por defecto \`http://localhost:3000/api/v1\`), leído con \`String.fromEnvironment\` en \`lib/core/config/app_config.dart\`. Sin secretos en el frontend.`

## 14. `docs/02-architecture/architecture.md` (N-02)

**Ubicación:** §4 "Autenticación y autorización", última viñeta (línea 308).

- **Texto actual:** `- El rol se lee del token, pero en operaciones sensibles el servicio verifica que el usuario siga activo.`
- **Texto correcto:** `- El rol se lee del token y no se revalida en cada petición. Solo \`POST /orders\`, el login, el refresh y \`GET /auth/me\` comprueban que el usuario siga activo. Un usuario desactivado conserva acceso de lectura hasta que caduca el access token (15 min); ver el hallazgo S-07 de seguridad.`

## 15. `docs/02-architecture/architecture.md` (revisión de la fase 9, prioridad baja)

**Ubicación:** §5, tabla de variables, filas `NODE_ENV` y `PORT`.

- **Texto actual de la columna Obligatoria:** `sí` en ambas filas.
- **Texto correcto:** `no (def. \`development\`)`en`NODE_ENV`y`no (def. \`3000\`)`en`PORT`. El código (`backend/src/config/env.js`) tiene valores por defecto y `docs/04-backend/README.md` ya lo indica.

## 16. `docs/02-architecture/architecture.md` (DT-05, prioridad baja)

**Ubicación:** justo después del bloque de código de §2.2 "Estructura de carpetas propuesta (`backend/`)", antes de "### 2.3 Motor de cálculo".

- **Texto actual:** no existe nota.
- **Texto correcto (añadir):** `> Nota (fase 9): esta es la estructura propuesta en la fase 2. La estructura real está en \`docs/04-backend/documentacion-tecnica.md\` (por ejemplo, \`routes/index.js\` en lugar de \`*.routes.js\`) y en \`docs/05-frontend/documentacion-tecnica.md\` (\`features/preset_pizzas\` y \`features/admin\`).`

**Ubicación:** §3.2, árbol de \`frontend/lib/features\`. Mismo tratamiento: añadir la misma referencia.

## 17. `docs/02-architecture/documentacion-tecnica.md` (N-04)

**Ubicación:** línea 69.

- **Texto actual:** `Frontend: \`API_BASE_URL\` vía \`--dart-define\` (def. \`http://localhost:3000/api/v1\`).`
- **Texto correcto:** `Frontend: \`API_URL\` vía \`--dart-define\` (def. \`http://localhost:3000/api/v1\`).`

**Ubicación:** línea 115.

- **Texto actual:** `flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3000/api/v1`
- **Texto correcto:** `flutter run -d windows --dart-define=API_URL=http://localhost:3000/api/v1`

**Ubicación:** línea 128 (frase final).

- **Texto actual:** `... la app Windows apunta a la API por \`API_BASE_URL\`. ...`
- **Texto correcto:** `... la app Windows apunta a la API por \`API_URL\`. ...`

## 18. `docs/02-architecture/entregable.md` (revisión de la fase 9, prioridad baja)

**Ubicación:** §5 "Riesgos", fila R-06 (línea 70).

- **Texto actual:** `| R-06 | Prisma no modela CHECK; podrían perderse al regenerar migraciones. | Se añaden en la migración inicial (\`--create-only\`) y QA verifica su existencia. |`
- **Texto correcto:** `| R-06 | Prisma no modela CHECK; podrían perderse al regenerar migraciones. | Se añadieron en la migración \`20261106190500_add_check_constraints\`, porque la migración inicial ya estaba aplicada (ver \`docs/04-backend/README.md\`). QA verifica su existencia. |`

## 19. `docs/03-design/documentacion-tecnica.md` (N-04)

**Ubicación:** línea 62.

- **Texto actual:** `Sin cambios en esta fase. Frontend: \`API_BASE_URL\` por \`--dart-define\` (por defecto \`http://localhost:3000/api/v1\`).`
- **Texto correcto:** `Sin cambios en esta fase. Frontend: \`API_URL\` por \`--dart-define\` (por defecto \`http://localhost:3000/api/v1\`).`

## 20. `docs/02-architecture/api-contract.md` (D-06 / PA-B1, prioridad baja)

**Ubicación:** §3 "Matriz de permisos", línea 669 (lista de roles).

- **Texto actual:** `- ADMIN: todos.`
- **Texto correcto:** `- ADMIN: todos los registros. En \`GET /ingredients\` y \`GET /preset-pizzas\` ve solo los activos salvo que envíe \`includeInactive=true\` (decisión PA-B1; implementado así).`

**Ubicación:** §3, fila `GET /ingredients`, `/ingredients/:id` (línea 696).

- **Texto actual:** columna ADMIN = `todos`.
- **Texto correcto:** `todos (con includeInactive=true; por defecto solo activos)`.

**Ubicación:** §3, fila `GET /preset-pizzas`, `/preset-pizzas/:id` (línea 698).

- **Texto actual:** columna ADMIN = `todas`.
- **Texto correcto:** `todas (con includeInactive=true; por defecto solo activas)`.

---

## Correcciones que no requieren cambio de texto

- **Informes de QA y seguridad** (`docs/06-qa/`, `docs/07-security/`): son la fuente de verdad de la fase y no se corrigen. Su cifra de 289 (267 + 22) y el estado de ATL son los vigentes.
- **Plantillas `docs/_templates/`**: sin cambios.
- **`README.md` raíz y `frontend/README.md`**: revisados. El `frontend/README.md` ya usa `API_URL` y la compilación está bien documentada.
- **`backend/env.template`**: los valores `change-me` y `change-me-too` se mantienen como ejemplo, pero su corrección (valores vacíos) es parte de C1 / S-01 en el backlog. No es una corrección de texto de documentación.

## Pendiente de decisión (no es una corrección)

- Versión `0.1.0` (backend) frente a `1.0.0+1` (frontend): N-05 del backlog.
- Estructura real frente a la propuesta: se documenta con la nota del punto 16; no se rehace la arquitectura.
- `replaced_by_id` sin clave foránea: N-03 del backlog.
