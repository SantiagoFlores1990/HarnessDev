# Requisitos — Good Pizza

Fuente: `docs/prompt-proyecto.md` y decisiones confirmadas por el usuario. Prioridad con MoSCoW (M = Must, S = Should, C = Could, W = Won't).

## 1. Alcance

Aplicación de escritorio para Windows (Flutter, español, Material 3, paleta azul marino) con backend Node.js (monolito, API REST `/api/v1`) y base PostgreSQL `pizzeria` (ya existente, modelo creado solo con migraciones Prisma). Permite a una pizzería vender pizzas predefinidas o con ingredientes personalizados, calcular precio, calorías e IVA, descontar stock y gestionar el estado de los pedidos. Consumo solo en el local; moneda USD con 2 decimales.

## 2. Actores

| Actor         | Descripción                                                                                                                                                                |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Administrador | Parametriza el sistema (ingredientes, precios, calorías, IVA, stock, pizzas predefinidas) y gestiona pedidos (cambia estado).                                              |
| Cliente       | Se registra e inicia sesión (obligatorio para pedir), arma o elige pizzas, confirma pedidos y consulta estado e historial propios. No parametriza nada ni cancela pedidos. |
| Sistema       | Calcula totales, valida reglas, descuenta stock, numera órdenes, guarda snapshots.                                                                                         |

## 3. Requisitos funcionales

| ID    | Requisito                                                                                                                                                                                                                                                                                                                         | Actor         | Prioridad |
| ----- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------- | --------- |
| RF-01 | Registro de cliente (nombre, email, contraseña de mínimo 8 caracteres, S-21); rol Cliente asignado automáticamente.                                                                                                                                                                                                               | Cliente       | M         |
| RF-02 | Inicio de sesión con JWT; las rutas de pedido exigen sesión.                                                                                                                                                                                                                                                                      | Cliente/Admin | M         |
| RF-03 | Autorización por rol (Admin/Cliente) y por dueño del pedido: un cliente solo ve sus pedidos.                                                                                                                                                                                                                                      | Sistema       | M         |
| RF-04 | CRUD de ingredientes: código único, nombre, categoría (masa, salsa, queso, carne, vegetal, otros), activo sí/no, stock (porciones), tarifa IVA (15 % por defecto, o 0 %). Incluye masa y salsa. Los ingredientes solo se desactivan, nunca se borran (S-23).                                                                      | Admin         | M         |
| RF-05 | Por ingrediente y por tamaño (Individual, Mediana, Familiar): calorías por porción y precio por porción, definidos por el administrador (sin factor fijo).                                                                                                                                                                        | Admin         | M         |
| RF-06 | Gestión de stock de ingredientes (consultar y modificar).                                                                                                                                                                                                                                                                         | Admin         | M         |
| RF-07 | CRUD de pizzas predefinidas (Margarita, Pepperoni, Hawaiana, Vegetariana, 4 Quesos) con su receta (masa, salsa, ingredientes y cantidades).                                                                                                                                                                                       | Admin         | M         |
| RF-08 | Listar pizzas predefinidas con su precio y calorías por tamaño. El precio siempre sale de la fórmula (masa + salsa + ingredientes según tamaño); no hay precio fijo (S-18). Una predefinida con un ingrediente inactivo o sin stock se muestra como no disponible (S-25).                                                         | Cliente       | M         |
| RF-09 | Pantalla "Personalizar pizza": elegir tamaño, exactamente 1 masa y 1 salsa, e ingredientes con checkbox y cantidad.                                                                                                                                                                                                               | Cliente       | M         |
| RF-10 | Máximo 3 porciones por ingrediente (repetición permitida, p. ej. triple queso).                                                                                                                                                                                                                                                   | Sistema       | M         |
| RF-11 | Mínimo 3 ingredientes distintos además de masa y salsa, solo en pizzas personalizadas armadas desde cero. No aplica a predefinidas ni a su personalización por adición (S-17).                                                                                                                                                    | Sistema       | M         |
| RF-12 | No permitir más porciones que el stock disponible.                                                                                                                                                                                                                                                                                | Sistema       | M         |
| RF-13 | Mostrar en vivo calorías totales y precio de la pizza al armarla.                                                                                                                                                                                                                                                                 | Cliente       | M         |
| RF-14 | Personalizar una predefinida solo agregando ingredientes (no quitar); las porciones de la receta cuentan para el máximo de 3. No se exige el mínimo de 3 ingredientes (S-17); las predefinidas se venden con su receta tal cual, incluso con menos de 3 ingredientes.                                                             | Cliente       | M         |
| RF-15 | Precio de pizza = precio masa(tamaño) + precio salsa(tamaño) + Σ(precio ingrediente(tamaño) × cantidad). Calorías con la misma fórmula. Precios sin IVA.                                                                                                                                                                          | Sistema       | M         |
| RF-16 | IVA por componente según tarifa del ingrediente; el pedido muestra Subtotal 15 %, Subtotal 0 %, IVA 15 % y Total (= subtotales + IVA). El IVA se calcula sobre cada subtotal (15 % y 0 %) y se redondea a 2 decimales, half-up (S-19).                                                                                            | Sistema       | M         |
| RF-17 | Un pedido admite varias pizzas, cada una con su cantidad (1 a 20 por línea, S-26).                                                                                                                                                                                                                                                | Cliente       | M         |
| RF-18 | Al confirmar: descontar stock en una transacción (1 unidad por porción; masa y salsa 1 por pizza, multiplicado por cantidad de pizzas); si no alcanza, rechazar con mensaje claro y sin cambios parciales.                                                                                                                        | Sistema       | M         |
| RF-19 | Snapshot en el pedido de precios, calorías y tarifa IVA al momento de la compra; cambios posteriores no alteran pedidos antiguos.                                                                                                                                                                                                 | Sistema       | M         |
| RF-20 | Número de orden con formato `GP-AAAAMMDD-0001`; fecha en la zona horaria del servidor (S-24).                                                                                                                                                                                                                                     | Sistema       | M         |
| RF-21 | Estados Pendiente → En preparación → Entregado; solo el administrador los cambia; el cliente los ve. El cliente no puede cancelar pedidos y no hay devolución de stock (S-20).                                                                                                                                                    | Admin         | M         |
| RF-22 | Cliente consulta estado e historial de sus pedidos.                                                                                                                                                                                                                                                                               | Cliente       | M         |
| RF-23 | Admin lista y gestiona todos los pedidos.                                                                                                                                                                                                                                                                                         | Admin         | M         |
| RF-24 | Comprobante/orden: encabezado con logo y "Good Pizza", número y fecha; datos del cliente; por pizza: tamaño, masa, salsa, ingredientes con cantidad, calorías y precio; resumen con calorías totales, Subtotal 15 %, Subtotal 0 %, IVA 15 % y TOTAL USD; estado actual. Solo se muestra en pantalla, sin PDF ni impresión (S-22). | Cliente       | M         |
| RF-25 | Logotipo SVG de Good Pizza usado en la app y en la orden.                                                                                                                                                                                                                                                                         | Sistema       | M         |
| RF-26 | Seed: 1 admin y 1 cliente (contraseñas desde `SEED_ADMIN_PASSWORD`/`SEED_CLIENT_PASSWORD`, o aleatorias impresas una vez), ~20 ingredientes de ejemplo y las 5 predefinidas.                                                                                                                                                      | Sistema       | M         |
| RF-27 | Endpoint `/api/v1/health`.                                                                                                                                                                                                                                                                                                        | Sistema       | S         |
| RF-28 | Pantallas cliente: registro, login, predefinidas, personalizar, resumen del pedido, mis pedidos. Pantallas admin: ingredientes, predefinidas, gestión de pedidos. Navegación con NavigationRail.                                                                                                                                  | Ambos         | M         |
| RF-29 | Los ingredientes inactivos no se ofrecen al cliente y se conservan para el histórico de pedidos.                                                                                                                                                                                                                                  | Admin         | S         |

## 4. Requisitos no funcionales

| ID     | Categoría      | Requisito                                                                                                                                                                | Prioridad |
| ------ | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------- |
| RNF-01 | Rendimiento    | Cálculo en vivo en cliente sin esperas perceptibles (< 200 ms); respuestas de API habituales < 500 ms en el local (un solo establecimiento).                             | S         |
| RNF-02 | Integridad     | Dinero con `Decimal` (nunca Float); redondeo a 2 decimales half-up; descuento de stock transaccional y sin sobreventa en concurrencia.                                   | M         |
| RNF-03 | Seguridad      | Contraseñas con bcrypt (mínimo 8 caracteres); JWT; helmet, cors, rate limit; validación con Zod; sin contraseñas ni secretos en el repo; no se lee `backend/.env.local`. | M         |
| RNF-04 | Seguridad      | Autorización por rol y por dueño en cada endpoint; el servidor recalcula precios (no confía en el cliente).                                                              | M         |
| RNF-05 | UX             | Interfaz en español, Material 3, escritorio con NavigationRail, azul marino con contraste adecuado (WCAG AA), modo claro.                                                | M         |
| RNF-06 | UX             | Mensajes de error claros (p. ej. stock insuficiente indica ingrediente y disponibilidad).                                                                                | M         |
| RNF-07 | Portabilidad   | Solo Windows (`flutter run -d windows`); backend Node 20+, PostgreSQL 17.                                                                                                | M         |
| RNF-08 | Calidad        | `npm test` y `flutter test` pasan; `flutter analyze` sin errores; pruebas de cálculo, reglas, stock, endpoints y permisos.                                               | M         |
| RNF-09 | Mantenibilidad | Migraciones Prisma; documentación en español, código en inglés.                                                                                                          | M         |
| RNF-10 | Auditabilidad  | Pedidos conservan snapshots inmutables.                                                                                                                                  | M         |

## 5. Supuestos (decisiones del prompt, decisiones confirmadas y supuestos derivados)

Decisiones del prompt:

- S-01: Mínimo 3 ingredientes distintos además de masa y salsa (solo personalizadas, ver S-17).
- S-02: Máximo 3 porciones por ingrediente (incluye las de la receta predefinida).
- S-03: 1 unidad de stock por porción.
- S-04: Masa y salsa descuentan 1 unidad por pizza.
- S-05: IVA 15 % o 0 % por ingrediente (defecto 15 %); precios de catálogo sin IVA.
- S-06: Las predefinidas solo permiten agregar ingredientes, no quitar.
- S-07: Estados Pendiente, En preparación, Entregado; solo el admin los cambia, en ese orden.
- S-08: Tres tamaños fijos; calorías y precio distintos por tamaño, sin factor fijo.
- S-09: Sin delivery ni pasarela de pago; solo se registra el pedido.
- S-10: Moneda USD, 2 decimales; idioma español.
- S-11: Sin fase DevOps/Docker/CI.

Supuestos adicionales (razonables, no bloquean):

- S-12: El stock de un pedido de N pizzas se descuenta multiplicando por N.
- S-13: La numeración `0001` es secuencial por día y reinicia cada día.
- S-14: El registro público solo crea clientes; el administrador se crea por seed.
- S-15: Los ingredientes inactivos no se ofrecen para nuevos pedidos pero se conservan en el histórico.
- S-16: La app y los datos del seed son de ejemplo, no precios reales.

Decisiones confirmadas por el usuario (reglas firmes):

- S-17: El mínimo de 3 ingredientes distintos aplica solo a pizzas personalizadas. Las predefinidas se venden con su receta tal cual (incluso con menos de 3 ingredientes). Al personalizarlas agregando ingredientes no se exige el mínimo.
- S-18: El precio de las predefinidas siempre sale de la fórmula (masa + salsa + ingredientes según tamaño); no hay precio fijo.
- S-19: El IVA se calcula sobre cada subtotal (15 % y 0 %) y se redondea a 2 decimales, half-up.
- S-20: El cliente no puede cancelar pedidos; no hay devolución de stock.
- S-21: La contraseña tiene mínimo 8 caracteres.
- S-22: El comprobante solo se muestra en pantalla (sin PDF ni impresión).
- S-23: Los ingredientes solo se desactivan, nunca se borran.
- S-24: La zona horaria para fecha y número de orden es la del servidor.
- S-25: Una predefinida con un ingrediente inactivo o sin stock queda no disponible.
- S-26: Máximo 20 pizzas por línea del pedido (cantidad entre 1 y 20).

## 6. Fuera de alcance

Delivery, pasarela de pago, cancelación por el cliente y devolución de stock, retroceso de estados, borrado de ingredientes, exportación/impresión (PDF) del comprobante, otras plataformas (móvil, web, Linux, macOS), DevOps/Docker/CI, factura electrónica oficial, multi-sucursal, recuperación de contraseña, notificaciones.

## 7. Preguntas abiertas

Resueltas por el usuario; incorporadas como reglas firmes S-17 a S-26 y en los RF. No quedan preguntas abiertas.
