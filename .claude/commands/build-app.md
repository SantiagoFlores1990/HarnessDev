---
description: Genera una aplicación full stack (Node + Flutter) recorriendo todo el SDLC con los agentes.
argument-hint: <descripción de la aplicación>
---
Construye la siguiente aplicación: **$ARGUMENTS**

Orquesta los subagentes en este orden, esperando a que cada uno termine y verificando que su carpeta `docs/NN-*` tenga salida antes de continuar:

1. `requirements-analyst`
2. `solution-architect`
3. `ux-designer`
4. `backend-dev`
5. `flutter-dev`
6. `qa-engineer`
7. `security-reviewer` (si el veredicto es NO-GO, vuelve a `backend-dev` o `flutter-dev` para corregir y repite QA y seguridad, máx. 2 iteraciones)
8. `devops-engineer`
9. `maintenance-docs`

A cada agente pásale la descripción original y recuérdale leer los `docs/` previos. Al final entrega un resumen: qué se construyó, cómo ejecutarlo (backend y Flutter en desktop y móvil) y riesgos pendientes.
