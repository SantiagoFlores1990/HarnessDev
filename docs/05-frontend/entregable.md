# Entregable — Fase 5: Frontend (Flutter, Windows)

- **Proyecto:** Good Pizza
- **Fecha:** 2026-11-06
- **Agente responsable:** flutter-dev
- **Versión:** 1.0

## 1. Objetivo de la fase

Implementar en `frontend/` la aplicación de escritorio Windows que consume la API `/api/v1` sin desviarse de `api-contract.md`: las 13 pantallas S-01..S-13 del diseño, con Riverpod, go_router (guards por rol), dio (interceptor de autenticación con refresh rotativo), almacenamiento seguro de tokens, tema azul marino Material 3, layouts adaptativos de escritorio, atajos de teclado y pruebas automatizadas.

## 2. Resumen ejecutivo

1. Proyecto Flutter creado con `flutter create --org com.pizzeria --project-name good_pizza --platforms=windows .`; nombre visible "Good Pizza"; ventana inicial 1280 x 800.
2. Estructura feature-first (`auth`, `catalog`, `preset_pizzas`, `pizza_builder`, `cart`, `orders`, `admin`) y `core/{api,config,storage,theme,router,widgets,utils,layout}`.
3. Las 13 pantallas con estados cargando / vacío / error con "Reintentar", mensajes en español mapeados a los 24 códigos de error y a las 15 violaciones de armado.
4. El frontend **no calcula** precios, calorías, IVA ni reglas: pide `POST /orders/quote` (debounce 150 ms, cancelación de la petición anterior) y muestra `violations`; confirma con `expectedTotal` y maneja `409 PRICE_CHANGED`.
5. Interceptor dio: Bearer, un único refresh serializado ante `401 TOKEN_EXPIRED` (token rotativo), reintento y cierre de sesión con aviso si el refresh es rechazado.
6. Comprobante (`ReceiptView`) con el diseño exacto de `screens.md` §S-13, solo en pantalla.
7. 221 pruebas automatizadas en esta fase (WT-01..WT-30 + flujo completo), con 93,2 % de cobertura de líneas. En la fase 6 pasan 225 pruebas de `flutter test` (93,3 %) y 1 de `integration_test` en Windows; `flutter analyze` sin incidencias.
8. **Requisito del entorno:** `flutter build windows --debug` compila con el componente ATL de Visual Studio Build Tools instalado (verificado en la fase 6: `good_pizza.exe`). Sin ATL falla con `atlstr.h`. El arranque del ejecutable contra el backend real queda pendiente (QA G-12).

## 3. Artefactos producidos

| Artefacto                   | Ruta                                        | Descripción                                                                                                                                                     |
| --------------------------- | ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Aplicación Flutter          | `frontend/`                                 | Proyecto Windows (`lib/`, `test/`, `assets/`, `windows/`, `pubspec.yaml`)                                                                                       |
| Logotipo SVG                | `frontend/assets/brand/`                    | `good_pizza_logo.svg` (emblema), `logo-good-pizza-mono.svg`, `logo-good-pizza-horizontal.svg` (solo documentación; el texto "Good Pizza" se compone con `Text`) |
| Guía de ejecución           | `docs/05-frontend/README.md`                | Cómo ejecutar en Windows, `--dart-define`, pruebas, solución de problemas                                                                                       |
| Flujo                       | `docs/05-frontend/flujo.md`                 | Proceso de la fase y flujos funcionales (mermaid)                                                                                                               |
| Modelo de datos del cliente | `docs/05-frontend/diagrama-er.md`           | Modelos de dominio del frontend y su relación con el ER físico del backend                                                                                      |
| Pruebas                     | `docs/05-frontend/pruebas-unitarias.md`     | Casos WT-01..WT-30, salida real, cobertura                                                                                                                      |
| Manual de usuario           | `docs/05-frontend/manual-usuario.md`        | Guía para cliente y administrador                                                                                                                               |
| Documentación técnica       | `docs/05-frontend/documentacion-tecnica.md` | Arquitectura, estado, API, decisiones                                                                                                                           |

## 4. Decisiones y supuestos

Decisiones del usuario aplicadas: solo Windows de escritorio, español, Material 3 claro, USD con 2 decimales y separador punto centralizado en `money_format.dart`; sesión iniciada automáticamente tras registrarse; estado de pedidos del cliente con refresco manual (botón y F5); el carrito fusiona predefinidas iguales sin extras sumando cantidad hasta 20 y no fusiona las personalizadas; pie del comprobante "Documento informativo del pedido. No es una factura electrónica."; fecha del comprobante = `createdAt` en hora local; fuente Segoe UI del sistema; tamaño mínimo 1024 x 680 solo recomendado (sin `window_manager`); vista previa de precios de predefinidas con `POST /orders/quote` y 3 ítems CUSTOM.

Decisiones propias (no estaban fijadas en los documentos):

| #    | Decisión                                                                                                                                                                              | Motivo                                                                                                                                                    |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| D-F1 | Las listas de administración (ingredientes y predefinidas) arrancan con "Mostrar inactivos" **activado** y envían `includeInactive=true`                                              | El backend devuelve solo activos por defecto; sin esto el admin no vería ni podría reactivar los inactivos. El mockup S-07 mostraba la casilla sin marcar |
| D-F2 | Código de predefinida: `^[A-Z0-9_]{2,30}$` (se convierte a mayúsculas)                                                                                                                | El diseño dice "mayúsculas/guion bajo"; se permiten dígitos                                                                                               |
| D-F3 | `TOKEN_EXPIRED` tiene mensaje de respaldo "Tu sesión expiró…" aunque el diseño dice "sin mensaje"                                                                                     | Defensivo: normalmente lo absorbe el interceptor                                                                                                          |
| D-F4 | Repositorios por feature con interfaz abstracta + implementación `dio`; `catalog` aloja también las operaciones admin de ingredientes y `admin/presentation` solo las pantallas admin | Evita repositorios duplicados; permite fakes en pruebas                                                                                                   |
| D-F5 | Sin `FocusRing` propio: el foco visible usa el tema Material (`focusedBorder`, `focusColor`) y `focusRingOnDark` en el rail                                                           | Cubre el requisito con menos código; ver pendientes                                                                                                       |
| D-F6 | Los providers no reintentan automáticamente (`retry: null`); los errores se muestran con "Reintentar"                                                                                 | Riverpod 3 reintenta por defecto, lo que ocultaría los errores                                                                                            |
| D-F7 | Con `go_router`, las rutas hijas (`/orders/:id`, `/admin/*/new`, `/:id`) se apilan sobre su lista: tras guardar se invalidan las listas                                               | Mantiene el botón/atajo "volver" y el estado de la lista                                                                                                  |

## 5. Riesgos y pendientes

| Tipo                            | Descripción                                                                                                                                                                                           | Acción                                                                                                                                                                              |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Bloqueante de entorno**       | `flutter build windows --debug` falla: `error C1083: No se puede abrir el archivo incluir: 'atlstr.h'` (plugin `flutter_secure_storage_windows`). Build Tools 2022 17.14 sin el componente ATL        | Instalar "C++ ATL para las últimas herramientas de compilación v143 (x86 y x64)" desde Visual Studio Installer y repetir `flutter build windows --debug` / `flutter run -d windows` |
| No verificado                   | Arranque real de la app y prueba de humo con el backend real (backend apagado; no se puede saber si las tablas tienen datos sin credenciales)                                                         | Tras instalar ATL: `cd backend && npm run dev`, luego `flutter run -d windows` e iniciar sesión con las cuentas del seed                                                            |
| No verificado                   | `flutter_secure_storage` real y fuente Segoe UI (las pruebas usan memoria y Ahem)                                                                                                                     | Verificar en la primera ejecución manual                                                                                                                                            |
| Pendiente (opcional del diseño) | `F6` (saltar entre regiones), botón ☰ para alternar el rail en compacto, menú contextual de filas, `Esc` para quitar el foco del buscador, ordenación por teclado con flechas entre tarjetas de S-03 | No bloquean ningún criterio; no implementados                                                                                                                                       |
| Pendiente                       | Revisión en pantalla real a 125–200 % de escala de texto de Windows                                                                                                                                   | QA (fase 6)                                                                                                                                                                         |
| Riesgo                          | La actualización del estado del pedido del cliente es manual (decisión de diseño)                                                                                                                     | Documentado en el manual                                                                                                                                                            |

### Preguntas abiertas

| ID    | Pregunta                                                                                                      | Comportamiento aplicado                                                                    |
| ----- | ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| PA-F1 | ¿Las listas admin deben abrir con inactivos visibles? (ver D-F1)                                              | Sí, interruptor activado por defecto                                                       |
| PA-F2 | `OrderDetail.pizzas[].presetPizza.id/code` pueden ser `null` si la predefinida desaparece (PA-B2 del backend) | El frontend usa solo `name` (snapshot); tolera `id`/`code` ausentes                        |
| PA-F3 | ¿Se desea el botón ☰ y `F6` del diseño en esta versión?                                                      | No incluidos                                                                               |
| PA-F4 | El mensaje al agotarse el stock de una masa/salsa de la receta de una predefinida (modo personalizar)         | Las masas/salsas no elegidas quedan deshabilitadas; el servidor valida el stock al cotizar |

## 6. Criterios de aceptación de la fase

- [x] Flujo documentado (`flujo.md`)
- [x] Diagrama entidad-relación actualizado (`diagrama-er.md`: modelos del cliente; ER físico del backend sin cambios)
- [x] Pruebas unitarias ejecutadas (resultados reales adjuntos en `pruebas-unitarias.md`: 221 pruebas OK en esta fase; 225 en la fase 6; `flutter analyze` sin incidencias)
- [x] Manual de usuario actualizado
- [x] Documentación técnica actualizada
- [x] `flutter build windows --debug` (compila tras instalar ATL; verificado en la fase 6)
- [ ] `flutter run -d windows` contra el backend real con datos del seed (pendiente; QA G-12)

## 7. Aprobación

| Rol                                  | Nombre                 | Fecha      |
| ------------------------------------ | ---------------------- | ---------- |
| Responsable de la fase (flutter-dev) | Agente flutter-dev     | 2026-11-06 |
| Revisión                             | Pendiente (QA, fase 6) |            |
