# Pruebas unitarias — Fase 2: Arquitectura

## Alcance

En arquitectura no hay código ejecutable. Según la skill `phase-deliverables`, las "pruebas" de esta fase son **verificaciones de consistencia del contrato y del diseño**, realizadas por revisión manual cruzada de `architecture.md`, `data-model.md`, `api-contract.md`, `adr/` y los requisitos de la fase 1. No se presentan como pruebas automatizadas ni se inventan salidas de ejecución. Además se especifican los casos que las fases 4 y 5 deben automatizar.

## Casos de prueba (verificaciones de consistencia)

| ID    | Historia/RF         | Descripción                                                                        | Entrada                               | Resultado esperado                                                                                                                                                                   | Resultado real                                                                   | Estado |
| ----- | ------------------- | ---------------------------------------------------------------------------------- | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------- | ------ |
| VC-01 | RF-01..RF-29        | Cada RF tiene endpoint, entidad o regla del motor asignada.                        | Tabla RF de requirements.md           | Ningún RF sin trazar                                                                                                                                                                 | Trazados (ver matriz abajo)                                                      | OK     |
| VC-02 | Prompt §Modelo      | Entidades mínimas del prompt presentes en el esquema Prisma.                       | Lista del prompt                      | Usuarios, roles, tamaños, categorías, tarifas IVA, ingredientes, valores por tamaño, predefinidas e ingredientes, pedidos, pizzas del pedido, ingredientes de la pizza con snapshots | Las 11 presentes (+ refresh_tokens, order_daily_sequences, order_status_history) | OK     |
| VC-03 | RNF-02              | Ningún campo monetario usa Float.                                                  | schema.prisma propuesto               | Solo `Decimal`                                                                                                                                                                       | Precios/totales `Decimal(10,2)`/`(12,2)`, tarifa `Decimal(5,2)`                  | OK     |
| VC-04 | Skill prisma        | Todas las relaciones tienen `onDelete` explícito.                                  | 16 relaciones                         | 16/16 con onDelete                                                                                                                                                                   | 16/16 (Restrict, Cascade o SetNull)                                              | OK     |
| VC-05 | Skill prisma        | Índices en FK y campos de búsqueda.                                                | FKs del esquema                       | Índice o UK que empieza por la FK                                                                                                                                                    | Todas cubiertas (`@@index` o `@@unique` compuesto)                               | OK     |
| VC-06 | S-23                | No existe borrado de ingredientes.                                                 | api-contract §2                       | Sin `DELETE /ingredients/:id`; FK Restrict                                                                                                                                           | Confirmado; ruta → 404 ROUTE_NOT_FOUND                                           | OK     |
| VC-07 | Prompt §Backend     | `/api/v1/health` definido.                                                         | api-contract #1                       | 200 / 503                                                                                                                                                                            | Definido                                                                         | OK     |
| VC-08 | api-design          | Todos los errores usan `{error:{code,message,details}}`.                           | api-contract §1.1-1.2                 | Formato único                                                                                                                                                                        | Único; catálogo de 24 códigos                                                    | OK     |
| VC-09 | ER ↔ API            | Cada campo de respuesta de `OrderDetail` sale de una columna snapshot.             | OrderDetail vs order_*                | Sin dependencias del catálogo vigente                                                                                                                                                | customer, size, preset, componentes, importes, tarifa: todos snapshot            | OK     |
| VC-10 | RF-16, S-19         | La fórmula de IVA es idéntica en architecture, data-model, api-contract y ADR-008. | 4 documentos                          | round_half_up(subtotal15 × 0.15, 2) sobre el pedido                                                                                                                                  | Idéntica                                                                         | OK     |
| VC-11 | US-07               | Ejemplo numérico del contrato reproduce la historia.                               | MEDIUM 2.00 + 1.00 + 1.50×3           | 7.50                                                                                                                                                                                 | 7.50                                                                             | OK     |
| VC-12 | US-10               | Ejemplos de redondeo.                                                              | 0.35, 0.30, 10.00/2.00, 6.50          | 0.05, 0.05, 1.50/13.50, 0.98                                                                                                                                                         | Coinciden (cálculo manual)                                                       | OK     |
| VC-13 | Ejemplo §4 contrato | Totales del ejemplo de referencia.                                                 | masa, salsa, queso×3, jamón, piña, ×2 | sub15 15.40, sub0 3.60, IVA 2.31, total 21.31, 1640 kcal                                                                                                                             | Recalculado a mano: coincide                                                     | OK     |
| VC-14 | RF-03, US-13        | Pedido ajeno no revela existencia.                                                 | GET /orders/:id de otro cliente       | 404                                                                                                                                                                                  | 404 NOT_FOUND documentado                                                        | OK     |
| VC-15 | US-20, US-22        | Matriz de permisos coherente con el detalle de endpoints.                          | §3 vs §2                              | Sin contradicciones                                                                                                                                                                  | Coherente (POST /orders solo CLIENT; admin 403)                                  | OK     |
| VC-16 | RF-18, US-11        | Stock: transacción, sin cambios parciales, concurrencia.                           | ADR-005 + flujo                       | FOR UPDATE + UPDATE condicional + CHECK + rollback                                                                                                                                   | Documentado en los 3 artefactos                                                  | OK     |
| VC-17 | RF-20, S-13, S-24   | Formato y reinicio diario del número de orden.                                     | ADR-004                               | `GP-` + fecha local + 4 dígitos, transaccional                                                                                                                                       | Documentado; UK en order_number                                                  | OK     |
| VC-18 | RF-11, S-17         | Mínimo 3 toppings solo en CUSTOM.                                                  | Motor, contrato, receta admin         | No aplica a PRESET ni a recetas                                                                                                                                                      | Coherente en los tres                                                            | OK     |
| VC-19 | RF-14, S-02         | Receta + extras ≤ 3 por ingrediente.                                               | Motor, `extras` en contrato           | Extras son adicionales; suma ≤ 3                                                                                                                                                     | Coherente                                                                        | OK     |
| VC-20 | RNF-03              | Ningún documento contiene secretos o valores de `.env.local`.                      | docs/02-architecture                  | Solo nombres de variables y marcadores                                                                                                                                               | Sin valores reales (URL de ejemplo con USUARIO/CONTRASENA)                       | OK     |
| VC-21 | Skill flutter       | Estructura feature-first con data/domain/presentation y Riverpod.                  | architecture §3                       | Cumple                                                                                                                                                                               | Cumple                                                                           | OK     |
| VC-22 | Glosario            | Códigos en inglés mapeados a términos en español.                                  | Tamaños, categorías, estados          | Mapeo explícito                                                                                                                                                                      | En contrato §1 y seed                                                            | OK     |

### Matriz de trazabilidad (resumen)

| RF           | Artefacto                                                                      |
| ------------ | ------------------------------------------------------------------------------ |
| RF-01, RF-02 | `POST /auth/register`, `/auth/login`, `users`, ADR-006                         |
| RF-03        | `requireRole`, filtro por dueño, matriz §3                                     |
| RF-04..RF-06 | `/ingredients*`, `ingredients`, `ingredient_size_values`, `vat_rates`          |
| RF-07, RF-08 | `/preset-pizzas*`, `preset_pizzas`, `preset_pizza_ingredients`, `pricesBySize` |
| RF-09..RF-15 | `pricing-engine`, `POST /orders/quote`, violaciones §1.3                       |
| RF-16        | `calculateOrder`, ADR-008, `orders.subtotal_*`/`vat15_amount`                  |
| RF-17        | `items[]` con `quantity` 1..20, `order_pizzas`                                 |
| RF-18        | ADR-005, `stock.service`                                                       |
| RF-19        | ADR-003, columnas `*_snapshot`                                                 |
| RF-20        | ADR-004, `order_daily_sequences`                                               |
| RF-21..RF-23 | `PATCH /orders/:id/status`, `GET /orders`, `order_status_history`              |
| RF-24, RF-25 | `GET /orders/:id` (OrderDetail), logo en `assets/brand/`                       |
| RF-26        | `prisma/seed.js`, variables `SEED_*`                                           |
| RF-27        | `GET /health`                                                                  |
| RF-28        | Rutas go_router §3.4                                                           |
| RF-29        | `active`, filtro para CLIENT                                                   |

## Casos a automatizar en fases siguientes (especificación)

| ID     | Capa          | Caso                                                                           | Esperado                                                                |
| ------ | ------------- | ------------------------------------------------------------------------------ | ----------------------------------------------------------------------- |
| UT-B01 | Motor         | Precio y calorías CUSTOM (US-07)                                               | 7.50; calorías por fórmula                                              |
| UT-B02 | Motor         | IVA mixto 15 %/0 % y half-up (US-10)                                           | 0.0525→0.05; 0.045→0.05; 13.50                                          |
| UT-B03 | Motor         | < 3 toppings en CUSTOM                                                         | `MIN_TOPPINGS_NOT_MET`                                                  |
| UT-B04 | Motor         | Predefinida con 2 toppings, sin extras                                         | válida                                                                  |
| UT-B05 | Motor         | 4 porciones / receta 2 + extra 2                                               | `MAX_PORTIONS_EXCEEDED`                                                 |
| UT-B06 | Motor         | Sin masa o sin salsa; masa como topping                                        | `DOUGH_REQUIRED` / `SAUCE_REQUIRED` / `INGREDIENT_CATEGORY_NOT_ALLOWED` |
| UT-B07 | Motor         | Stock agregado entre líneas (masa compartida × cantidades)                     | `INSUFFICIENT_STOCK` con requested/available                            |
| UT-B08 | Servicio      | Descuento de stock: rollback ante fallo, sin cambios parciales                 | 0 updates confirmados                                                   |
| UT-B09 | Utils         | Formato `GP-20261106-0001`, 9999→10000                                         | Correcto                                                                |
| IT-B01 | API           | 401 sin token; 403 cliente en admin; 404 pedido ajeno                          | Códigos y formato de error                                              |
| IT-B02 | API           | `PATCH status` DELIVERED→PENDING                                               | 422 `INVALID_STATUS_TRANSITION`                                         |
| IT-B03 | BD (si PA-01) | Dos confirmaciones concurrentes por el último stock                            | Una 201, otra 409                                                       |
| WT-F01 | Flutter       | Personalizar triple queso → precio en vivo → agregar → confirmar → comprobante | Flujo completo con repositorio falso                                    |

## Ubicación del código de pruebas

- Backend: `backend/tests/unit/`, `backend/tests/api/`, `backend/tests/helpers/` (fase 4).
- Flutter: `frontend/test/core/`, `frontend/test/features/`, `frontend/test/flows/` (fase 5).

## Ejecución

```
cd backend && npm test
cd frontend && flutter test
```

## Resultados (salida real)

```
No aplica en la fase 2: no existe código. Las verificaciones VC-01..VC-22 se realizaron por
revisión documental; los resultados de ejecución se reportarán en las fases 4 (backend) y 5 (frontend).
```

## Cobertura

| Módulo                                         | %                           |
| ---------------------------------------------- | --------------------------- |
| Requisitos funcionales trazados (RF-01..RF-29) | 100 % (29/29, por revisión) |
| Código                                         | No aplica en esta fase      |
