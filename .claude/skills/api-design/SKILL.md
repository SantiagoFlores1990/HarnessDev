---
name: api-design
description: Reglas de diseño de API REST (recursos, verbos, códigos HTTP, paginación, versionado, errores) para el contrato entre Node y Flutter.
---
# Diseño de API

- Prefijo `/api/v1`; recursos en plural y kebab-case (`/orders`, `/order-items`).
- Verbos: GET leer, POST crear (201), PUT/PATCH actualizar, DELETE borrar (204).
- Errores uniformes: `{ "error": { "code": "VALIDATION_ERROR", "message": "...", "details": [] } }`.
- Códigos: 400 validación, 401 sin auth, 403 sin permiso, 404, 409 conflicto, 422 regla de negocio, 500.
- Paginación: `?page=1&pageSize=20` → `{ data, page, pageSize, total }`.
- Fechas ISO-8601 UTC; dinero como string decimal o entero en centavos (decidir y documentar).
- El contrato (`docs/02-architecture/api-contract.md`) es la fuente de verdad; backend y Flutter no se desvían de él.
