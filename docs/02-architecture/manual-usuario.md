# Manual de usuario — Fase 2: Arquitectura

> En esta fase el manual describe lo que el usuario podrá hacer según la arquitectura definida (pantallas, reglas y mensajes). Las capturas y el detalle visual llegan con las fases de diseño UX (3) y frontend (5).

## 1. Introducción

Good Pizza es una aplicación de escritorio para la pizzería del mismo nombre. Los **clientes** se registran, eligen una pizza predefinida o arman la suya, ven en vivo calorías y precio, confirman el pedido y siguen su estado. El **administrador** mantiene el catálogo de ingredientes (precios, calorías, IVA y stock por tamaño), las pizzas predefinidas y avanza el estado de los pedidos. Todo el consumo es en el local; no hay delivery ni pagos en la app.

## 2. Requisitos

- Equipo con Windows 10/11 de 64 bits.
- El servidor de Good Pizza (backend) en ejecución y accesible en la red del local.
- Otras plataformas (móvil, Linux, macOS, web) están fuera del alcance.

## 3. Acceso al sistema

- **Registro (clientes):** nombre, email y contraseña (mínimo 8 caracteres). La cuenta se crea siempre como Cliente.
- **Inicio de sesión:** email y contraseña. Ante datos incorrectos se muestra "Email o contraseña incorrectos." sin indicar cuál falló.
- La sesión se mantiene de forma segura en el equipo y se renueva sola mientras se usa; "Cerrar sesión" la termina.
- La cuenta de administrador no se registra desde la app: la crea la carga inicial de datos.

## 4. Guía por funcionalidad

### 4.1 Pizzas predefinidas (cliente)

**Objetivo:** pedir rápido una receta del local. · **Pasos:** 1. Abrir "Pizzas predefinidas" en el menú lateral. 2. Ver Margarita, Pepperoni, Hawaiana, Vegetariana y 4 Quesos con receta, calorías y precio por tamaño (Individual, Mediana, Familiar). 3. Elegir tamaño y "Agregar al pedido", o "Personalizar" para añadir ingredientes. · **Resultado:** la pizza queda en el pedido. Las pizzas con algún ingrediente agotado o desactivado aparecen como "No disponible".

### 4.2 Personalizar pizza (cliente)

**Objetivo:** armar una pizza a gusto. · **Pasos:** 1. Elegir tamaño. 2. Elegir exactamente una masa y una salsa base. 3. Marcar ingredientes y su cantidad (1 a 3 porciones; p. ej. triple queso). 4. Revisar calorías y precio, que se actualizan al instante. 5. Elegir cuántas pizzas iguales (1 a 20) y "Agregar al pedido". · **Resultado:** la pizza se añade al pedido.
Reglas visibles:

- Pizza armada desde cero: al menos 3 ingredientes distintos además de masa y salsa.
- Predefinida personalizada: sus ingredientes vienen marcados y no se pueden quitar ni reducir; solo se agregan. Las porciones de la receta cuentan para el máximo de 3.
- No se puede elegir más porciones que el stock disponible; un ingrediente sin stock aparece deshabilitado.

### 4.3 Resumen del pedido (cliente)

**Objetivo:** revisar y confirmar. · **Pasos:** 1. Abrir "Pedido". 2. Revisar cada pizza con cantidad, calorías y precio; cambiar cantidades o eliminar líneas. 3. Ver Subtotal 15 %, Subtotal 0 %, IVA 15 % y Total. 4. "Confirmar pedido". · **Resultado:** se genera la orden `GP-AAAAMMDD-0001` en estado Pendiente y se muestra el comprobante. Si mientras tanto se agotó algún ingrediente o cambió un precio, la app lo informa y actualiza el resumen antes de volver a confirmar.

### 4.4 Comprobante y Mis pedidos (cliente)

**Objetivo:** consultar pedidos. · **Pasos:** 1. Abrir "Mis pedidos" (número, fecha, total y estado). 2. Abrir un pedido para ver el comprobante: logo y "Good Pizza", número y fecha, datos del cliente, detalle por pizza (tamaño, masa, salsa, ingredientes con cantidad, calorías y precio), calorías totales, subtotales, IVA, TOTAL en USD y estado actual. · **Resultado:** información solo en pantalla (sin PDF ni impresión). Los importes no cambian aunque luego cambien los precios del catálogo. El cliente no puede cancelar pedidos.

### 4.5 Ingredientes (administrador)

**Objetivo:** mantener el catálogo. · **Pasos:** 1. Abrir "Ingredientes". 2. Crear o editar: código único, nombre, categoría (masa, salsa, queso, carne, vegetal, otros), tarifa de IVA (15 % por defecto u 0 %), y precio y calorías por porción para los tres tamaños. 3. Ajustar stock (fijar un valor o sumar/restar). 4. Desactivar o reactivar. · **Resultado:** los cambios aplican a pedidos nuevos; los ingredientes nunca se borran.

### 4.6 Pizzas predefinidas (administrador)

**Objetivo:** mantener las recetas. · **Pasos:** 1. Abrir "Pizzas predefinidas". 2. Editar la receta: una masa, una salsa y los ingredientes con porciones (máximo 3 cada uno). 3. Activar o desactivar. · **Resultado:** el precio se calcula siempre con la fórmula (no hay precio fijo); los cambios solo afectan a pedidos nuevos.

### 4.7 Gestión de pedidos (administrador)

**Objetivo:** atender pedidos. · **Pasos:** 1. Abrir "Pedidos" (filtros por estado y fecha). 2. Abrir un pedido. 3. Avanzar Pendiente → En preparación → Entregado. · **Resultado:** el cliente ve el nuevo estado al refrescar. No se puede retroceder ni saltar estados.

## 5. Mensajes de error frecuentes

| Mensaje                                                   | Causa                                                  | Solución                      |
| --------------------------------------------------------- | ------------------------------------------------------ | ----------------------------- |
| La contraseña debe tener al menos 8 caracteres.           | Contraseña corta al registrarse.                       | Usar 8 o más caracteres.      |
| El email ya está registrado.                              | Cuenta existente.                                      | Iniciar sesión.               |
| Email o contraseña incorrectos.                           | Credenciales erróneas.                                 | Revisar los datos.            |
| Elige una masa. / Elige una salsa base.                   | Falta un componente base.                              | Seleccionarlo.                |
| Elige al menos 3 ingredientes distintos.                  | Pizza armada desde cero con menos de 3.                | Agregar ingredientes.         |
| Máximo 3 porciones por ingrediente.                       | Se intentó una cuarta porción.                         | Reducir la cantidad.          |
| Máximo 20 pizzas por línea.                               | Cantidad mayor a 20.                                   | Usar otra línea o reducir.    |
| No hay stock suficiente de X: solicitado N, disponible M. | Se agotó al confirmar.                                 | Ajustar el pedido.            |
| Los precios cambiaron; revisa el nuevo total.             | Precio modificado entre la revisión y la confirmación. | Revisar y confirmar de nuevo. |
| La pizza X no está disponible.                            | Ingrediente de la receta inactivo o agotado.           | Elegir otra pizza.            |
| Transición de estado no permitida.                        | (Admin) retroceso o salto de estado.                   | Avanzar en orden.             |
| Tu sesión expiró.                                         | Sesión vencida o revocada.                             | Iniciar sesión otra vez.      |

## 6. Preguntas frecuentes

- **¿Los precios incluyen IVA?** No; el IVA (15 % o 0 % según cada ingrediente) se suma en el resumen.
- **¿Por qué el total puede diferir en un centavo de mi cuenta mental?** El IVA se calcula sobre el subtotal 15 % del pedido y se redondea a 2 decimales hacia arriba en la mitad (0,045 → 0,05).
- **¿Puedo cancelar un pedido?** No; consulte con el local.
- **¿Los datos iniciales son reales?** No: ingredientes, precios y stock de la carga inicial son de ejemplo.

## 7. Soporte

Contactar al administrador del local. Para soporte técnico, ver `documentacion-tecnica.md`.
