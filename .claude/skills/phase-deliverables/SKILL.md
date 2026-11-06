---
name: phase-deliverables
description: Paquete obligatorio de entregables por fase del SDLC (entregable, flujo, diagrama entidad-relación, pruebas unitarias, manual de usuario y documentación técnica) con plantillas en docs/_templates.
---
# Entregables por fase

Cada agente, al terminar su fase, crea en `docs/NN-<fase>/` estos 6 archivos a partir de `docs/_templates/`:

| Archivo | Plantilla |
|---|---|
| `entregable.md` | `entregable.md` |
| `flujo.md` | `flujo.md` (Mermaid) |
| `diagrama-er.md` | `diagrama-er.md` (Mermaid `erDiagram`) |
| `pruebas-unitarias.md` | `pruebas-unitarias.md` |
| `manual-usuario.md` | `manual-usuario.md` |
| `documentacion-tecnica.md` | `documentacion-tecnica.md` |

## Alcance según la fase
- **Requisitos:** ER conceptual (entidades del dominio); "pruebas" = casos de aceptación Given/When/Then; manual = descripción de lo que el usuario podrá hacer.
- **Arquitectura / Diseño:** ER lógico completo; pruebas = verificaciones de consistencia del contrato y del diseño; flujos de pantalla.
- **Backend / Frontend:** ER físico real (igual al esquema Prisma); pruebas unitarias reales ejecutadas con salida pegada; manual y doc técnica reflejan el código existente.
- **QA / Seguridad / DevOps / Mantenimiento:** consolidan y verifican; actualizan los archivos previos en lugar de duplicarlos.

## Reglas
- Español en la documentación; Mermaid para todos los diagramas.
- El ER debe coincidir con `backend/prisma/schema.prisma` desde la fase de backend.
- Nunca inventar resultados de pruebas: ejecutar y pegar salida real; si algo no corre, indicarlo.
- Nunca incluir secretos ni valores de `.env.local`.
- Si una fase no cambia un artefacto, referenciar el de la fase anterior y registrar "sin cambios".
