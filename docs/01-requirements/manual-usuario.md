# Manual de usuario — Fase 1 (alcance previsto)

Describe lo que el usuario podrá hacer. La aplicación aún no existe; el contenido se actualizará en fases posteriores.

## 1. Introducción

Good Pizza es una aplicación de escritorio para Windows para pedir pizzas en el local, predefinidas o personalizadas. Va dirigida a clientes y al administrador de la pizzería.

## 2. Requisitos

- Windows 10/11. Conexión al servidor del local.

## 3. Acceso al sistema

- Registro con nombre, email y contraseña de mínimo 8 caracteres.
- Inicio de sesión con email y contraseña. Sin sesión no se puede pedir.

## 4. Guía por funcionalidad

### 4.1 Elegir una pizza predefinida (cliente)

**Objetivo:** pedir rápido. · **Pasos:** 1. Abrir "Pizzas predefinidas". 2. Elegir tamaño. 3. Opcional: agregar ingredientes (no se pueden quitar; no se exige un mínimo de ingredientes). · **Resultado:** pizza lista para agregar al pedido. Si una predefinida aparece como no disponible, algún ingrediente de su receta está inactivo o sin stock.

### 4.2 Personalizar pizza (cliente)

**Objetivo:** armar la pizza propia. · **Pasos:** 1. Elegir tamaño. 2. Elegir 1 masa y 1 salsa. 3. Marcar al menos 3 ingredientes distintos, con 1 a 3 porciones cada uno y sin superar el stock. 4. Revisar calorías y precio en vivo. 5. Agregar al pedido. · **Resultado:** pizza en el pedido.

### 4.3 Confirmar pedido y ver la orden (cliente)

**Objetivo:** registrar el pedido. · **Pasos:** 1. Abrir el resumen y ajustar cantidades (1 a 20 por pizza). 2. Revisar Subtotal 15 %, Subtotal 0 %, IVA 15 % y Total. 3. Confirmar. · **Resultado:** orden `GP-AAAAMMDD-0001` en estado Pendiente, visible en pantalla (no se exporta ni imprime). Una vez confirmado, el pedido no se puede cancelar.

### 4.4 Mis pedidos (cliente)

**Objetivo:** consultar estado e historial. · **Pasos:** abrir "Mis pedidos" y elegir un pedido. · **Resultado:** detalle y estado actual.

### 4.5 Gestionar ingredientes (administrador)

**Objetivo:** mantener el catálogo. · **Pasos:** crear o editar código, nombre, categoría, estado, stock, IVA, y calorías y precio por tamaño. Para retirar un ingrediente, desactivarlo (no se borra). · **Resultado:** catálogo actualizado para nuevos pedidos.

### 4.6 Gestionar pizzas predefinidas y pedidos (administrador)

**Objetivo:** mantener recetas y atender pedidos. · **Pasos:** editar recetas (el precio siempre se calcula por fórmula); en pedidos, avanzar Pendiente → En preparación → Entregado. · **Resultado:** el cliente ve el nuevo estado.

## 5. Mensajes de error frecuentes

| Mensaje                                        | Causa                                           | Solución                      |
| ---------------------------------------------- | ----------------------------------------------- | ----------------------------- |
| Elige al menos 3 ingredientes distintos        | Pizza personalizada con menos de 3 ingredientes | Agregar más                   |
| Máximo 3 porciones por ingrediente             | Cantidad mayor a 3                              | Reducir                       |
| Máximo 20 pizzas por línea                     | Cantidad mayor a 20                             | Reducir                       |
| La contraseña debe tener al menos 8 caracteres | Contraseña corta                                | Usar una más larga            |
| Stock insuficiente                             | Porciones mayores que las existencias           | Reducir o cambiar ingrediente |
| Credenciales incorrectas                       | Email o contraseña erróneos                     | Reintentar                    |

(Los textos definitivos se fijarán en las fases siguientes.)

## 6. Preguntas frecuentes

- ¿Puedo quitar ingredientes de una predefinida? No, solo agregar.
- ¿Los precios incluyen IVA? No, el IVA se desglosa en el pedido.
- ¿Cambian mis pedidos si suben los precios? No.
- ¿Puedo cancelar un pedido? No; consulta al personal del local.
- ¿Puedo imprimir o descargar la orden? No, solo se muestra en pantalla.

## 7. Soporte

Consultar al administrador de la pizzería.
