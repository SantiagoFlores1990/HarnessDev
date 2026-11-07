# Entregable — Fase 3: Diseño UX/UI

- **Proyecto:** Good Pizza — sistema de venta de pizzas con ingredientes personalizados
- **Fecha:** 2026-11-06
- **Agente responsable:** ux-designer
- **Versión:** 1.0

## 1. Objetivo de la fase

Diseñar la experiencia y la interfaz de la app de escritorio Windows (Flutter, Material 3, español, USD): flujos, pantallas con estados, sistema de diseño con paleta azul marino y contraste AA verificado, logotipo SVG, comportamiento de ventana/teclado/ratón y accesibilidad, a partir de los requisitos (fase 1) y el contrato de API y la arquitectura (fase 2).

## 2. Resumen ejecutivo

- 13 pantallas (S-01..S-13): cliente (login, registro, predefinidas, personalizar, resumen del pedido, mis pedidos, detalle/comprobante) y admin (ingredientes, predefinidas, pedidos, con formularios y detalle).
- Armado con **checkboxes**, cantidad 1..3 por ingrediente y stock visible; precio y calorías en vivo con `POST /orders/quote` (`valid`/`violations` mapeados a mensajes en español).
- Comprobante solo en pantalla con el diseño exacto del prompt: logo, número, fecha, cliente, por pizza tamaño/masa/salsa/ingredientes, resumen (Calorías totales, Subtotal 15 %, Subtotal 0 %, IVA 15 %, TOTAL) y estado.
- Paleta de azul marino completa (modo claro) con 45 pares de contraste calculados (mínimo texto 4,94:1); `ThemeData` M3 y `ThemeExtension` para éxito/advertencia en código Dart.
- Logotipo SVG creado (color, monocromo y horizontal para documentación).
- Escritorio Windows solamente: ventana mínima 1024 × 680, rail compacto/extendido, atajos de teclado, foco visible; móvil explícitamente fuera de alcance.
- Los 24 códigos de error del contrato tienen mensaje y presentación definidos.
- 9 preguntas abiertas no bloqueantes (PA-UX-01..09) con supuesto aplicado.

## 3. Artefactos producidos

| Artefacto             | Ruta                                                   | Descripción                                                                                                                                          |
| --------------------- | ------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| Flujos de usuario     | `docs/03-design/user-flows.md`                         | Mermaid: navegación y redirecciones, acceso, cliente a comprobante, armado en vivo, admin (ingredientes, predefinidas, pedidos), máquina de estados. |
| Pantallas             | `docs/03-design/screens.md`                            | S-01..S-13 con maqueta, componentes, estados (cargando/vacío/error), textos, comprobante exacto, mapeo de errores del contrato.                      |
| Sistema de diseño     | `docs/03-design/design-system.md`                      | Logotipo, paleta con hex y contraste, tipografía, espaciado, `ThemeData` M3 en Dart, componentes.                                                    |
| Escritorio / ventana  | `docs/03-design/responsive.md`                         | Alcance Windows, ventana, rangos de ancho, NavigationRail, atajos, ratón, foco.                                                                      |
| Accesibilidad         | `docs/03-design/accesibilidad.md`                      | Contraste, tamaños de objetivo, semantics, teclado, lista de verificación.                                                                           |
| Logotipo              | `docs/03-design/assets/logo-good-pizza.svg`            | Emblema a color (usable con `flutter_svg`).                                                                                                          |
| Logotipo monocromo    | `docs/03-design/assets/logo-good-pizza-mono.svg`       | Variante de una tinta.                                                                                                                               |
| Logotipo horizontal   | `docs/03-design/assets/logo-good-pizza-horizontal.svg` | Emblema + palabra; solo documentación (usa `<text>`).                                                                                                |
| Entregable            | `docs/03-design/entregable.md`                         | Este documento.                                                                                                                                      |
| Flujo                 | `docs/03-design/flujo.md`                              | Proceso de la fase y secuencia de cálculo en vivo y confirmación.                                                                                    |
| Diagrama ER           | `docs/03-design/diagrama-er.md`                        | ER de la fase 2 (sin cambios), trazabilidad pantalla-entidad y estado de interfaz.                                                                   |
| Pruebas               | `docs/03-design/pruebas-unitarias.md`                  | 38 verificaciones de consistencia y 30 casos de widget para `flutter-dev`.                                                                           |
| Manual de usuario     | `docs/03-design/manual-usuario.md`                     | Guía por rol según el diseño.                                                                                                                        |
| Documentación técnica | `docs/03-design/documentacion-tecnica.md`              | Guía de implementación para `flutter-dev`.                                                                                                           |

## 4. Decisiones y supuestos

Decisiones del usuario aplicadas: app solo Windows con NavigationRail; Material 3, español, USD 2 decimales; paleta azul marino definida por diseño, modo claro; logotipo SVG creado por diseño; checkboxes (sin render visual) con cantidad 1..3; stock visible al cliente; comprobante solo en pantalla.

Decisiones de diseño:

- D-UX-01 Modo claro únicamente; el modo oscuro queda fuera de alcance (RNF-05).
- D-UX-02 Fuente Segoe UI del sistema (sin empaquetar fuentes).
- D-UX-03 Masa y salsa como casillas de selección exclusiva (marcar otra desmarca la anterior) con semántica de grupo exclusivo.
- D-UX-04 Rail extendido (≥ 1280 px) o compacto (1024–1279 px); resumen lateral o barra inferior según ancho.
- D-UX-05 La palabra "Good Pizza" del logotipo se compone con `Text` en Flutter (`flutter_svg` no renderiza `<text>`).
- D-UX-06 Vista previa de precio en el admin de predefinidas con `POST /orders/quote` (ítems CUSTOM por tamaño, ignorando `MIN_TOPPINGS_NOT_MET`), sin cambiar el contrato.
- D-UX-07 Tras registrarse la sesión queda iniciada (el contrato devuelve tokens).
- D-UX-08 Solo el último estado y el historial se muestran en el comprobante; sin acciones de impresión.
- D-UX-09 Estados con color + icono + texto; foco visible con anillo de 2 px.

Supuestos heredados: S-01..S-26 sin cambios. Convenciones: precios sin IVA en armado y predefinidas; IVA y total solo en el resumen y el comprobante.

## 5. Riesgos y pendientes

| ID      | Riesgo                                                           | Mitigación                                                                 |
| ------- | ---------------------------------------------------------------- | -------------------------------------------------------------------------- |
| R-UX-01 | Ratios de contraste calculados a mano.                           | Prueba WT-01 automática en frontend; paleta con margen sobre los umbrales. |
| R-UX-02 | Tamaño mínimo de ventana requiere cambio nativo o paquete extra. | PA-UX-02; el diseño tolera scroll por debajo del mínimo.                   |
| R-UX-03 | La cotización en vivo depende de la latencia de la API (RNF-01). | Estado local inmediato, debounce 150 ms, último valor visible.             |
| R-UX-04 | Si el catálogo es grande, la lista del armado crece.             | Agrupación por categoría y scroll; ~20 ingredientes previstos.             |

### Preguntas abiertas

| ID       | Pregunta                                                                                                                                                        | Supuesto aplicado                                                                  |
| -------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| PA-UX-01 | Separador decimal: la arquitectura usa `"$ 7.50"` y los requisitos escriben `7,50`. ¿Punto o coma?                                                              | Punto (`$ 7.50`), centralizado en `money_format.dart` para cambiarlo.              |
| PA-UX-02 | ¿Se puede fijar un tamaño mínimo de ventana (1024 × 680)? Requiere modificar el runner de Windows o añadir `window_manager`, no previsto en las dependencias.   | Se documenta como recomendado; hasta aprobar, comportamiento degradado con scroll. |
| PA-UX-03 | ¿Es válida la fuente Segoe UI del sistema (sin empaquetar)?                                                                                                     | Sí.                                                                                |
| PA-UX-04 | ¿Iniciar sesión automáticamente tras el registro?                                                                                                               | Sí (el contrato devuelve tokens).                                                  |
| PA-UX-05 | La vista previa de precios en S-10 usa `quote` con ítems CUSTOM. ¿Se prefiere un endpoint específico?                                                           | Se usa `quote`; sin cambio de contrato.                                            |
| PA-UX-06 | La fecha del comprobante se muestra desde `createdAt` en hora local del equipo; el número usa la fecha del servidor (S-24). ¿Aceptable si ambas zonas difieren? | Sí; cliente y servidor están en el mismo local.                                    |
| PA-UX-07 | ¿El cliente necesita actualización automática del estado (sondeo) o basta con refrescar?                                                                        | Solo manual (botón Actualizar, `F5`) y al abrir el detalle.                        |
| PA-UX-08 | Líneas iguales en el carrito (misma predefinida, tamaño y sin extras): ¿se fusionan sumando cantidad?                                                           | Sí hasta 20; las personalizadas no se fusionan.                                    |
| PA-UX-09 | ¿Se acepta el pie "Documento informativo del pedido. No es una factura electrónica." en el comprobante?                                                         | Sí (la factura electrónica está fuera de alcance).                                 |

## 6. Criterios de aceptación de la fase

- [x] Flujo documentado (`flujo.md`, `user-flows.md`)
- [x] Diagrama entidad-relación actualizado (sin cambios; trazabilidad y estado de UI)
- [x] Pruebas unitarias ejecutadas (resultados reales adjuntos): en esta fase son verificaciones de consistencia por revisión y cálculo manual; no hay código ejecutable. Se declara en `pruebas-unitarias.md` sin inventar salidas
- [x] Manual de usuario actualizado
- [x] Documentación técnica actualizada
- [x] Pantallas con estados cargando, vacío y error y mensajes que mapean los códigos del contrato
- [x] Paleta azul marino con contraste AA, logotipo SVG y `ThemeData` M3
- [x] Móvil declarado fuera de alcance

## 7. Aprobación

| Rol                      | Nombre      | Fecha      |
| ------------------------ | ----------- | ---------- |
| Diseñador UX/UI (agente) | ux-designer | 2026-11-06 |
| Product owner            | (pendiente) |            |
