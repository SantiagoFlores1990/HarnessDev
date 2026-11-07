# Manual de usuario — Good Pizza

- **Versión:** 0.1.0 · **Fecha:** 2026-11-06 · **Idioma:** español · **Moneda:** USD (2 decimales)
- **Destinatarios:** **clientes** que piden en el local y **administradores** que gestionan el catálogo y los pedidos.
- **Base del manual:** las pantallas implementadas en `frontend/lib/features` y las rutas de `frontend/lib/core/router/app_router.dart`. Los textos de los mensajes y los atajos se verificaron en el código. Los detalles de presentación siguen `docs/03-design/screens.md`.

> **Datos de ejemplo.** Los ingredientes, precios, calorías, stock e impuestos que aparecen en este manual son de ejemplo. No son precios reales. Revísalos antes de operar.

---

## 1. Introducción

Good Pizza es la aplicación de escritorio de la pizzería para Windows. Permite:

- **Al cliente:** registrarse, elegir una pizza predefinida o armar una a su gusto, ver en vivo las calorías y el precio, revisar el pedido con el IVA desglosado, confirmarlo y consultar el estado de sus pedidos.
- **Al administrador:** mantener los ingredientes (precios, calorías, IVA, stock), las pizzas predefinidas y el estado de los pedidos.

El consumo es **en el local**. No hay entrega a domicilio ni pago en línea: el pedido se registra y el personal lo prepara. **No se puede cancelar un pedido** desde la aplicación, y el stock descontado no se devuelve.

## 2. Requisitos

- Windows 10 u 11 de 64 bits.
- La aplicación debe estar conectada a la API del local. Si aparece "No se pudo conectar con el servidor. Verifica que el servicio esté en ejecución", avisa al responsable técnico (ver la sección 9).
- Una cuenta: los clientes se registran desde la aplicación; las cuentas de administrador las crea el responsable técnico.

## 3. Acceso al sistema

### 3.1 Iniciar sesión (todos los usuarios)

1. Abre **Good Pizza**. Aparece la pantalla **Iniciar sesión** con el logotipo.
2. Escribe tu **Email** y tu **Contraseña**. Para ver la contraseña, pulsa el icono del ojo.
3. Pulsa **Iniciar sesión** (o la tecla `Enter`).
4. Según tu rol, entrarás a:
   - **Cliente:** Pizzas predefinidas.
   - **Administrador:** Ingredientes.

Si el email o la contraseña no son correctos, el mensaje es **"Email o contraseña incorrectos."** (es el mismo para ambos casos, por seguridad). Si olvidas la contraseña, no hay recuperación por correo: pide ayuda al responsable técnico.

### 3.2 Crear cuenta (cliente)

1. En la pantalla de inicio de sesión, pulsa **Crear cuenta**.
2. Completa **Nombre completo** (2 a 120 caracteres), **Email** y **Contraseña** (mínimo 8 caracteres). Repite la contraseña en **Repetir contraseña**.
3. Pulsa **Crear cuenta**.
4. La cuenta queda creada con rol **Cliente** y la sesión se inicia sola. Verás "¡Bienvenido, <nombre>!".

Reglas de validación: el email debe tener formato válido; las dos contraseñas deben coincidir. Si el email ya existe, aparece **"Este email ya está registrado."**, con el enlace **Iniciar sesión**.

### 3.3 Cerrar sesión

- Pulsa **Cerrar sesión** en la parte inferior del menú lateral, o usa `Ctrl+Shift+Q`.
- Confirma en el diálogo. **En un equipo compartido, cierra siempre la sesión al terminar.**

### 3.4 Menú y navegación

La aplicación tiene un menú lateral (NavigationRail). Las opciones dependen del rol:

| Rol           | Opciones del menú                                                                                                       |
| ------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Cliente       | **Pizzas predefinidas**, **Personalizar pizza**, **Mi pedido** (con el número de pizzas en el carrito), **Mis pedidos** |
| Administrador | **Ingredientes**, **Pizzas predefinidas**, **Pedidos**                                                                  |

Para volver a la pantalla anterior usa **Alt+←**. Para actualizar una lista, usa **F5** o **Ctrl+R**.

## 4. Guía del cliente

### 4.1 Ver pizzas predefinidas

**Objetivo:** ver las cinco pizzas de la carta con su precio y calorías.

**Pasos:**

1. En el menú, elige **Pizzas predefinidas**. Es la pantalla de inicio del cliente.
2. Elige el tamaño con los botones **Individual**, **Mediana** o **Familiar** (por defecto, **Mediana**). Los precios y las calorías de todas las tarjetas cambian al instante.
3. Revisa cada tarjeta: nombre, descripción, receta (masa, salsa e ingredientes con sus porciones), **precio sin IVA** y **kcal**.
4. Si la pizza tiene **Disponible**, puedes usarla. Si aparece **No disponible**, el texto indica el motivo (por ejemplo, "falta Piña" porque se acabó el stock). Esos botones están deshabilitados.

**Acciones de la tarjeta:**

- **Agregar al pedido:** añade la pizza tal como está, con cantidad 1. Aparece el aviso "Pizza agregada" con el botón **Ver pedido**. Si ya tenías esa misma pizza en el pedido (mismo tamaño y sin extras), se suma la cantidad (hasta 20).
- **Personalizar:** abre **Personalizar pizza** con esa receta para añadir ingredientes (ver 4.3).

**Resultado:** la pizza queda en **Mi pedido**. Recuerda: las pizzas predefinidas solo permiten **agregar** ingredientes, no quitarlos.

### 4.2 Armar una pizza desde cero

**Objetivo:** crear una pizza con tus ingredientes.

**Pasos:**

1. En el menú, elige **Personalizar pizza**.
2. **Tamaño:** elige **Individual**, **Mediana** o **Familiar**. El tamaño cambia el precio y las calorías de cada ingrediente, porque cada tamaño tiene su propio valor.
3. **Masa (elige 1):** marca una masa. Solo puede haber una: al marcar otra, se desmarca la anterior.
4. **Salsa base (elige 1):** marca una salsa. Igual que la masa, solo puede haber una.
5. **Ingredientes:** agrupados por categoría (Queso, Carne, Vegetal, Otros). Marca la casilla de cada ingrediente que quieras.
   - Al marcarlo aparece el selector de **porciones**, con valor inicial 1. Puedes subir hasta **3 porciones** por ingrediente (por ejemplo, **triple queso** = 3 porciones de queso mozzarella).
   - Cada ingrediente muestra su **Stock** y su precio y calorías por porción en el tamaño elegido.
   - Un ingrediente con **Agotado** no se puede marcar.
6. Revisa el panel **TU PIZZA**: resume tus elecciones y muestra **Calorías totales** y **Precio de la pizza** (sin IVA). Se actualiza en vivo al cambiar cualquier dato (muestra "Calculando…" mientras se recalcula).
7. **Cantidad de pizzas:** elige cuántas pizzas iguales quieres (de 1 a 20).
8. Si el aviso indica "Elige al menos 3 ingredientes distintos", añade ingredientes hasta llegar a 3. **Esta regla solo aplica a pizzas armadas desde cero**; las predefinidas no la necesitan.
9. Pulsa **Agregar al pedido** (o `Ctrl+Enter`). Cuando el botón está deshabilitado, el texto de debajo indica el motivo.

**Reglas que se aplican siempre:**

- Exactamente **1 masa** y **1 salsa**.
- **Máximo 3 porciones** por ingrediente.
- **Mínimo 3 ingredientes distintos** además de la masa y la salsa (solo en pizzas armadas desde cero).
- **No se pueden pedir más porciones que el stock disponible.**
- La masa y la salsa no se agregan como ingredientes extra.

**Resultado:** la pizza se agrega a **Mi pedido** y el armado vuelve a empezar.

### 4.3 Personalizar una pizza predefinida

**Objetivo:** añadir ingredientes a una pizza de la carta.

**Pasos:**

1. Desde una tarjeta de **Pizzas predefinidas**, pulsa **Personalizar**. Se abre el armado con el aviso "Personalizando <nombre>. Puedes agregar ingredientes o porciones, pero no quitar los de la receta."
2. La masa y la salsa de la receta aparecen marcadas y bloqueadas (**Parte de la receta**). No se pueden cambiar.
3. Los ingredientes de la receta aparecen marcados y **no se pueden quitar**. Puedes subir sus porciones, pero no bajar de las que trae la receta.
4. Marca nuevos ingredientes para agregarlos como extras.
5. Ajusta el tamaño si quieres; el precio se recalcula.
6. Pulsa **Agregar al pedido**.

### 4.4 Revisar el pedido y confirmarlo

**Objetivo:** revisar las pizzas, el total con IVA y confirmar.

**Pasos:**

1. Abre **Mi pedido**.
2. Cada pizza aparece como tarjeta con su título ("Pizza 1 · Personalizada · Mediana" o "Pizza 2 · Margarita · Familiar"), la lista de componentes, el precio y las calorías por pizza, y el subtotal de la línea.
3. Para cambiar la cantidad de una pizza, usa el selector **- / +** (de 1 a 20). Para quitarla, usa el icono de papelera (**Quitar del pedido**); aparece **Deshacer**.
4. El panel **RESUMEN** muestra:
   - **Calorías totales**.
   - **Subtotal 15 %**: parte del pedido gravada con IVA 15 %.
   - **Subtotal 0 %**: parte del pedido con IVA 0 %.
   - **IVA 15 %**: el impuesto calculado sobre el subtotal 15 %.
   - **TOTAL (USD)** = subtotal 15 % + subtotal 0 % + IVA 15 %.
     Los precios de las pizzas se muestran sin IVA; el IVA aparece solo en este resumen y en el comprobante.
5. Pulsa **Confirmar pedido** (o `Ctrl+Enter`).
6. En el diálogo de confirmación, revisa el total y pulsa **Confirmar**. Al confirmar, **el stock se reserva y el pedido no se puede cancelar**.
7. Si todo va bien, se abre el **comprobante** del pedido con el aviso "Pedido GP-… confirmado. Estado: Pendiente."

**Si algo impide confirmar:**

- **"Stock insuficiente"**: aparece la lista de ingredientes con lo solicitado y lo disponible. Pulsa **Ajustar pedido** y reduce cantidades o cambia ingredientes.
- **"El precio cambió"**: el total cambió desde que revisaste el pedido. Pulsa **Revisar pedido** para ver el nuevo total, o **Aceptar y confirmar**.
- **Aviso de reglas de armado**: una pizza no cumple una regla. Corrígela en el armado.
- **"Tu cuenta no puede crear pedidos."**: tu rol no permite pedir. Consulta con el local.

Si se pierde la conexión al confirmar, el carrito se conserva. Vuelve a intentarlo cuando la aplicación esté conectada.

### 4.5 Consultar mis pedidos

**Objetivo:** ver el estado y el historial de tus pedidos.

**Pasos:**

1. Abre **Mis pedidos**. Se listan tus pedidos, del más reciente al más antiguo.
2. Cada fila muestra el **Nº de orden** (`GP-AAAAMMDD-NNNN`), la fecha, el número de pizzas, el total y el **estado**.
3. Para filtrar, usa los botones **Todos**, **Pendiente**, **En preparación** o **Entregado**.
4. Pulsa una fila (o `Enter`) para abrir el comprobante.
5. Para ver cambios de estado hechos por el personal, pulsa **Actualizar** o `F5`. La aplicación **no se actualiza sola**.

**Estados:** **Pendiente** → **En preparación** → **Entregado**. Un pedido no puede volver atrás ni cancelarse desde la aplicación.

### 4.6 Leer el comprobante (orden)

El comprobante contiene, en este orden:

1. **Encabezado:** logotipo y "Good Pizza", número de orden y fecha y hora.
2. **Cliente:** nombre y email.
3. **Por cada pizza:** título ("PIZZA N · Personalizada" o "PIZZA N · <nombre> (predefinida)"), cantidad, tamaño, masa, salsa y una tabla con ingrediente, cantidad (porciones), calorías y precio. En predefinidas con extras aparece "(R receta + E extra)".
4. **Resumen:** Calorías totales, Subtotal 15 %, Subtotal 0 %, IVA 15 % y **TOTAL (USD)**.
5. **Estado actual:** el estado, la fecha del último cambio y una línea de tiempo de tres pasos.
6. Pie: "Documento informativo del pedido. No es una factura electrónica."

El comprobante **solo se muestra en pantalla**. No hay opciones de imprimir, exportar a PDF ni compartir. El texto se puede seleccionar y copiar.

Si el pedido no es tuyo o no existe, aparece **"No encontramos este pedido."** Puedes volver a **Mis pedidos**.

## 5. Guía del administrador

### 5.1 Gestionar ingredientes

**Objetivo:** consultar y cambiar ingredientes, precios, calorías, IVA y stock.

**Ver la lista** (menú **Ingredientes**):

- Columnas: código, nombre, categoría, IVA, stock, precio y kcal por tamaño (Individual, Mediana, Familiar), activo.
- **Buscar:** escribe código o nombre (o `Ctrl+F`).
- **Categoría:** filtra por Masa, Salsa, Queso, Carne, Vegetal u Otros.
- **Mostrar inactivos:** la casilla viene **marcada** por defecto, así que ves también los ingredientes desactivados. Desmárcala para ocultarlos.
- Un ingrediente con stock 0 muestra el aviso **Agotado**.

**Crear un ingrediente:**

1. Pulsa **Nuevo ingrediente** (o `Ctrl+N`).
2. Completa: **Código** (2 a 20 caracteres: letras mayúsculas, números y guion; se guarda en mayúsculas), **Nombre** (2 a 80), **Categoría**, **Tarifa de IVA** (**15 %** por defecto, o **0 %**) y **Stock inicial** (entero, 0 o más).
3. En **Valores por tamaño** introduce, para **cada uno de los tres tamaños**, el **precio por porción** (en USD, sin IVA, máximo 2 decimales) y las **calorías por porción** (entero, 0 o más). Cada tamaño tiene su propio valor.
4. Pulsa **Guardar ingrediente** (o `Ctrl+S`).

**Editar un ingrediente:** pulsa la fila o el icono de lápiz. Puedes cambiar nombre, IVA y los valores por tamaño. El stock y el estado se cambian con sus propios botones (Ajustar stock y el interruptor Activo). **La categoría no se puede cambiar** si el ingrediente se usa en una pizza predefinida: la aplicación indica cuáles.

> Los cambios de precio, calorías e IVA aplican a los **pedidos nuevos**. Los pedidos anteriores conservan sus valores.

**Ajustar el stock:**

1. Pulsa **Ajustar stock** en el formulario o el número de stock de la lista.
2. Elige **Fijar valor** (pone el stock exacto, 0 o más) o **Sumar o restar** (suma un número, positivo o negativo).
3. Revisa la **vista previa** "Nuevo stock" y pulsa **Guardar**.
4. Si el ajuste dejaría el stock por debajo de 0, la aplicación muestra **"El ajuste dejaría el stock por debajo de 0."**

**Activar o desactivar un ingrediente:**

- Usa el interruptor **Activo** de la lista o del formulario.
- Al **desactivar**, confirma el diálogo. El ingrediente deja de ofrecerse a los clientes, las predefinidas que lo usan quedan no disponibles, y los pedidos anteriores no cambian.
- Al **activar**, el sistema exige precio y calorías de los **tres tamaños**. Si falta alguno: "No se puede activar: faltan precio y calorías de algún tamaño."

> **No existe "Eliminar".** Los ingredientes solo se desactivan.

### 5.2 Gestionar pizzas predefinidas

**Objetivo:** mantener la carta de pizzas.

**Ver la lista** (menú **Pizzas predefinidas**): orden, nombre, código, receta resumida, precio y kcal por tamaño (calculados a partir de la receta; no hay precio fijo), disponibilidad y el interruptor **Activa**. La casilla **Mostrar inactivas** viene marcada por defecto.

**Crear o editar una pizza:**

1. Pulsa **Nueva pizza** (o `Ctrl+N`) o abre una existente.
2. **Datos:** **Código** (2 a 30 caracteres, mayúsculas y guion bajo), **Nombre** (2 a 80), **Descripción** (hasta 300) y **Orden**.
3. **Receta:** elige una **Masa** y una **Salsa** (cada una, porción fija 1). Marca los **Ingredientes** que quieras y ajusta sus porciones de 1 a 3. Una predefinida puede tener menos de 3 ingredientes.
4. **Vista previa:** muestra el precio sin IVA y las kcal para los tres tamaños. Se calcula con el mismo motor que usa la venta.
5. Pulsa **Guardar pizza** (o `Ctrl+S`).

**Errores habituales:**

- "Ya existe una pizza con ese código." / "Ya existe una pizza con ese nombre."
- Receta inválida: por ejemplo, "Elige una masa." o "Máximo 3 porciones por ingrediente."

> Los cambios de receta afectan solo a pedidos nuevos. Para retirar una pizza de la carta, desactívala con el interruptor **Activa**; no se borra.

### 5.3 Gestionar pedidos

**Objetivo:** seguir los pedidos y avanzar su estado hasta **Entregado**.

**Pasos:**

1. Abre **Pedidos**. Se listan todos los pedidos, del más reciente al más antiguo.
2. Filtra por **estado**, por fechas (**Desde**, **Hasta**) o busca por **Nº de orden** o email.
3. Pulsa una fila (o `Enter`) para abrir el detalle.
4. En el detalle verás el comprobante completo (sección 4.6) y el panel **GESTIÓN DEL ESTADO**:
   - Si está **Pendiente**: botón **Pasar a En preparación**.
   - Si está **En preparación**: botón **Marcar como Entregado**.
   - Si está **Entregado**: "Este pedido ya fue entregado. No admite más cambios."
5. Confirma en el diálogo. **El cambio no se puede deshacer.**
6. En el **Historial** verás cada estado, la fecha y el nombre de quien lo cambió.

**Reglas:**

- Los estados solo avanzan en este orden: Pendiente → En preparación → Entregado.
- No hay retroceso, cancelación ni devolución de stock.
- Si otra persona cambió el estado antes que tú, aparece **"El pedido ya cambió de estado"**. Pulsa **Actualizar** y revisa el estado.

## 6. Mensajes de error frecuentes

| Mensaje                                                                            | Causa                                    | Qué hacer                                                                  |
| ---------------------------------------------------------------------------------- | ---------------------------------------- | -------------------------------------------------------------------------- |
| "Email o contraseña incorrectos."                                                  | Credenciales no válidas                  | Revisa el email y la contraseña. Si persiste, consulta con el responsable. |
| "Tu cuenta está desactivada. Consulta con el local."                               | La cuenta fue desactivada                | Consulta con el local.                                                     |
| "Demasiados intentos. Espera unos minutos e inténtalo de nuevo."                   | Límite de intentos superado              | Espera unos minutos.                                                       |
| "Tu sesión expiró. Inicia sesión de nuevo."                                        | Caducó la sesión                         | Inicia sesión otra vez.                                                    |
| "No se pudo conectar con el servidor. Verifica que el servicio esté en ejecución." | La API no está disponible                | Avisa al responsable técnico.                                              |
| "Ya existe un ingrediente con ese código."                                         | Código repetido                          | Usa otro código.                                                           |
| "Este email ya está registrado."                                                   | El email ya tiene cuenta                 | Inicia sesión.                                                             |
| "No hay stock suficiente de <ingrediente>: solicitado N, disponible M."            | Stock insuficiente                       | Reduce la cantidad o cambia el ingrediente.                                |
| "Elige al menos 3 ingredientes distintos."                                         | Pizza armada con menos de 3 ingredientes | Añade ingredientes (no aplica a predefinidas).                             |
| "Máximo 3 porciones por ingrediente."                                              | Se superó el límite de porciones         | Baja las porciones.                                                        |
| "Máximo 20 pizzas por línea."                                                      | Cantidad superior a 20                   | Usa otra línea o baja la cantidad.                                         |
| "El precio cambió."                                                                | El total cambió antes de confirmar       | Revisa el nuevo total y acepta.                                            |
| "El pedido ya cambió de estado."                                                   | Otro usuario cambió el estado            | Pulsa Actualizar.                                                          |
| "No se pudo calcular el precio. Reintentar."                                       | Fallo al recalcular                      | Pulsa Reintentar.                                                          |
| "Tu cuenta no puede crear pedidos."                                                | Rol sin permiso de pedido                | Consulta con el local.                                                     |
| "No se pudo confirmar el pedido. Inténtalo de nuevo."                              | Error de red o del servidor              | El carrito se conserva. Reintenta.                                         |

## 7. Atajos de teclado

| Atajo               | Acción                                                                                                          |
| ------------------- | --------------------------------------------------------------------------------------------------------------- |
| `Ctrl+1` a `Ctrl+4` | Ir al destino del menú                                                                                          |
| `Alt+←`             | Volver                                                                                                          |
| `F5` o `Ctrl+R`     | Actualizar la pantalla                                                                                          |
| `F1`                | Mostrar la ayuda de atajos                                                                                      |
| `Ctrl+Shift+Q`      | Cerrar sesión                                                                                                   |
| `Esc`               | Cerrar diálogo o menú                                                                                           |
| `Tab` y `Mayús+Tab` | Mover el foco                                                                                                   |
| `Ctrl+Enter`        | Cliente: agregar pizza (Personalizar) o confirmar pedido (Resumen). Administrador: avanzar el estado del pedido |
| `Espacio`           | Marcar o desmarcar la casilla enfocada                                                                          |
| `↑` `↓` o `+` `−`   | Cambiar la cantidad con el selector enfocado                                                                    |
| `Ctrl+N`            | Administrador: nuevo ingrediente o nueva pizza                                                                  |
| `Ctrl+S`            | Administrador: guardar el formulario                                                                            |
| `Ctrl+F`            | Administrador: buscar en la lista                                                                               |

## 8. Preguntas frecuentes

**¿Puedo cancelar un pedido?**
No desde la aplicación. Consulta con el local. El stock de un pedido confirmado no se devuelve.

**¿Por qué no veo un ingrediente?**
Puede estar desactivado. Los clientes solo ven ingredientes activos. Los administradores lo ven con "Mostrar inactivos".

**¿Por qué el precio no tiene IVA?**
Los precios del catálogo y de la pizza son sin IVA. El IVA aparece en el resumen del pedido y en el comprobante: 15 % sobre el subtotal gravado al 15 %, y 0 % en el otro subtotal.

**¿Por qué no puedo marcar un ingrediente?**
Está agotado (stock 0) o ya has alcanzado el stock disponible o el máximo de 3 porciones.

**¿Por qué el estado de mi pedido no cambia?**
La aplicación no se actualiza sola. Pulsa **Actualizar** o `F5`.

**¿Puedo pedir a domicilio o pagar en la aplicación?**
No. La aplicación solo registra el pedido para consumo en el local.

**¿Puedo imprimir el comprobante?**
No desde la aplicación. Puedes seleccionar y copiar el texto.

**¿Por qué mi pedido aparece con la fecha de otro día?**
El número de orden y la fecha usan la zona horaria del equipo del servidor. Consulta con el responsable técnico.

**Estoy en un equipo compartido. ¿Qué debo hacer?**
Cierra la sesión (`Ctrl+Shift+Q`) al terminar. La aplicación puede mantener la sesión abierta en el equipo.

## 9. Soporte

- **Problemas de acceso o de cuenta:** consulta con el administrador del local.
- **La aplicación no conecta con el servidor, o hay errores técnicos:** avisa al responsable técnico. Indica la hora, la pantalla y el mensaje exacto. No compartas contraseñas.
- **Documentación técnica:** `docs/09-maintenance/runbook.md` (operación) y `docs/09-maintenance/backlog.md` (pendientes conocidos).

## 10. Limitaciones conocidas

- Solo Windows. No hay versión para móvil, web, Linux ni macOS.
- Sin modo oscuro.
- El estado del pedido se actualiza al pulsar **Actualizar** o `F5`.
- Sin cancelación ni devolución de stock.
- Sin impresión ni exportación del comprobante.
- Los datos de ejemplo del sistema no son precios reales.
