# Historias de usuario — Good Pizza

Prioridad MoSCoW entre corchetes. Referencias a RF en `requirements.md`; reglas firmes S-xx en la sección 5 de ese documento.

## Cliente

### US-01 Registro [M] (RF-01)

Como cliente quiero registrarme para poder hacer pedidos.

- Given que no tengo cuenta, When envío nombre, email válido y contraseña de al menos 8 caracteres, Then se crea mi cuenta con rol Cliente y puedo iniciar sesión.
- Given una contraseña de menos de 8 caracteres, When intento registrarme, Then se rechaza con un mensaje que indica el mínimo de 8 caracteres.
- Given un email ya registrado, When intento registrarme, Then recibo un mensaje de que el email ya existe y no se crea cuenta.

### US-02 Inicio de sesión [M] (RF-02)

Como cliente quiero iniciar sesión para acceder a mis pedidos.

- Given una cuenta válida, When ingreso credenciales correctas, Then accedo a la app con mi sesión.
- Given credenciales incorrectas, When intento ingresar, Then veo un error genérico sin revelar cuál dato falló.
- Given que no inicié sesión, When intento confirmar un pedido, Then se me pide iniciar sesión.

### US-03 Ver pizzas predefinidas [M] (RF-08)

Como cliente quiero ver las pizzas predefinidas para elegir rápido.

- Given que inicié sesión, When abro "Pizzas predefinidas", Then veo Margarita, Pepperoni, Hawaiana, Vegetariana y 4 Quesos con receta, calorías y precio por tamaño.
- Given una predefinida, When veo su precio, Then es el resultado de la fórmula masa + salsa + ingredientes según el tamaño (no hay precio fijo).
- Given una predefinida con un ingrediente inactivo o sin stock, When abro la lista, Then se muestra como no disponible y no se puede pedir.

### US-04 Armar pizza personalizada [M] (RF-09, RF-11)

Como cliente quiero armar mi pizza para comer lo que me gusta.

- Given la pantalla "Personalizar pizza" armada desde cero, When elijo tamaño, 1 masa, 1 salsa y 3 ingredientes distintos, Then puedo agregar la pizza al pedido.
- Given una pizza personalizada con menos de 3 ingredientes distintos, When intento agregarla, Then se bloquea con el mensaje "Elige al menos 3 ingredientes distintos".
- Given que no elegí masa o salsa, When intento agregar, Then se bloquea indicando lo que falta.
- Given que ya elegí una masa, When marco otra masa, Then la anterior se desmarca (exactamente una).

### US-05 Repetir porciones (triple queso) [M] (RF-10)

Como cliente quiero repetir un ingrediente para hacer, por ejemplo, triple queso.

- Given un ingrediente marcado, When ajusto la cantidad a 3, Then se acepta.
- Given cantidad 3, When intento subir a 4, Then no se permite y se informa "Máximo 3 porciones por ingrediente".

### US-06 Respetar stock [M] (RF-12)

Como cliente quiero que no me dejen pedir lo que no hay para evitar rechazos.

- Given un ingrediente con stock 2, When intento seleccionar 3 porciones, Then el máximo seleccionable es 2 y se informa el stock disponible.
- Given un ingrediente con stock 0, When veo la lista, Then aparece deshabilitado.

### US-07 Calorías y precio en vivo [M] (RF-13, RF-15)

Como cliente quiero ver calorías y precio mientras armo para decidir.

- Given una pizza en armado, When cambio tamaño, ingrediente o cantidad, Then calorías totales y precio se actualizan de inmediato según los valores del tamaño elegido.
- Given tamaño Mediana, masa 2,00, salsa 1,00 y queso 1,50 × 3, When calculo, Then el precio es 7,50 sin IVA.

### US-08 Personalizar predefinida solo agregando [M] (RF-14)

Como cliente quiero añadir ingredientes a una predefinida para adaptarla.

- Given una predefinida seleccionada, When la personalizo, Then los ingredientes de la receta aparecen marcados y no se pueden quitar ni reducir.
- Given una receta con 2 porciones de queso, When agrego más, Then solo puedo añadir 1 porción adicional (total 3).
- Given una predefinida con menos de 3 ingredientes distintos (p. ej. Margarita), When la agrego al pedido tal cual o con adiciones, Then se acepta sin exigir el mínimo de 3 ingredientes.

### US-09 Pedido con varias pizzas [M] (RF-17)

Como cliente quiero agregar varias pizzas, cada una con cantidad, para pedir para todos.

- Given pizzas agregadas, When veo el resumen, Then listo cada pizza con su cantidad, calorías y precio, y puedo cambiar cantidades o eliminarlas antes de confirmar.
- Given una línea con 20 pizzas, When intento subir a 21, Then no se permite y se informa "Máximo 20 pizzas por línea".

### US-10 IVA desglosado [M] (RF-16)

Como cliente quiero ver el IVA desglosado para entender el total.

- Given una pizza con componentes 15 % y 0 %, When veo el resumen, Then se muestran Subtotal 15 %, Subtotal 0 %, IVA 15 % y Total = subtotales + IVA.
- Given subtotal 15 % = 10,00 y subtotal 0 % = 2,00, When calculo, Then IVA 15 % = 1,50 y Total = 13,50.
- Given subtotal 15 % = 0,35, When calculo el IVA, Then 0,0525 se redondea half-up a 0,05 (calculado sobre el subtotal, no por línea).
- Given subtotal 15 % = 0,30, When calculo el IVA, Then 0,045 se redondea half-up a 0,05.

### US-11 Confirmar pedido y descuento de stock [M] (RF-18, RF-19, RF-20)

Como cliente quiero confirmar mi pedido para que el local lo prepare.

- Given un pedido válido con stock suficiente, When confirmo, Then se crea con estado Pendiente, número `GP-AAAAMMDD-0001` (fecha en la zona horaria del servidor), el stock se descuenta (1 por porción; masa y salsa 1 por pizza) y se guardan snapshots de precios, calorías e IVA.
- Given stock insuficiente en algún ingrediente al confirmar, When confirmo, Then el pedido se rechaza con mensaje claro (ingrediente y disponibilidad) y ningún stock cambia.
- Given dos clientes confirmando simultáneamente el último stock, When ambos confirman, Then solo uno tiene éxito.

### US-12 Orden/comprobante en pantalla [M] (RF-24, RF-25)

Como cliente quiero ver la orden final para verificar mi compra.

- Given un pedido confirmado, When abro su orden, Then veo en pantalla logo y "Good Pizza", número y fecha; mis datos; por pizza tamaño, masa, salsa, ingredientes con cantidad, calorías y precio; calorías totales, Subtotal 15 %, Subtotal 0 %, IVA 15 %, TOTAL en USD y estado actual.
- Given la orden en pantalla, When busco opciones de exportar o imprimir, Then no existen (fuera de alcance).

### US-13 Mis pedidos y estado [M] (RF-22, RF-21)

Como cliente quiero consultar el estado e historial de mis pedidos para saber cuándo recogerlos.

- Given que tengo pedidos, When abro "Mis pedidos", Then veo solo los míos con número, fecha, total y estado.
- Given un pedido de otro cliente, When intento acceder por su identificador, Then recibo acceso denegado/no encontrado.
- Given que el admin cambió el estado, When refresco, Then veo el nuevo estado.
- Given un pedido Pendiente mío, When busco cancelarlo, Then no existe la opción, y un intento por API es rechazado (no hay cancelación ni devolución de stock).

### US-14 Pedidos antiguos inmutables [M] (RF-19)

Como cliente quiero que mis pedidos pasados no cambien si cambian los precios.

- Given un pedido confirmado, When el admin modifica precio, calorías o IVA de un ingrediente, Then la orden del pedido muestra los valores originales.

## Administrador

### US-15 CRUD de ingredientes [M] (RF-04, RF-29)

Como administrador quiero crear, editar y desactivar ingredientes para mantener el catálogo.

- Given datos válidos con código único, When creo un ingrediente, Then aparece en el catálogo con IVA 15 % por defecto.
- Given un código existente, When intento crear, Then se rechaza por duplicado.
- Given un ingrediente existente, When quiero retirarlo, Then solo puedo desactivarlo (no hay borrado), deja de ofrecerse al cliente y el histórico se conserva.

### US-16 Precios y calorías por tamaño [M] (RF-05)

Como administrador quiero fijar calorías y precio por tamaño de cada ingrediente para reflejar costos reales.

- Given un ingrediente, When defino valores para Individual, Mediana y Familiar, Then se guardan de forma independiente.
- Given que falta algún tamaño, When intento activar el ingrediente, Then se rechaza indicando los tamaños faltantes.
- Given un precio negativo, When guardo, Then se rechaza.

### US-17 Cambiar precio y stock [M] (RF-06)

Como administrador quiero cambiar precio y stock de un ingrediente para ajustarlos.

- Given un ingrediente, When modifico precio y stock, Then los nuevos pedidos usan los nuevos valores.
- Given un stock negativo, When guardo, Then se rechaza.

### US-18 Tarifa de IVA por ingrediente [M] (RF-04, RF-16)

Como administrador quiero asignar 15 % o 0 % a cada ingrediente.

- Given un ingrediente, When elijo 0 %, Then sus componentes se acumulan en Subtotal 0 % en nuevos pedidos.
- Given un valor distinto de 15 % o 0 %, When guardo, Then se rechaza.

### US-19 Gestionar pizzas predefinidas [M] (RF-07)

Como administrador quiero administrar las recetas de las predefinidas.

- Given la pantalla de predefinidas, When edito la receta de Pepperoni, Then el cambio afecta a nuevos pedidos y no a los anteriores.
- Given una receta con más de 3 porciones de un ingrediente, When guardo, Then se rechaza.
- Given una receta con menos de 3 ingredientes distintos, When guardo, Then se acepta (el mínimo solo rige para personalizadas).
- Given una predefinida, When la veo, Then su precio se muestra calculado por fórmula y no hay campo de precio fijo.

### US-20 Gestionar pedidos y estados [M] (RF-21, RF-23)

Como administrador quiero ver todos los pedidos y avanzar su estado hasta Entregado.

- Given un pedido Pendiente, When lo paso a En preparación y luego a Entregado, Then el estado se actualiza y el cliente lo ve.
- Given un pedido Entregado, When intento retroceder o saltar estados, Then se rechaza.
- Given un cliente, When intenta cambiar un estado, Then recibe acceso denegado (403).

## Sistema

### US-21 Datos de ejemplo [M] (RF-26)

Como administrador quiero datos iniciales para probar el sistema.

- Given una base migrada, When ejecuto el seed, Then existen 1 admin, 1 cliente, ~20 ingredientes y 5 predefinidas.
- Given que `SEED_*_PASSWORD` no están definidas, When ejecuto el seed, Then se generan contraseñas aleatorias impresas una sola vez y nunca guardadas en el código.

### US-22 Autorización por rol [M] (RF-03)

Como propietario quiero que cada rol solo acceda a lo suyo.

- Given un cliente, When llama a un endpoint de administración de ingredientes, Then recibe 403.
- Given una petición sin token, When llama a un endpoint protegido, Then recibe 401.

### US-23 Health [S] (RF-27)

Como operador quiero consultar `/api/v1/health` para verificar que el servicio responde.

- Given el backend en ejecución, When consulto `/api/v1/health`, Then responde 200 con estado OK.
