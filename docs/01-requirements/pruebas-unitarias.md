# Pruebas — Fase 1 (casos de aceptación)

## Alcance

En esta fase no hay código. Se definen casos de aceptación Given/When/Then que backend, frontend y QA convertirán en pruebas automáticas. Resultado real: no ejecutados (pendiente de implementación).

## Casos de prueba

| ID    | Historia/RF   | Descripción                                                            | Entrada                                           | Resultado esperado                                                   | Resultado real | Estado    |
| ----- | ------------- | ---------------------------------------------------------------------- | ------------------------------------------------- | -------------------------------------------------------------------- | -------------- | --------- |
| UT-01 | US-04 / RF-11 | Personalizada con 2 ingredientes distintos                             | masa, salsa, queso, jamón                         | Error "mínimo 3 ingredientes distintos"                              | No ejecutado   | Pendiente |
| UT-02 | US-05 / RF-10 | Queso ×3, sube a 4                                                     | cantidad 4                                        | Error máximo 3 porciones                                             | No ejecutado   | Pendiente |
| UT-03 | US-06 / RF-12 | Stock 2, pide 3                                                        | cantidad 3                                        | Error con stock disponible 2                                         | No ejecutado   | Pendiente |
| UT-04 | US-07 / RF-15 | Mediana: masa 2,00, salsa 1,00, queso 1,50 ×3                          | —                                                 | Precio 7,50                                                          | No ejecutado   | Pendiente |
| UT-05 | US-07 / RF-15 | Calorías con la misma fórmula por tamaño                               | —                                                 | Suma de calorías del tamaño elegido                                  | No ejecutado   | Pendiente |
| UT-06 | US-10 / RF-16 | Subtotal 15 % = 10,00 y 0 % = 2,00                                     | —                                                 | IVA 1,50; Total 13,50                                                | No ejecutado   | Pendiente |
| UT-07 | US-08 / RF-14 | Predefinida: quitar ingrediente de receta                              | quitar                                            | No permitido                                                         | No ejecutado   | Pendiente |
| UT-08 | US-08 / RF-14 | Receta con 2 porciones + 2 adicionales                                 | total 4                                           | Rechazado (máx. 3)                                                   | No ejecutado   | Pendiente |
| UT-09 | US-11 / RF-18 | Confirmar con stock suficiente                                         | pedido válido                                     | Stock descontado: 1 por porción, masa y salsa 1 por pizza × cantidad | No ejecutado   | Pendiente |
| UT-10 | US-11 / RF-18 | Stock insuficiente en un ingrediente                                   | pedido                                            | Rechazo claro; stock sin cambios (rollback)                          | No ejecutado   | Pendiente |
| UT-11 | US-11 / RF-20 | Número de orden                                                        | primer pedido del día (zona horaria del servidor) | `GP-AAAAMMDD-0001`; siguiente `-0002`                                | No ejecutado   | Pendiente |
| UT-12 | US-14 / RF-19 | Admin cambia precio tras la compra                                     | nuevo precio                                      | Pedido antiguo conserva valores                                      | No ejecutado   | Pendiente |
| UT-13 | US-13 / RF-03 | Cliente B pide pedido de cliente A                                     | GET pedido ajeno                                  | 403/404                                                              | No ejecutado   | Pendiente |
| UT-14 | US-20 / RF-21 | Admin avanza Pendiente → En preparación → Entregado                    | PATCH estado                                      | Cambios válidos; retroceso/salto rechazado                           | No ejecutado   | Pendiente |
| UT-15 | US-22 / RF-03 | Cliente llama endpoint admin                                           | token cliente                                     | 403; sin token 401                                                   | No ejecutado   | Pendiente |
| UT-16 | US-18 / RF-04 | IVA distinto de 15/0                                                   | 12 %                                              | Rechazado                                                            | No ejecutado   | Pendiente |
| UT-17 | US-21 / RF-26 | Seed sin variables de contraseña                                       | ejecutar seed                                     | Contraseñas aleatorias impresas una vez                              | No ejecutado   | Pendiente |
| UT-18 | US-01 / RF-01 | Registro con email duplicado                                           | email existente                                   | Error, sin cuenta nueva                                              | No ejecutado   | Pendiente |
| UT-19 | US-01 / RF-01 | Contraseña de 7 caracteres; de 8 caracteres                            | 7 / 8 caracteres                                  | 7 rechazada; 8 aceptada                                              | No ejecutado   | Pendiente |
| UT-20 | US-08 / RF-14 | Predefinida con menos de 3 ingredientes (Margarita), sin y con adición | receta tal cual; receta + 1 ingrediente           | Aceptada en ambos casos sin exigir el mínimo                         | No ejecutado   | Pendiente |
| UT-21 | US-03 / RF-08 | Precio de predefinida                                                  | tamaño Familiar                                   | Igual a la fórmula masa + salsa + ingredientes; sin precio fijo      | No ejecutado   | Pendiente |
| UT-22 | US-10 / RF-16 | Redondeo half-up del IVA sobre subtotal                                | subtotal 15 % = 0,30                              | IVA 0,05 (0,045 sube)                                                | No ejecutado   | Pendiente |
| UT-23 | US-10 / RF-16 | IVA sobre el subtotal, no por línea                                    | dos líneas de 0,35 y 0,35 (subtotal 0,70)         | IVA = round(0,105) = 0,11                                            | No ejecutado   | Pendiente |
| UT-24 | US-13 / RF-21 | Cliente intenta cancelar pedido Pendiente                              | cancelar                                          | Opción inexistente; API rechaza; stock sin cambios                   | No ejecutado   | Pendiente |
| UT-25 | US-12 / RF-24 | Comprobante en pantalla                                                | abrir orden                                       | Muestra todos los campos; sin exportar/imprimir                      | No ejecutado   | Pendiente |
| UT-26 | US-15 / RF-04 | Retirar un ingrediente                                                 | eliminar                                          | Solo se desactiva; no se ofrece al cliente; histórico intacto        | No ejecutado   | Pendiente |
| UT-27 | US-03 / RF-08 | Predefinida con ingrediente inactivo o sin stock                       | ingrediente inactivo                              | Predefinida marcada no disponible y no pedible                       | No ejecutado   | Pendiente |
| UT-28 | US-09 / RF-17 | Cantidad de pizzas en una línea                                        | 20 / 21 / 0                                       | 20 aceptada; 21 y 0 rechazadas                                       | No ejecutado   | Pendiente |

## Ubicación del código de pruebas

- Backend: `backend/tests/…` (Vitest + Supertest)
- Flutter: `frontend/test/…`

## Ejecución

```
cd backend && npm test
cd frontend && flutter test
```

## Resultados (salida real)

No aplica en esta fase: no existe código ejecutable.

## Cobertura

| Módulo | %   |
| ------ | --- |
| —      | N/A |
