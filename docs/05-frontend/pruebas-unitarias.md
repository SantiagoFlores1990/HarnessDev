# Pruebas unitarias — Fase 5 (Frontend Flutter)

## Alcance

Pruebas automatizadas con `flutter_test` del frontend Windows: unitarias (formato de dinero, contraste, `ApiException`, interceptor de autenticación, controladores y modelos), de widget (las 13 pantallas S-01..S-13, el `AppShell` y los widgets compartidos) y de flujo completo ("personalizar pizza hasta generar la orden"). Se ejecutan **sin backend ni base de datos**: repositorios falsos (`test/helpers/fakes.dart`), `ProviderScope` con overrides y un adaptador HTTP falso para `dio`. Los casos WT-01..WT-30 de `docs/03-design/pruebas-unitarias.md` están automatizados.

Aclaraciones honestas:

- El "motor" que usan los repositorios falsos (`FakeServer.quoteJson`) es un **doble de prueba** del servidor para devolver cotizaciones coherentes; no es código de la aplicación (la app nunca calcula precios, IVA ni reglas).
- Los tests de widget corren con la fuente de prueba Ahem (cada glifo es un cuadrado, más ancha que Segoe UI) y escala de texto 0,6 (0,5 a 1100 px) para que el diseño no desborde. Las guías de accesibilidad evalúan el árbol de `Semantics` y los colores renderizados, no la fuente real.
- La compilación de Windows funciona tras instalar el componente ATL (verificado en la fase 6: `good_pizza.exe`). No se ha ejecutado la aplicación contra el backend real. Las pruebas no cubren `flutter_secure_storage` real (Credential Manager) ni la comunicación con el backend real.

## Casos de prueba

IDs WT-xx de `docs/03-design/pruebas-unitarias.md` §2; todos con resultado real **OK** en la última ejecución.

| ID    | Historia/RF        | Descripción                                                                                                                                                                                                                      | Archivo de prueba                                        | Resultado esperado                                    | Estado |
| ----- | ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------- | ----------------------------------------------------- | ------ |
| WT-01 | RNF-05             | Recalcula desde `AppColors`/`AppSemanticColors` las 45 razones de contraste de `design-system.md` §2.4; falla si baja del umbral (texto ≥ 4,5; UI/foco ≥ 3) o se desvía > 0,15 de lo documentado                                 | `test/core/contrast_test.dart` (47 pruebas)              | Todas ≥ umbral; mínimo texto 4,94:1; mínimo UI 4,49:1 | OK     |
| WT-02 | RF-25              | `GoodPizzaLogo` renderiza `SvgPicture` y `Text("Good Pizza")` (el nombre no va en el SVG)                                                                                                                                        | `test/features/shell_test.dart` (logotipo)               | 1 `SvgPicture` + 1 `Text`                             | OK     |
| WT-03 | RF-28              | Rail cliente con 4 destinos, admin con 3; sin `NavigationBar`/`BottomNavigationBar`; badge del carrito; cierre de sesión con confirmación                                                                                        | `shell_test.dart` (AppShell)                             | Destinos por rol                                      | OK     |
| WT-04 | RF-03              | Redirecciones: sin sesión a `/login`; CLIENT en `/admin/*` a `/presets`; ADMIN en ruta de cliente a `/admin/ingredients`; función pura y en la app                                                                               | `test/core/router_test.dart` (11)                        | Rutas esperadas                                       | OK     |
| WT-05 | US-01              | Registro: contraseña de 7 caracteres → "La contraseña debe tener al menos 8 caracteres."; `EMAIL_ALREADY_EXISTS` en el campo email; registro correcto inicia sesión                                                              | `test/features/auth_test.dart`                           | Mensajes exactos                                      | OK     |
| WT-06 | US-02              | Login con `INVALID_CREDENTIALS` → "Email o contraseña incorrectos." (banner único); redirección por rol; `FORBIDDEN`, `RATE_LIMITED`, red                                                                                        | `auth_test.dart`                                         | Banner único                                          | OK     |
| WT-07 | US-03              | S-03 lista 5 predefinidas; la `available:false` muestra "No disponible" y deshabilita botones; cambiar tamaño actualiza precios sin nueva petición                                                                               | `test/features/presets_test.dart`                        | Texto y estados                                       | OK     |
| WT-08 | US-04              | S-04: marcar otra masa/salsa desmarca la anterior; sin selección "Elige una masa." / "Elige una salsa base."                                                                                                                     | `test/features/builder_test.dart`                        | Exclusividad y mensajes                               | OK     |
| WT-09 | US-05              | Stepper no pasa de 3; "Máximo 3 porciones por ingrediente"                                                                                                                                                                       | `builder_test.dart`                                      | Límite                                                | OK     |
| WT-10 | US-06              | Stock 2: máximo 2 y "Stock disponible: 2"; stock 0 deshabilitado con "Agotado"                                                                                                                                                   | `builder_test.dart`                                      | Límite y estado                                       | OK     |
| WT-11 | US-07              | Varios cambios rápidos → una sola cotización (debounce 150 ms); muestra `unitPrice` `$ 7.50` y `unitCalories` `690 kcal`; la petición anterior se cancela                                                                        | `builder_test.dart`, `models_and_controllers_test.dart`  | Valores del repositorio falso                         | OK     |
| WT-12 | US-04              | Con `MIN_TOPPINGS_NOT_MET` "Agregar al pedido" deshabilitado y "Elige al menos 3 ingredientes distintos."                                                                                                                        | `builder_test.dart`                                      | Botón deshabilitado                                   | OK     |
| WT-13 | US-08              | Personalizar Margarita: receta bloqueada, mínimo = porciones de receta, extras = porciones − receta (payload PRESET), sin aviso de mínimo                                                                                        | `builder_test.dart`, `models_and_controllers_test.dart`  | Estado y payload                                      | OK     |
| WT-14 | US-09              | Carrito: cambiar cantidad, quitar con "Deshacer", tope 20 con "Máximo 20 pizzas por línea"; fusión de predefinidas iguales                                                                                                       | `test/features/cart_test.dart`                           | Interacción                                           | OK     |
| WT-15 | US-10              | S-05 muestra Subtotal 15 %, Subtotal 0 %, IVA 15 % y TOTAL de `totals` sin recalcular (15.40 / 3.60 / 2.31 / 21.31 con líneas que no suman a propósito)                                                                          | `cart_test.dart`                                         | Texto exacto                                          | OK     |
| WT-16 | US-11              | Confirmar: `INSUFFICIENT_STOCK` muestra diálogo con ingrediente, solicitado y disponible; `PRICE_CHANGED` muestra el nuevo total y reenvía con el nuevo `expectedTotal`; `PIZZA_RULES_VIOLATED`, `FORBIDDEN`, 500 con Reintentar | `cart_test.dart`                                         | Diálogos                                              | OK     |
| WT-17 | US-12              | S-13 muestra logo, "Good Pizza", número, fecha local, cliente, por pizza tamaño/masa/salsa/ingredientes con cantidad/calorías/precio, resumen, estado y pie; sin imprimir/PDF; orden de bloques                                  | `test/features/orders_test.dart`                         | Presencia y ausencia                                  | OK     |
| WT-18 | US-13              | S-06 lista solo lo que devuelve el repositorio, chip color + icono + texto, vacío "Aún no tienes pedidos.", filtro por estado, refresco manual sin automático                                                                    | `orders_test.dart`                                       | Estados                                               | OK     |
| WT-19 | US-15              | S-07/S-08: IVA 15 % por defecto; falta de un tamaño → error; no hay "Eliminar"; desactivar pide confirmación; el ADMIN envía `includeInactive=true`                                                                              | `test/features/admin_test.dart`                          | Formulario                                            | OK     |
| WT-20 | US-16/17           | S-08: precio negativo y más de 2 decimales rechazados; `StockDialog` muestra `STOCK_WOULD_BE_NEGATIVE`                                                                                                                           | `admin_test.dart`                                        | Mensajes                                              | OK     |
| WT-21 | US-19              | S-10: receta sin mínimo de 3 ingredientes se acepta; sin campo de precio; vista previa con 3 ítems CUSTOM                                                                                                                        | `admin_test.dart`                                        | Formulario                                            | OK     |
| WT-22 | US-20              | S-12: Pendiente → "Pasar a En preparación"; En preparación → "Marcar como Entregado"; Entregado sin botón; `INVALID_STATUS_TRANSITION`                                                                                           | `admin_test.dart`                                        | Estados                                               | OK     |
| WT-23 | contrato §1.2      | `ApiException` mapea los 24 códigos a su mensaje de `screens.md` §6.1; código desconocido a mensaje genérico; 15 violaciones con texto                                                                                           | `test/core/api_exception_test.dart` (12)                 | Tabla de mapeo                                        | OK     |
| WT-24 | RNF-06             | `AsyncValueView`: cargando, vacío, datos y error con "Reintentar"; error de carga + Reintentar en las pantallas                                                                                                                  | `shell_test.dart` (AsyncValueView) y pruebas de pantalla | 3 estados                                             | OK     |
| WT-25 | Accesibilidad      | `textContrastGuideline`, `androidTapTargetGuideline`, `labeledTapTargetGuideline` en S-01, S-02, S-03, S-04, S-05, S-13 y paneles admin; etiqueta semántica del comprobante                                                      | `test/features/accessibility_test.dart` (8)              | Pasa                                                  | OK     |
| WT-26 | Accesibilidad      | Recorrido solo con teclado: Tab real hasta "Agregar al pedido" + Enter, Ctrl+3, Ctrl+Enter, Tab, Enter hasta crear el pedido; Esc; Espacio y flechas                                                                             | `shell_test.dart` (WT-26)                                | Flujo completo                                        | OK     |
| WT-27 | Atajos             | `Ctrl+Enter` agrega (S-04), confirma (S-05) y avanza estado (S-12); `Ctrl+N`, `Ctrl+S`, `F5`, `Ctrl+R`, `F1`, `Alt+←`, `Ctrl+Shift+Q`, `Ctrl+1..4`                                                                               | `shell_test.dart` (WT-27)                                | Acciones                                              | OK     |
| WT-28 | Responsive         | Rail compacto a 1100 px y extendido a 1400 px; predefinidas con 2 / 3 / 4 columnas; panel lateral vs barra inferior; el estado se conserva al redimensionar                                                                      | `shell_test.dart` (WT-28)                                | Layout                                                | OK     |
| WT-29 | Flujo (criterio 4) | Triple queso → agregar → resumen con IVA → confirmar → comprobante con calorías y total; y predefinida con extras                                                                                                                | `test/flows/customize_to_order_flow_test.dart` (2)       | Flujo completo                                        | OK     |
| WT-30 | Formato            | `money_format`: `"7.50"` → `$ 7.50`; `"15.00"` → `15 %`; fechas y validación de precios                                                                                                                                          | `test/core/money_format_test.dart` (8)                   | Formato                                               | OK     |

Pruebas adicionales (no numeradas en el diseño): interceptor de autenticación (Bearer, un solo refresh serializado con token rotativo, reintento, cierre de sesión, fallo de red) en `test/core/auth_interceptor_test.dart`; repositorios `dio` contra un adaptador HTTP falso (rutas, métodos, query `includeInactive`, cuerpos, `expectedTotal`, CancelToken) en `test/core/dio_repositories_test.dart`; reglas del carrito, controlador del armado y parseo de modelos en `cart_test.dart` y `models_and_controllers_test.dart`.

## Defectos encontrados por las pruebas (y corregidos)

| Hallazgo                                                                                                                        | Corrección                                                                                                  |
| ------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Acción "Ver pedido" del snackbar usaba `context` de una pantalla ya desmontada (excepción al pulsarla tras volver a `/presets`) | Se captura `GoRouter` antes (`pizza_builder_page.dart`, `presets_page.dart`, `admin_ingredients_page.dart`) |
| Destinos del `NavigationRail` de 44 px de alto (< 48 px de `accesibilidad.md`)                                                  | `padding` vertical de 2 px por destino                                                                      |
| Texto del ingrediente creaba un nodo táctil de 14 px de alto                                                                    | `GestureDetector(excludeFromSemantics: true)`; la casilla ya expone el nombre, stock y precio               |
| Interruptores de la lista admin sin etiqueta semántica; botón "Editar" de 45,9 px de ancho                                      | `Semantics(label)` y columna de acciones de 56 px fija                                                      |
| Indicador girando bajo el diálogo de `INVALID_STATUS_TRANSITION` (S-12)                                                         | `_busy=false` antes de abrir diálogos                                                                       |
| En modo predefinida, todas las masas/salsas mostraban "Parte de la receta"                                                      | Solo la seleccionada de la receta lleva la marca; el resto queda deshabilitado                              |

## Ubicación del código de pruebas

- Frontend: `frontend/test/core/`, `frontend/test/features/`, `frontend/test/flows/`, `frontend/test/helpers/` (`fakes.dart`, `fixtures.dart`, `pump_app.dart`, `finders.dart`).
- Backend: `backend/tests/…` (fase 4, sin cambios).

## Ejecución

```
cd frontend
flutter pub get
flutter analyze
flutter test
flutter test --coverage
```

## Resultados (salida real)

`flutter analyze`:

```
Analyzing frontend...
No issues found! (ran in 14.8s)
```

`flutter test` (última línea del reporte compacto) y resumen por archivo (reporte JSON de la misma ejecución):

```
00:40 +221: D:/SANTIAGO/CLAUDE-IA/HarnessDev/frontend/test/features/shell_test.dart: WT-24 AsyncValueView error de red muestra el mensaje de conexion
00:40 +221: All tests passed!

test/core/api_exception_test.dart                      12 ok   0 fallos
test/core/auth_interceptor_test.dart                    8 ok   0 fallos
test/core/contrast_test.dart                           47 ok   0 fallos
test/core/dio_repositories_test.dart                   12 ok   0 fallos
test/core/money_format_test.dart                        8 ok   0 fallos
test/core/router_test.dart                             11 ok   0 fallos
test/features/accessibility_test.dart                   8 ok   0 fallos
test/features/admin_test.dart                          25 ok   0 fallos
test/features/auth_test.dart                           13 ok   0 fallos
test/features/builder_test.dart                        11 ok   0 fallos
test/features/cart_test.dart                           12 ok   0 fallos
test/features/models_and_controllers_test.dart         11 ok   0 fallos
test/features/orders_test.dart                         11 ok   0 fallos
test/features/presets_test.dart                         1 ok   0 fallos
test/features/shell_test.dart                          29 ok   0 fallos
test/flows/customize_to_order_flow_test.dart            2 ok   0 fallos
TOTAL 221 pruebas; done: {"success":true,"type":"done","time":55080}
```

`flutter build windows --debug` (resultado real: **FALLA por el entorno**, no por el código Dart):

```
Building Windows application...
D:\SANTIAGO\CLAUDE-IA\HarnessDev\frontend\windows\flutter\ephemeral\.plugin_symlinks\flutter_secure_storage_windows\windows\flutter_secure_storage_windows_plugin.cpp(6,10): error C1083: No se puede abrir el archivo incluir: 'atlstr.h': No such file or directory [...\build\windows\x64\plugins\flutter_secure_storage_windows\flutter_secure_storage_windows_plugin.vcxproj]
Building Windows application...                                    52,6s
Build process failed.
```

Entorno: Visual Studio Build Tools 2022 17.14 sin el componente "C++ ATL" (no existe la carpeta `atlmfc`). Qué hacer: instalar **C++ ATL para las últimas herramientas de compilación v143 (x86 y x64)** y repetir (ver `README.md`). Como comprobación parcial se ejecutó `flutter build bundle --debug --target lib/main.dart`, que compila el Dart a `kernel_blob.bin` y empaqueta los assets (incluidos los 3 SVG) sin errores; eso NO equivale a compilar el ejecutable de Windows.

## Cobertura

Cobertura de líneas de `lib/` medida con `flutter test --coverage` (`coverage/lcov.info`):

| Módulo                                                                   | Líneas cubiertas | %          |
| ------------------------------------------------------------------------ | ---------------- | ---------- |
| `lib/app.dart`                                                           | 17/18            | 94,4 %     |
| `lib/core` (api, config, storage, theme, router, widgets, utils, layout) | 734/780          | 94,1 %     |
| `lib/features/admin`                                                     | 920/1058         | 87,0 %     |
| `lib/features/auth`                                                      | 257/264          | 97,3 %     |
| `lib/features/cart`                                                      | 237/244          | 97,1 %     |
| `lib/features/catalog`                                                   | 115/115          | 100,0 %    |
| `lib/features/orders`                                                    | 505/518          | 97,5 %     |
| `lib/features/pizza_builder`                                             | 402/434          | 92,6 %     |
| `lib/features/preset_pizzas`                                             | 174/175          | 99,4 %     |
| **Total**                                                                | **3361/3606**    | **93,2 %** |

## No verificado

- Arranque del ejecutable de Windows contra el backend real (`flutter run -d windows`): pendiente. La compilación sí funciona tras instalar ATL (fase 6).
- Prueba de humo contra el backend real: el backend no estaba en ejecución y no hay forma de comprobar sin credenciales (ni sin escribir datos) que las tablas tengan datos; se omitió.
- `flutter_secure_storage` real (Credential Manager) y fuente Segoe UI: las pruebas usan almacenamiento en memoria y la fuente Ahem.
- Comportamiento visual real a 100 %–200 % de escala de texto de Windows y con pantalla táctil.
