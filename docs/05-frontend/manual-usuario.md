# Manual de usuario — Fase 5 (Frontend)

## 1. Introducción

Good Pizza es la aplicación de escritorio de la pizzería. El **cliente** se registra, elige una pizza predefinida o arma la suya, la agrega al pedido y consulta el estado de sus pedidos. El **administrador** parametriza el sistema (ingredientes, precios, calorías, IVA y stock, pizzas predefinidas) y cambia el estado de los pedidos. Todo el consumo es en el local: no hay delivery ni pago en línea; solo se registra el pedido. Los precios están en dólares (USD) y no incluyen IVA hasta el resumen del pedido.

## 2. Requisitos

- Windows 10/11 de 64 bits.
- El servicio (backend) de la pizzería en ejecución y accesible desde el equipo.
- Pantalla de al menos 1024 x 680 (recomendado 1280 x 800). No hay versión móvil.

## 3. Acceso al sistema

**Crear cuenta (cliente).** En la pantalla de inicio de sesión pulsa "Crear cuenta". Escribe nombre completo (mínimo 2 caracteres), email, contraseña (mínimo 8 caracteres) y repítela. Al crear la cuenta la sesión se inicia sola y llegas a "Pizzas predefinidas". Las cuentas de administrador las crea el local, no se pueden crear desde la aplicación.

**Iniciar sesión.** Escribe email y contraseña y pulsa "Iniciar sesión" (o Enter). El icono del ojo muestra u oculta la contraseña. El cliente entra a "Pizzas predefinidas"; el administrador, a "Ingredientes".

**Cerrar sesión.** "Cerrar sesión" en el menú lateral (o `Ctrl+Shift+Q`). Si tienes pizzas sin confirmar en el pedido, se te avisa de que se perderán.

## 4. Guía por funcionalidad

### 4.1 Cliente: pizzas predefinidas

**Objetivo:** ver las recetas con precio y calorías por tamaño.
**Pasos:** 1. Elige el tamaño (Individual, Mediana o Familiar): los precios cambian al instante. 2. Pulsa "Agregar al pedido" para añadir la pizza tal cual, o "Personalizar" para agregarle ingredientes.
**Resultado:** aparece "Pizza agregada" con el acceso "Ver pedido". Si agregas la misma pizza y tamaño otra vez, se suma la cantidad (hasta 20). Una pizza "No disponible" muestra el motivo (por ejemplo, "falta Piña") y no se puede pedir. Las predefinidas solo permiten agregar ingredientes, no quitarlos.

### 4.2 Cliente: personalizar pizza

**Objetivo:** armar tu pizza con casillas y ver calorías y precio en vivo.
**Pasos:** 1. Elige el tamaño. 2. Marca **una** masa. 3. Marca **una** salsa base. 4. Marca los ingredientes que quieras y, en cada uno, elige 1 a 3 porciones (por ejemplo, triple queso = 3 porciones de mozzarella). Debes elegir al menos 3 ingredientes distintos (en pizzas armadas desde cero). 5. Revisa el panel "Tu pizza": calorías totales y precio (sin IVA). 6. Elige la cantidad de pizzas y pulsa "Agregar al pedido" (`Ctrl+Enter`).
**Notas:** cada ingrediente muestra su stock; no puedes pedir más porciones que el stock ("Stock disponible: N") ni más de 3 ("Máximo 3 porciones por ingrediente"). Un ingrediente agotado aparece como "Agotado". Mientras falte algo, el panel explica qué ("Elige una masa.", "Elige al menos 3 ingredientes distintos.") y el botón está deshabilitado. Si personalizas una predefinida, la masa, la salsa y los ingredientes de la receta están marcados y bloqueados: solo puedes agregar porciones o ingredientes.

### 4.3 Cliente: resumen del pedido

**Objetivo:** revisar y confirmar.
**Pasos:** 1. Ajusta la cantidad de cada línea (1 a 20) o quítala con el icono de papelera (puedes "Deshacer"). 2. Revisa Calorías totales, Subtotal 15 %, Subtotal 0 %, IVA 15 % y TOTAL (USD). 3. Pulsa "Confirmar pedido" (`Ctrl+Enter`) y acepta el diálogo.
**Resultado:** se muestra el comprobante con el número `GP-AAAAMMDD-0001` y el estado "Pendiente". El stock se descuenta; **los pedidos no se pueden cancelar desde la aplicación**.
**Si algo cambia:** "Stock insuficiente" lista qué ingrediente falta (pulsa "Ajustar pedido"); "El precio cambió" muestra el total nuevo (puedes "Revisar pedido" o "Aceptar y confirmar").

### 4.4 Cliente: mis pedidos y comprobante

**Objetivo:** ver el estado y el historial de tus pedidos.
**Pasos:** abre "Mis pedidos"; filtra por estado con los botones (Todos, Pendiente, En preparación, Entregado); haz clic en una fila para abrir el comprobante. El estado **no se actualiza solo**: pulsa "Actualizar" o `F5`.
**Comprobante:** encabezado con logotipo, número y fecha; tus datos; por cada pizza el tamaño, masa, salsa y la tabla de ingredientes con cantidad, calorías y precio; el resumen con calorías totales, subtotales, IVA y TOTAL; el estado actual con su línea de tiempo. Es solo para ver en pantalla (no hay imprimir ni exportar; puedes seleccionar y copiar el texto). Los pedidos antiguos conservan sus precios aunque el administrador los cambie.

### 4.5 Administrador: ingredientes

**Objetivo:** mantener el catálogo.
**Pasos:** 1. En "Ingredientes" busca por código o nombre, filtra por categoría y usa "Mostrar inactivos". 2. "Nuevo ingrediente" (`Ctrl+N`): código, nombre, categoría, tarifa de IVA (15 % por defecto o 0 %), stock inicial y, **para cada tamaño**, precio (USD, sin IVA, máximo 2 decimales) y calorías; guarda con `Ctrl+S`. 3. En un ingrediente existente: editar con el lápiz o la fila; "Ajustar stock" (clic en la cifra) permite fijar un valor o sumar/restar.
**Notas:** los ingredientes **no se eliminan**: se desactivan con el interruptor (se pide confirmación; dejan de ofrecerse y las predefinidas que los usan quedan no disponibles). Los cambios de precio, calorías e IVA aplican a pedidos nuevos.

### 4.6 Administrador: pizzas predefinidas

**Objetivo:** definir las recetas.
**Pasos:** "Nueva pizza" (`Ctrl+N`): código, nombre, orden, descripción, **una** masa, **una** salsa y los ingredientes con 1 a 3 porciones (pueden ser menos de 3 ingredientes). No hay campo de precio: la "Vista previa" muestra el precio y las calorías calculados por tamaño. Los cambios de receta solo afectan a pedidos nuevos.

### 4.7 Administrador: pedidos

**Objetivo:** hacer avanzar el estado de los pedidos.
**Pasos:** en "Pedidos" filtra por estado, fechas o busca por número de orden o email; abre un pedido; pulsa "Pasar a En preparación" y luego "Marcar como Entregado" (`Ctrl+Enter`), confirmando cada vez. No se puede retroceder, saltar ni cancelar.

## 5. Mensajes de error frecuentes

| Mensaje                                                                                               | Causa                                                          | Solución                               |
| ----------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- | -------------------------------------- |
| No se pudo conectar con el servidor. Verifica que el servicio esté en ejecución e inténtalo de nuevo. | El servicio de la pizzería está apagado o la dirección es otra | Avisar al local; pulsar "Reintentar"   |
| Email o contraseña incorrectos.                                                                       | Datos de acceso erróneos (no se indica cuál)                   | Corregir y reintentar                  |
| Tu cuenta está desactivada. Consulta con el local.                                                    | Usuario desactivado                                            | Hablar con el local                    |
| Demasiados intentos / Demasiadas solicitudes.                                                         | Límite de peticiones                                           | Esperar unos minutos                   |
| Este email ya está registrado.                                                                        | Ya existe una cuenta con ese email                             | Iniciar sesión                         |
| Elige al menos 3 ingredientes distintos.                                                              | Pizza armada con menos de 3 ingredientes                       | Marcar más ingredientes                |
| Máximo 3 porciones por ingrediente / Stock disponible: N                                              | Límite de porciones o de stock                                 | Reducir las porciones                  |
| No hay stock suficiente de X: solicitado N, disponible M.                                             | Otro pedido consumió el stock                                  | "Ajustar pedido" y reducir la cantidad |
| El precio cambió. El total ahora es $ X (antes $ Y).                                                  | El administrador cambió un precio                              | Revisar y aceptar                      |
| El ajuste dejaría el stock por debajo de 0.                                                           | Se intentó restar más stock del existente                      | Usar "Fijar valor" o restar menos      |
| El pedido ya cambió de estado.                                                                        | Otro administrador lo cambió                                   | Pulsar "Actualizar"                    |
| Tu sesión expiró. Inicia sesión de nuevo.                                                             | La sesión caducó                                               | Volver a iniciar sesión                |

## 6. Preguntas frecuentes

- **¿Puedo cancelar un pedido?** No desde la aplicación; consulta con el local.
- **¿Puedo quitar un ingrediente de una pizza predefinida?** No, solo agregar.
- **¿Por qué mi pedido no cambia de estado?** El estado se actualiza al pulsar "Actualizar" o `F5`.
- **¿Se pueden imprimir los comprobantes?** No; el comprobante es solo informativo en pantalla ("No es una factura electrónica").
- **Atajos:** `F1` muestra la lista completa.

## 7. Soporte

Contactar al administrador del local. Para incidencias técnicas, ver `docs/05-frontend/README.md` (solución de problemas).
