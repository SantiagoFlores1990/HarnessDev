# Entregable — Fase 7: Seguridad

- **Proyecto:** Good Pizza
- **Fecha:** 2026-11-06
- **Agente responsable:** security-reviewer
- **Versión:** 1.0

## 1. Objetivo de la fase

Revisar la seguridad del monolito Good Pizza antes de usarlo en el local: la API Node/Express/Prisma, la app Flutter para Windows, la configuración, las dependencias y el entorno de Claude Code. El resultado son hallazgos accionables y un veredicto GO/NO-GO con criterio explícito. La fase no modifica código de `backend/` ni de `frontend/`.

## 2. Resumen ejecutivo

1. **Veredicto: GO CONDICIONADO.** Pasa a NO-GO si no se confirma C1: secretos JWT robustos en `backend/.env.local`.
2. Críticas: 0. Altas: 1 en la app (S-01: fuera de `production` se aceptan secretos JWT por defecto, lo que permite forjar tokens ADMIN) y 1 en el entorno de desarrollo (H-01: los permisos de Claude Code dejan ejecutar `prisma migrate reset` y similares sin preguntar).
3. Medias en la app: límites de peticiones compartidos en un solo PC (S-02), sesión persistente en un equipo compartido (S-03), API en todas las interfaces y por HTTP (S-04), amplificación en errores de validación (S-05, medida: 72 KB generan 3,6 MB) y agotamiento de stock con pedidos falsos (S-06).
4. Bien resueltos: bcrypt con coste 12, JWT con algoritmo fijado, refresh rotativo con hash y detección de reutilización, autorización por rol y por dueño (25 de 25 rutas coinciden con el contrato), Zod strict en toda entrada, SQL parametrizado, stock sin sobreventa, helmet, CORS con lista blanca, errores sin stack, logs con redacción y ningún secreto en el repositorio.
5. `npm audit --omit=dev`: 4 altas. El impacto real es bajo o medio: Zod se alcanza desde HTTP solo con autenticación; `deepmerge-ts` no se alcanza. Las críticas de `npm audit` completo son solo de pruebas (`tinypool`, `vitest`).
6. `flutter pub outdated`: dependencias directas al día.
7. Pruebas de seguridad existentes: 134 en backend y 19 en Flutter, todas pasan en esta fase.

## 3. Artefactos producidos

| Artefacto             | Ruta                                        | Descripción                                                                                                                         |
| --------------------- | ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Informe de seguridad  | `docs/07-security/security-report.md`       | Hallazgos con severidad, archivo:línea, impacto, escenario, corrección y responsable; salidas reales de las herramientas; veredicto |
| Entregable            | `docs/07-security/entregable.md`            | Este documento                                                                                                                      |
| Flujo                 | `docs/07-security/flujo.md`                 | Proceso de la revisión, flujo de autenticación y autorización, y modelo de amenazas (STRIDE)                                        |
| Diagrama ER           | `docs/07-security/diagrama-er.md`           | ER físico con anotaciones de seguridad (datos sensibles, CHECK, `onDelete`)                                                         |
| Pruebas               | `docs/07-security/pruebas-unitarias.md`     | Casos de abuso cubiertos (con ejecución real) y casos que faltan                                                                    |
| Manual                | `docs/07-security/manual-usuario.md`        | Buenas prácticas para clientes, administrador y quien instala                                                                       |
| Documentación técnica | `docs/07-security/documentacion-tecnica.md` | Controles de seguridad por capa, configuración y endurecimiento recomendado                                                         |

## 4. Decisiones y supuestos

- El despliegue de referencia es el de `docs/02-architecture/architecture.md` §1: app y API **en el mismo PC del local**. Las severidades de S-02, S-03 y S-04 dependen de ese supuesto (ver Preguntas abiertas en el informe).
- Los hallazgos del entorno de Claude Code (H-xx) se informan aparte y **no** cuentan para el criterio GO/NO-GO de la aplicación, porque no se despliegan. H-01 sí pone en riesgo los datos reales mientras se usen agentes.
- Para no cargar `.env.local`, las pruebas se ejecutaron con `npx vitest` (valores fijos de `vitest.config.js`) y no con `npm test`.
- La medición de Zod (S-05) se hizo en proceso, importando solo el esquema real: sin BD, sin red, sin `.env.local`.

## 5. Riesgos y pendientes

- C1 sin verificar (no se puede leer `.env.local`).
- La concurrencia real con PostgreSQL sigue sin probarse (D-05 de QA): es una dependencia de integridad, no un defecto encontrado.
- La aplicación de las correcciones queda en manos de backend-dev y flutter-dev. Los ajustes de hooks y permisos quedan en manos del usuario.
- Decisiones de negocio pendientes: cancelación y tope de pedidos (S-06), modelo de PC compartido (S-03), exposición en red (S-04).

## 6. Criterios de aceptación de la fase

- [x] Flujo documentado (autenticación, autorización y amenazas)
- [x] Diagrama entidad-relación actualizado con anotaciones de seguridad (sin cambios de esquema respecto a la fase 4)
- [x] Pruebas ejecutadas con resultados reales adjuntos (134 backend + 19 Flutter de seguridad; `npm audit`; `flutter pub outdated`)
- [x] Manual de usuario actualizado (buenas prácticas de seguridad)
- [x] Documentación técnica actualizada (controles y endurecimiento)
- [x] Veredicto GO/NO-GO con criterio explícito

## 7. Aprobación

| Rol                      | Nombre                     | Fecha      |
| ------------------------ | -------------------------- | ---------- |
| Revisor de seguridad     | security-reviewer (agente) | 2026-11-06 |
| Responsable del producto | (pendiente: usuario)       |            |
