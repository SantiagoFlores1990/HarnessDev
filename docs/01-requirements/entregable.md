# Entregable — Fase 1: Requisitos

- **Proyecto:** Good Pizza
- **Fecha:** 2026-11-06
- **Agente responsable:** requirements
- **Versión:** 1.1 (incorpora las decisiones del usuario sobre las preguntas abiertas)

## 1. Objetivo de la fase

Convertir la especificación de `docs/prompt-proyecto.md` en requisitos verificables, historias de usuario con criterios Given/When/Then y un glosario del dominio.

## 2. Resumen ejecutivo (máx. 10 líneas)

- 29 requisitos funcionales y 10 no funcionales, priorizados con MoSCoW.
- 2 roles (Administrador, Cliente) más el sistema como actor.
- 23 historias de usuario (US-01 a US-23) con criterios Given/When/Then.
- Reglas clave: 1 masa + 1 salsa, mínimo 3 ingredientes distintos solo en personalizadas, máximo 3 porciones, stock, IVA 15 %/0 % por ingrediente sobre cada subtotal con redondeo half-up, snapshots, estados de 3 pasos.
- Decisiones del usuario ya firmes (S-17 a S-26): predefinidas con precio por fórmula, sin cancelación ni devolución de stock, contraseña de 8+ caracteres, comprobante solo en pantalla, ingredientes solo se desactivan, zona horaria del servidor, máximo 20 pizzas por línea.
- No quedan preguntas abiertas.

## 3. Artefactos producidos

| Artefacto           | Ruta                                            | Descripción                                            |
| ------------------- | ----------------------------------------------- | ------------------------------------------------------ |
| Requisitos          | `docs/01-requirements/requirements.md`          | Alcance, actores, RF, RNF, supuestos, fuera de alcance |
| Historias           | `docs/01-requirements/user-stories.md`          | US-01…US-23 con Given/When/Then                        |
| Glosario            | `docs/01-requirements/glossary.md`              | Términos del dominio                                   |
| Flujo               | `docs/01-requirements/flujo.md`                 | Proceso de fase y flujo funcional                      |
| ER conceptual       | `docs/01-requirements/diagrama-er.md`           | Entidades del dominio                                  |
| Casos de aceptación | `docs/01-requirements/pruebas-unitarias.md`     | Casos Given/When/Then                                  |
| Manual              | `docs/01-requirements/manual-usuario.md`        | Qué podrá hacer el usuario                             |
| Doc. técnica        | `docs/01-requirements/documentacion-tecnica.md` | Restricciones técnicas de partida                      |

## 4. Decisiones y supuestos

Ver sección 5 de `requirements.md` (S-01 a S-26). S-17 a S-26 son decisiones confirmadas por el usuario.

## 5. Riesgos y pendientes

- Sin preguntas abiertas.
- Riesgo de sobreventa en concurrencia: mitigar con transacción y bloqueo/actualización condicional en backend.
- Sin devolución de stock: el stock descontado no se recupera nunca (decisión aceptada, S-20).

## 6. Criterios de aceptación de la fase

- [x] Flujo documentado
- [x] Diagrama entidad-relación actualizado (conceptual)
- [x] Pruebas unitarias ejecutadas (resultados reales adjuntos): N/A en esta fase; casos de aceptación definidos, sin ejecución
- [x] Manual de usuario actualizado
- [x] Documentación técnica actualizada

## 7. Aprobación

| Rol                   | Nombre | Fecha |
| --------------------- | ------ | ----- |
| Pendiente de revisión | —      | —     |
