# Manual de usuario — Fase 4 (Backend)

En esta fase todavía no existe la aplicación de escritorio: el "usuario" del backend es quien lo instala, lo prueba y lo opera (administrador técnico). Este manual explica cómo ponerlo en marcha y qué hace la API desde el punto de vista de cada rol. La guía de pantallas llegará con la fase 5.

## 1. Introducción

El backend de Good Pizza es la API que usará la aplicación Windows. Permite que un **cliente** se registre, arme o elija pizzas, confirme el pedido y vea su estado, y que un **administrador** gestione ingredientes (precios, calorías, IVA, stock), pizzas predefinidas y el avance de los pedidos. Todo el consumo es en el local; no hay pago en línea ni delivery. Moneda: USD con 2 decimales; los precios del catálogo no incluyen IVA.

## 2. Requisitos

- Windows con Node.js 20 o superior y npm.
- PostgreSQL con la base `pizzeria` ya creada y `backend/.env.local` con tus credenciales (modelo: `backend/env.template`).
- Puerto 3000 libre (o el que definas en `PORT`).

## 3. Puesta en marcha

1. `cd backend` y `npm install`.
2. `npm run db:migrate` (crea las tablas en `pizzeria`; no borra datos).
3. `npm run db:seed` (carga datos de ejemplo). Si no definiste `SEED_ADMIN_PASSWORD` y `SEED_CLIENT_PASSWORD`, el seed muestra una contraseña generada para cada usuario **una sola vez**: guárdalas en ese momento.
4. `npm run dev`.
5. Abre `http://localhost:3000/api/v1/health`: debe mostrar `"status":"ok"` y `"database":"ok"`.

Usuarios de ejemplo (emails por defecto): `admin@goodpizza.local` (administrador) y `cliente@goodpizza.local` (cliente). Los ingredientes, precios y existencias cargados son **datos de ejemplo**; revísalos antes de usar precios reales.

## 4. Guía por funcionalidad

### 4.1 Registro e inicio de sesión (cliente)

**Objetivo:** obtener acceso para pedir. **Pasos:** `POST /api/v1/auth/register` con nombre, email y contraseña de al menos 8 caracteres; luego `POST /api/v1/auth/login`. **Resultado:** un token de acceso (15 minutos) y uno de renovación (7 días). Todas las demás llamadas llevan `Authorization: Bearer <accessToken>`. El registro siempre crea un cliente; el administrador lo crea el seed.

### 4.2 Elegir una pizza predefinida o armar una (cliente)

**Objetivo:** ver el catálogo y calcular el precio en vivo. **Pasos:** `GET /preset-pizzas` (precio y calorías por tamaño, y si está disponible), `GET /ingredients` (con stock) y `POST /orders/quote` con la pizza. **Reglas que verás reflejadas:**

- Una masa y una salsa base por pizza.
- Pizza armada desde cero: mínimo 3 ingredientes distintos además de masa y salsa; máximo 3 porciones por ingrediente (ejemplo: triple queso = 3 porciones de queso).
- Predefinidas: solo se pueden agregar ingredientes; las porciones de la receta cuentan para el máximo de 3.
- No se puede pedir más de lo que hay en stock; máximo 20 pizzas por línea.
- El resultado incluye calorías totales, Subtotal 15 %, Subtotal 0 %, IVA 15 % y Total.

### 4.3 Confirmar el pedido (cliente)

**Pasos:** `POST /orders` con las pizzas (y, opcionalmente, el total esperado). **Resultado:** el pedido queda en estado Pendiente con número `GP-AAAAMMDD-0001` y el stock se descuenta. Si el stock no alcanza, el pedido no se crea y el mensaje indica el ingrediente, lo solicitado y lo disponible. Si el total cambió entre la cotización y la confirmación (p. ej. el administrador cambió un precio) se informa y se devuelve la nueva cotización.

### 4.4 Consultar pedidos (cliente)

`GET /orders` lista solo tus pedidos; `GET /orders/{id}` muestra el comprobante (cliente, pizzas con ingredientes, calorías, subtotales, IVA, total y estado). Los pedidos de otros clientes no se pueden ver (responden "no encontrado"). Un pedido antiguo no cambia aunque cambien los precios.

### 4.5 Administrar ingredientes (administrador)

**Pasos:** `POST /ingredients` para crear (código único, categoría, tarifa de IVA 15 % o 0 %, stock y precio/calorías de los 3 tamaños); `PUT /ingredients/{id}` para editar precios, calorías, IVA o nombre; `PATCH /ingredients/{id}/stock` para fijar (`SET`) o ajustar (`ADD`) existencias; `PATCH /ingredients/{id}/status` para desactivar o activar. Los ingredientes **no se borran**: se desactivan, y las pizzas predefinidas que los usan pasan a "no disponibles".

### 4.6 Administrar pizzas predefinidas (administrador)

`POST /preset-pizzas` y `PUT /preset-pizzas/{id}` definen la receta (una masa, una salsa y toppings con 1 a 3 porciones). No tienen precio propio: se calcula con la fórmula y los precios vigentes. Se desactivan con `PATCH /preset-pizzas/{id}/status` (no se borran).

### 4.7 Gestionar pedidos (administrador)

`GET /orders` muestra todos (filtros por estado, fechas y búsqueda por número o email). `PATCH /orders/{id}/status` avanza el estado: Pendiente -> En preparación -> Entregado. No se puede saltar ni retroceder. El cliente no puede cambiar estados y el administrador no puede confirmar pedidos.

## 5. Mensajes de error frecuentes

| Mensaje (code)                                    | Causa                                                                                                 | Solución                                                                                  |
| ------------------------------------------------- | ----------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `VALIDATION_ERROR`                                | Datos inválidos (contraseña < 8, cantidad fuera de 1..20, porciones fuera de 1..3, campo desconocido) | Corregir según `details` (campo y motivo).                                                |
| `UNAUTHENTICATED` / `TOKEN_EXPIRED`               | Falta el token o caducó                                                                               | Iniciar sesión o usar `/auth/refresh`.                                                    |
| `INVALID_CREDENTIALS`                             | Email o contraseña incorrectos                                                                        | Verificar los datos.                                                                      |
| `FORBIDDEN`                                       | El rol no tiene permiso                                                                               | Usar una cuenta con el rol adecuado.                                                      |
| `NOT_FOUND`                                       | No existe o es de otro cliente                                                                        | Verificar el id.                                                                          |
| `PIZZA_RULES_VIOLATED`                            | Menos de 3 ingredientes distintos, más de 3 porciones, falta masa o salsa, ingrediente no disponible  | Corregir la pizza según `details`.                                                        |
| `INSUFFICIENT_STOCK`                              | No hay existencias suficientes                                                                        | Reducir la cantidad o elegir otro ingrediente; el mensaje indica solicitado y disponible. |
| `PRICE_CHANGED`                                   | El total cambió desde la cotización                                                                   | Revisar la nueva cotización y confirmar de nuevo.                                         |
| `INVALID_STATUS_TRANSITION`                       | Salto o retroceso de estado                                                                           | Seguir el orden Pendiente -> En preparación -> Entregado.                                 |
| `MISSING_SIZE_VALUES`                             | Faltan precio/calorías de algún tamaño                                                                | Indicar los 3 tamaños, una vez cada uno.                                                  |
| `RATE_LIMITED`                                    | Demasiadas solicitudes                                                                                | Esperar unos minutos.                                                                     |
| `SERVICE_UNAVAILABLE` (health)                    | La base de datos no responde                                                                          | Revisar que PostgreSQL esté iniciado y `DATABASE_URL`.                                    |
| "Configuración inválida. Revisa estas variables…" | Falta una variable de entorno al arrancar                                                             | Completar el nombre indicado en `backend/.env.local` (ver `env.template`).                |

## 6. Preguntas frecuentes

- **¿Dónde veo la contraseña generada por el seed?** Solo en la consola donde ejecutaste `npm run db:seed`, una vez. Si la perdiste, define `SEED_*_PASSWORD` en `.env.local` y vuelve a crear el usuario (el seed no cambia contraseñas de usuarios existentes).
- **¿Puedo borrar un ingrediente?** No; se desactiva.
- **¿El cliente puede cancelar un pedido?** No.
- **¿Qué zona horaria usa el número de orden?** La del servidor.

## 7. Soporte

Ver `docs/04-backend/README.md` (cómo correr, variables y endpoints) y `documentacion-tecnica.md`.
