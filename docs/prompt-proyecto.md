# Prompt del proyecto — Good Pizza

Cómo usarlo: abre Claude Code en la raíz del repositorio, en la rama `testHarness`, y pega todo el contenido del bloque de abajo (incluida la línea `/build-app`).

Antes de ejecutar:

- Define `SEED_ADMIN_PASSWORD` y `SEED_CLIENT_PASSWORD` en `backend/.env.local` si quieres contraseñas propias; si no, el seed las genera y las imprime una sola vez.
- La base de datos `pizzeria` debe existir y `backend/.env.local` debe tener las credenciales.
- Revisa las tarifas de IVA (15 % o 0 %) de los ingredientes de ejemplo antes de usar precios reales.

```
/build-app
# Good Pizza — sistema de venta de pizzas con ingredientes personalizados

## Contexto
Pizzería "Good Pizza". Aplicación de escritorio para Windows (Flutter) con backend Node.js, monolito en este repositorio. Todo el consumo es en el local: sin delivery ni pasarela de pago (solo se registra el pedido). Idioma de la interfaz: español. Moneda: USD con 2 decimales.

## Reglas de trabajo (obligatorias)
- Usa los agentes del SDLC en orden: requisitos, arquitectura, diseño UX, backend, frontend, QA, seguridad y documentación final. OMITE la fase 8 (DevOps/Docker/CI): Docker no está instalado.
- Cada fase genera sus 6 entregables (skill phase-deliverables) en docs/NN-*.
- La base de datos PostgreSQL `pizzeria` YA EXISTE. No la borres ni la recrees; crea todo el modelo con migraciones de Prisma.
- NO leas ni modifiques backend/.env.local. Usa los scripts npm (db:migrate, db:seed, dev), que lo cargan con dotenv-cli. Si falta alguna variable, agrégala a backend/env.template y dime qué valor debo poner.
- No guardes contraseñas en el código ni en el repo (es público).
- Trabaja en la rama testHarness. No hagas commit ni push; al final dame un resumen con comandos de ejecución.
- Si algo es ambiguo y no está aquí, pregúntame en vez de inventar.

## Roles
- **Administrador:** parametriza el sistema. CRUD de ingredientes (incluida masa y salsa), precios, calorías y tarifa de IVA por ingrediente, stock, pizzas predefinidas, y gestión de pedidos (cambiar estado).
- **Cliente:** se registra e inicia sesión (obligatorio para pedir). Elige una pizza predefinida o arma una, la agrega al pedido y consulta el estado y el historial de sus pedidos. No parametriza nada.

## Catálogo de ingredientes
Cada ingrediente tiene: código único, nombre, categoría (masa, salsa, queso, carne, vegetal, otros), activo sí/no, stock (en porciones) y tarifa de IVA (15 % o 0 %, por defecto 15 %).
Por cada tamaño tiene calorías por porción y precio por porción. Tamaños: **Individual, Mediana, Familiar**. Ambos valores son distintos por tamaño y los define el administrador (no uses un factor fijo).
La masa y la salsa base son ingredientes con precio y calorías por tamaño.

## Armado de la pizza (cliente)
Pantalla "Personalizar pizza", con checkboxes:
1. Elegir tamaño.
2. Elegir exactamente 1 masa y 1 salsa base.
3. Marcar ingredientes con checkbox y cantidad por ingrediente; se puede repetir (ej.: triple queso). Máximo 3 porciones por ingrediente.
4. Mínimo 3 ingredientes distintos, además de la masa y la salsa.
5. Se muestran en vivo las calorías totales y el precio de la pizza.
6. No se permite elegir más porciones que el stock disponible.

**Pizzas predefinidas:** 5 tipos (Margarita, Pepperoni, Hawaiana, Vegetariana, 4 Quesos) con su receta. El cliente puede personalizarlas **solo agregando** ingredientes (no quitar). Las porciones de la receta cuentan para el máximo de 3 por ingrediente.

## Cálculo
- Precio de una pizza = precio masa(tamaño) + precio salsa(tamaño) + suma de (precio ingrediente(tamaño) × cantidad).
- Calorías = misma fórmula con las calorías por tamaño.
- IVA: se calcula por componente según la tarifa del ingrediente (15 % o 0 %). El pedido muestra: Subtotal 15 %, Subtotal 0 %, IVA 15 % y Total (= subtotales + IVA).
- Los precios del catálogo NO incluyen IVA.
- Guarda en el pedido una copia (snapshot) de precios, calorías y tarifa de IVA al momento de la compra, para que cambios posteriores no alteren pedidos antiguos.
- Al confirmar el pedido se descuenta el stock en una transacción (1 unidad por porción; masa y salsa descuentan 1 por pizza); si no alcanza, rechaza el pedido con un mensaje claro.

## Pedido
- Un pedido puede tener varias pizzas, cada una con su cantidad.
- Estados: **Pendiente → En preparación → Entregado**. Solo el administrador los cambia; el cliente los ve.
- Número de orden con formato `GP-AAAAMMDD-0001`.
- Orden final (diseña el comprobante así): encabezado con logo y "Good Pizza", número de orden y fecha; datos del cliente; por cada pizza: tamaño, masa, salsa, lista de ingredientes con cantidad, calorías y precio; resumen con calorías totales, Subtotal 15 %, Subtotal 0 %, IVA 15 % y TOTAL en USD; estado actual.

## Modelo de datos (PostgreSQL, Prisma)
Diseña el diagrama entidad-relación completo en la base `pizzeria`. Como mínimo: usuarios y roles, tamaños, categorías, tarifas de IVA, ingredientes, valores por tamaño de cada ingrediente (calorías y precio), pizzas predefinidas y sus ingredientes, pedidos, pizzas del pedido, ingredientes de cada pizza del pedido (con snapshots). Dinero con Decimal, nunca Float.

## Backend (Node.js)
API REST /api/v1 con la arquitectura de las skills (Express, Prisma, Zod, JWT, bcrypt, helmet, cors, rate limit). Autorización por rol y por dueño del pedido (un cliente solo ve sus pedidos). Endpoint /api/v1/health.

## Frontend (Flutter, solo Windows)
- Crear con: `flutter create --org com.pizzeria --project-name good_pizza --platforms=windows .` dentro de frontend/. Nombre visible: "Good Pizza".
- Escritorio con NavigationRail, Material 3, español, tema con paleta de **azul marino** (define tú la paleta completa, con buen contraste y modo claro).
- Crea tú el logotipo de Good Pizza en SVG y úsalo en la app y en la orden.
- Pantallas cliente: registro, login, pizzas predefinidas, personalizar pizza, resumen del pedido, mis pedidos con estado. Pantallas admin: ingredientes, pizzas predefinidas y gestión de pedidos.

## Datos de ejemplo (seed)
- 1 usuario administrador y 1 cliente para simular pedidos.
- Sus contraseñas se leen de las variables SEED_ADMIN_PASSWORD y SEED_CLIENT_PASSWORD; si no existen, genera una aleatoria por usuario e imprímela una sola vez en consola. Nunca las escribas en el código.
- Unos 20 ingredientes de ejemplo (2 a 3 masas, 3 salsas, quesos, carnes, vegetales), con valores plausibles por tamaño, stock inicial y tarifa de IVA (la mayoría 15 %, algunos 0 %). Indica en la documentación que son datos de ejemplo.

## Pruebas
- Backend (Vitest + Supertest): pruebas unitarias de cálculo de precio, calorías, IVA 15 %/0 %, reglas de armado (mínimo 3 ingredientes, máximo 3 porciones, stock) y descuento de stock; más pruebas de endpoints y permisos.
- Frontend: pruebas de widget y de funcionalidad del flujo "personalizar pizza hasta generar la orden". Ejecuta todo y reporta resultados reales.

## Criterios de aceptación
1. Como cliente: me registro, inicio sesión, personalizo una pizza (por ejemplo triple queso) y obtengo la orden con calorías totales y total en USD con IVA desglosado.
2. Como administrador: cambio el precio y el stock de un ingrediente, y avanzo el estado de un pedido hasta Entregado.
3. Los pedidos antiguos no cambian cuando cambian los precios.
4. `npm test` y `flutter test` pasan; `flutter analyze` sin errores; la app arranca con `flutter run -d windows`.
```
