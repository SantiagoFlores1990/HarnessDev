# Manual de usuario — Fase 7: Buenas prácticas de seguridad

## 1. Introducción

Good Pizza guarda cuentas de clientes (nombre, email y contraseña cifrada), pedidos e inventario. Este manual explica qué debe hacer cada persona para usarlo de forma segura. Complementa el manual funcional de `docs/05-frontend/manual-usuario.md` y no lo reemplaza.

## 2. Requisitos

- PC con Windows del local, con la app Good Pizza y la API instaladas en la misma máquina (arquitectura de referencia).
- Una cuenta de Windows protegida con contraseña. Se recomienda una cuenta de Windows **separada** para el administrador.

## 3. Acceso al sistema

- **Clientes:** crean su cuenta en "Registro" con una contraseña de **al menos 8 caracteres**. Se recomienda una frase larga que no usen en otros servicios.
- **Administrador:** su cuenta la crea el seed. Si no se definió `SEED_ADMIN_PASSWORD`, la contraseña se muestra **una sola vez** en la consola del seed: guárdala en un gestor de contraseñas y no en papel junto al PC.
- **Cerrar sesión:** menú de la barra lateral, o `Ctrl+Shift+Q`. **La sesión no se cierra sola:** si sales de la app sin cerrar sesión, quien la abra después entra con tu cuenta (hallazgo S-03).

## 4. Guía por perfil

### 4.1 Clientes

**Objetivo:** proteger tu cuenta y tus pedidos.
**Pasos:**

1. Al terminar tu pedido, pulsa **Cerrar sesión** antes de dejar el PC.
2. No compartas tu contraseña con el personal: nadie del local la necesita.
3. Si ves la sesión de otra persona abierta, ciérrala y avisa al personal.

**Resultado:** nadie más puede ver tu historial ni pedir a tu nombre.

### 4.2 Administrador

**Objetivo:** evitar que un cliente use funciones de administración.
**Pasos:**

1. **Cierra siempre la sesión de administrador** al terminar. Si es posible, administra desde una cuenta de Windows distinta a la que usan los clientes.
2. Usa una contraseña de 12 caracteres o más, única, y cámbiala si sospechas que alguien la vio.
3. Revisa a diario la lista de pedidos: un volumen anómalo de pedidos del mismo cliente puede ser abuso (S-06). Hoy no existe la cancelación; anota el caso y ajusta el stock manualmente con la operación "Ajustar (ADD)".
4. Si varios usuarios dicen "Demasiadas solicitudes", espera 15 minutos: el límite de intentos se comparte en el PC (S-02).
5. No compartas capturas de los pedidos con datos de clientes (nombre y email).

**Resultado:** el catálogo, los precios y el stock solo los cambia quien debe.

### 4.3 Quien instala y mantiene el sistema

**Objetivo:** dejar el servidor bien configurado.
**Pasos:**

1. En `backend/.env.local` (nunca lo subas al repositorio ni lo compartas):
   - `JWT_SECRET` y `JWT_REFRESH_SECRET`: valores **aleatorios, distintos y de 32 caracteres o más**. Generar cada uno con `node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"`. **Nunca** dejes `change-me` (condición C1 del informe).
   - `NODE_ENV=production` en el PC del local: así el servidor se niega a arrancar con secretos débiles.
   - `BCRYPT_COST=12` o más.
2. Firewall de Windows: **no** permitas conexiones entrantes al puerto 3000 desde la red. La app y la API corren en el mismo PC (S-04).
3. Si alguna vez se usa la API desde otro equipo, pon delante un proxy con HTTPS. No uses `http://IP:3000` en una red compartida.
4. PostgreSQL: usa un usuario de base de datos propio de la app, sin permisos de superusuario. Haz copias de seguridad cifradas de la base `pizzeria` y guárdalas fuera del PC.
5. Para las pruebas de integración, define `DATABASE_URL_TEST` siempre con `?schema=test`. Nunca apuntes las pruebas a `public`.
6. Mantén las dependencias al día (`npm audit`, `flutter pub outdated`) y vuelve a ejecutar las pruebas después.

**Resultado:** nadie puede forjar sesiones ni acceder a la API desde la red.

## 5. Mensajes de error frecuentes

| Mensaje                                                                            | Causa                                                                                      | Solución                                                              |
| ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ | --------------------------------------------------------------------- |
| "Email o contraseña incorrectos."                                                  | Credenciales erróneas (el sistema no dice cuál de las dos)                                 | Revisa mayúsculas y vuelve a intentarlo                               |
| "Demasiadas solicitudes. Intenta de nuevo en unos minutos."                        | Se superó el límite de intentos (10 de autenticación cada 15 minutos, compartido en el PC) | Espera hasta 15 minutos; avisa al administrador si se repite          |
| "Tu cuenta está desactivada."                                                      | El administrador desactivó la cuenta (hoy solo es posible por base de datos)               | Contacta al local                                                     |
| "La sesión no es válida. Inicia sesión de nuevo."                                  | La sesión caducó (7 días), se cerró en otro lado o se detectó un token reutilizado         | Inicia sesión de nuevo. Si se repite sin motivo, cambia tu contraseña |
| "Configuración inválida… JWT_SECRET (mínimo 32 caracteres)" (consola del servidor) | `NODE_ENV=production` con secretos débiles                                                 | Genera secretos nuevos (ver 4.3)                                      |

## 6. Preguntas frecuentes

- **¿El sistema guarda mi contraseña?** No: guarda un hash bcrypt que no se puede revertir.
- **¿El personal puede ver mi contraseña?** No. El administrador ve tu nombre, tu email y tus pedidos.
- **¿Puedo cancelar un pedido?** Hoy no. El administrador solo puede avanzar el estado.
- **¿Qué pasa si olvido cerrar sesión?** La siguiente persona entra con tu cuenta hasta que alguien cierre sesión o pasen 7 días sin uso.

## 7. Soporte

Para incidentes de seguridad (sesión ajena abierta, pedidos que no reconoces, cambios de precio no autorizados), avisa al administrador del local. Quien mantiene el sistema debe:

1. Cambiar los secretos JWT, lo que invalida todas las sesiones.
2. Revisar `order_status_history` y los logs del servidor.
