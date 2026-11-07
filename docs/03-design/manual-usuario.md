# Manual de usuario — Fase 3 (según el diseño)

> Describe lo que verá y podrá hacer cada usuario según el diseño de pantallas. Las capturas se agregarán cuando exista la aplicación (fase 5). Los importes y datos de ejemplo son ilustrativos.

## 1. Introducción

Good Pizza es la aplicación de la pizzería para pedir pizzas en el local. Los **clientes** eligen una pizza predefinida o arman la suya, confirman el pedido y consultan su estado. El **administrador** mantiene el catálogo (ingredientes, precios, calorías, IVA y stock), las pizzas predefinidas y el estado de los pedidos. Todo el consumo es en el local: no hay entrega a domicilio ni pago en línea; la aplicación solo registra el pedido.

## 2. Requisitos

- Equipo con **Windows**. La aplicación es de escritorio; no existe versión móvil ni web.
- Ventana recomendada de al menos 1024 × 680 píxeles (inicial 1280 × 800).
- El servicio del local debe estar en ejecución (la app se conecta a él).
- Teclado y ratón (también funciona con pantalla táctil de Windows como apoyo).

## 3. Acceso al sistema

### 3.1 Crear una cuenta (cliente)

1. En la pantalla de inicio de sesión pulsa **Crear cuenta**.
2. Escribe tu nombre completo, tu email y una contraseña de **al menos 8 caracteres**; repítela.
3. Pulsa **Crear cuenta**. Entras directamente a "Pizzas predefinidas".

Solo se pueden crear cuentas de cliente; la cuenta del administrador la prepara el local.

### 3.2 Iniciar sesión

1. Escribe tu email y contraseña y pulsa **Iniciar sesión** (o `Enter`).
2. El cliente llega a "Pizzas predefinidas"; el administrador, a "Ingredientes".
3. Para salir usa **Cerrar sesión** en la parte inferior del menú lateral (`Ctrl+Shift+Q`).

## 4. Guía por funcionalidad — Cliente

El menú lateral tiene: **Pizzas predefinidas**, **Personalizar pizza**, **Mi pedido** (con el número de pizzas) y **Mis pedidos**.

### 4.1 Ver pizzas predefinidas

**Objetivo:** elegir rápido una de las cinco pizzas de la casa (Margarita, Pepperoni, Hawaiana, Vegetariana y 4 Quesos).
**Pasos:** 1. Elige el tamaño (Individual, Mediana o Familiar) para ver el precio y las calorías. 2. Pulsa **Agregar al pedido** o **Personalizar**.
**Resultado:** la pizza queda en tu pedido. Si una pizza muestra "No disponible", falta un ingrediente y no se puede pedir por ahora. Los precios no incluyen IVA.

### 4.2 Personalizar pizza (armar la tuya)

**Objetivo:** crear tu pizza con casillas.
**Pasos:**

1. Elige el **tamaño**.
2. Marca **una masa** y **una salsa**. Si marcas otra, la anterior se desmarca.
3. Marca los **ingredientes** que quieras (mínimo **3 distintos**). Para repetir un ingrediente (por ejemplo, triple queso) sube sus **porciones** hasta **3**.
4. Junto a cada ingrediente verás el **stock disponible**; no puedes pedir más porciones que el stock. Los agotados aparecen deshabilitados.
5. En el panel **Tu pizza** ves en vivo las **calorías totales** y el **precio** (sin IVA).
6. Elige la cantidad de pizzas (1 a 20) y pulsa **Agregar al pedido** (`Ctrl+Enter`).

**Resultado:** la pizza se agrega a "Mi pedido". Si falta algo (masa, salsa, 3 ingredientes) el botón queda deshabilitado y el panel explica qué falta.

**Personalizar una predefinida:** los ingredientes de la receta aparecen marcados y bloqueados; solo puedes **agregar** ingredientes o porciones (el máximo de 3 porciones incluye las de la receta). En las predefinidas no se exige el mínimo de 3 ingredientes.

### 4.3 Resumen del pedido (Mi pedido)

**Objetivo:** revisar y confirmar.
**Pasos:** 1. Revisa cada pizza (tamaño, ingredientes, calorías y precio). 2. Cambia cantidades o quita pizzas. 3. Mira el resumen: **Calorías totales, Subtotal 15 %, Subtotal 0 %, IVA 15 % y TOTAL (USD)**. 4. Pulsa **Confirmar pedido** y acepta.
**Resultado:** se crea tu pedido con estado **Pendiente** y número `GP-AAAAMMDD-0001`; verás el comprobante. Una vez confirmado **no se puede cancelar**.

### 4.4 Mis pedidos y comprobante

**Objetivo:** consultar el estado y el historial.
**Pasos:** 1. Abre **Mis pedidos**; usa los filtros de estado si quieres. 2. Pulsa **Actualizar** (`F5`) para ver cambios. 3. Abre un pedido para ver su comprobante.
**Estados:** **Pendiente** (recibido), **En preparación** (en cocina) y **Entregado**. Solo el local los cambia.
**Comprobante:** muestra el logotipo, el número y la fecha, tus datos, cada pizza con tamaño, masa, salsa e ingredientes (cantidad, calorías y precio), el resumen con el IVA desglosado, el total y el estado actual. Se ve **solo en pantalla** (no se imprime ni se exporta). Si el local cambia precios después, tu comprobante no cambia.

## 5. Guía por funcionalidad — Administrador

El menú lateral tiene: **Ingredientes**, **Pizzas predefinidas** y **Pedidos**.

### 5.1 Ingredientes

**Objetivo:** mantener el catálogo.
**Pasos:** 1. Usa la búsqueda y los filtros (categoría, "Mostrar inactivos"). 2. **Nuevo ingrediente** (`Ctrl+N`): código único, nombre, categoría (masa, salsa, queso, carne, vegetal u otros), **IVA 15 % (por defecto) o 0 %**, stock y, para **cada tamaño**, precio (sin IVA) y calorías por porción. 3. Para editar pulsa la fila. 4. Para cambiar el stock pulsa la cifra: **Fijar valor** o **Sumar o restar**.
**Activar/desactivar:** los ingredientes **no se eliminan**; al desactivar dejan de ofrecerse y las pizzas que los usan quedan no disponibles. Los pedidos anteriores no cambian.

### 5.2 Pizzas predefinidas

**Objetivo:** definir las recetas.
**Pasos:** 1. **Nueva pizza** o edita una existente. 2. Elige masa, salsa e ingredientes con sus porciones (1 a 3, sin repetir). 3. Mira la vista previa de precio y calorías por tamaño (calculada; no hay precio fijo). 4. Guarda.
**Nota:** una receta puede tener menos de 3 ingredientes. Los cambios afectan solo a pedidos nuevos.

### 5.3 Pedidos

**Objetivo:** atender los pedidos.
**Pasos:** 1. Busca por número o email, o filtra por estado y fechas. 2. Abre el pedido. 3. Pulsa **Pasar a En preparación** y, luego, **Marcar como Entregado**; confirma cada cambio.
**Reglas:** el orden es Pendiente → En preparación → Entregado; no se puede retroceder, saltar ni cancelar. El cliente verá el nuevo estado al actualizar.

## 6. Atajos de teclado

| Atajo               | Acción                                  |
| ------------------- | --------------------------------------- |
| `Ctrl+1` a `Ctrl+4` | Ir a la sección del menú                |
| `Ctrl+Enter`        | Agregar la pizza / confirmar el pedido  |
| `Ctrl+N`            | Nuevo (ingrediente o pizza predefinida) |
| `Ctrl+S`            | Guardar                                 |
| `F5`                | Actualizar                              |
| `Alt+←`             | Volver                                  |
| `F1`                | Ayuda de atajos                         |
| `Esc`               | Cerrar diálogo                          |

## 7. Mensajes de error frecuentes

| Mensaje                                                     | Causa                                      | Solución                                 |
| ----------------------------------------------------------- | ------------------------------------------ | ---------------------------------------- |
| "Email o contraseña incorrectos."                           | Datos de acceso erróneos                   | Revisa y vuelve a intentar               |
| "La contraseña debe tener al menos 8 caracteres."           | Contraseña corta                           | Usa 8 caracteres o más                   |
| "Este email ya está registrado."                            | Ya existe una cuenta                       | Inicia sesión                            |
| "Elige al menos 3 ingredientes distintos."                  | Pizza personalizada con pocos ingredientes | Marca más ingredientes                   |
| "Máximo 3 porciones por ingrediente."                       | Límite por ingrediente                     | Reduce las porciones                     |
| "Stock disponible: N" / "Agotado"                           | Se pide más de lo que hay                  | Elige menos porciones u otro ingrediente |
| "No hay stock suficiente de X: solicitado N, disponible M." | Alguien más pidió antes                    | Ajusta el pedido                         |
| "El precio cambió."                                         | El local actualizó precios                 | Revisa el nuevo total y acepta           |
| "No se pudo conectar con el servidor."                      | El servicio no está en ejecución           | Avisa al local y reintenta               |
| "Tu sesión expiró. Inicia sesión de nuevo."                 | Sesión caducada                            | Inicia sesión                            |
| "El pedido ya cambió de estado." (admin)                    | Otro cambio previo                         | Actualiza y revisa                       |

## 8. Preguntas frecuentes

- **¿Puedo cancelar un pedido?** No; consulta con el local.
- **¿Por qué una pizza aparece "No disponible"?** Le falta un ingrediente o está agotado.
- **¿El precio incluye IVA?** En el armado y las predefinidas se muestra sin IVA; el resumen y el comprobante desglosan el IVA y el total.
- **¿Puedo imprimir el comprobante?** No; solo se muestra en pantalla.
- **¿Cambian mis pedidos antiguos si suben los precios?** No.

## 9. Soporte

Consulta con el personal del local. Los datos del sistema y los precios de ejemplo no son reales.
