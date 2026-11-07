# Manual de usuario — Fase 6 (QA)

Esta fase no agrega pantallas. El manual explica cómo verificar el sistema (para quien opera o revisa el proyecto) y qué comprobar a mano antes de usarlo con clientes. Los manuales de uso de la app están en `docs/04-backend/manual-usuario.md` y `docs/05-frontend/manual-usuario.md`.

## 1. Introducción

Good Pizza es una aplicación de escritorio para Windows (Flutter) con un backend Node.js y PostgreSQL. Este manual está dirigido a la persona que valida la entrega.

## 2. Requisitos

- Windows 10/11 de 64 bits; Node.js 20 o superior; Flutter 3.47.9 (si no está en el PATH: `C:\src\flutter\bin\flutter.bat`); Visual Studio 2022 con C++ y ATL para compilar la app.
- PostgreSQL 17 con la base `pizzeria` y `backend/.env.local` configurado (nunca se muestra ni se versiona; use `backend/env.template` como guía).
- Para las pruebas con base de datos real: la variable `DATABASE_URL_TEST` con el esquema `test` (ver sección 4.3).

## 3. Acceso al sistema

Tras `npm run db:seed`, el seed crea un administrador y un cliente de ejemplo. Sus contraseñas salen de `SEED_ADMIN_PASSWORD` y `SEED_CLIENT_PASSWORD`; si no existen, el seed las genera y las imprime una sola vez en la consola. Los datos del seed son de ejemplo, no precios reales.

## 4. Guía por funcionalidad

### 4.1 Ejecutar las pruebas automáticas

**Objetivo:** confirmar que todo pasa. **Pasos:**

1. Backend: `cd backend`, luego `npm test` y `npm run lint`.
2. Cobertura del backend: `npm test -- --coverage` (el informe HTML queda en `backend/coverage/`).
3. Frontend: `cd frontend`, luego `flutter analyze` y `flutter test --coverage`.
4. App de escritorio real: `flutter test integration_test/app_flow_test.dart -d windows`.

**Resultado esperado (estado actual):** backend 267 pruebas pasan y 22 se omiten con el aviso de `DATABASE_URL_TEST`; lint sin salida; `flutter analyze` sin problemas; 225 pruebas de Flutter pasan; la prueba de integración pasa.

### 4.2 Interpretar "omitidas"

Las 22 pruebas omitidas son las que usan PostgreSQL real (concurrencia de stock, numeración diaria, restricciones CHECK y los criterios 1-3 contra la base). No son fallos: indican que no se ejecutaron. Hasta ejecutarlas, esas garantías no están verificadas en la base real.

### 4.3 Habilitar las pruebas con base de datos real

**Pasos:**

1. En `backend/.env.local` agregue `DATABASE_URL_TEST` con la misma conexión y `?schema=test` al final (no copie la contraseña a ningún otro archivo).
2. `npm run db:test:migrate` crea y migra el esquema `test`.
3. `npm test`. Las pruebas truncan solo el esquema `test`; abortan si la URL no termina en `?schema=test`.

### 4.4 Revisión manual recomendada de la aplicación

1. Inicie el backend (`npm run dev`) y compruebe `GET http://localhost:3000/api/v1/health` (debe responder `status: ok`, `database: ok`).
2. Inicie la app: `flutter run -d windows` en `frontend/`.
3. Como cliente: regístrese, arme una pizza con triple queso, confirme y verifique en el comprobante calorías totales, Subtotal 15 %, Subtotal 0 %, IVA 15 % y TOTAL.
4. Como administrador: cambie precio y stock de un ingrediente, avance el pedido hasta Entregado y verifique que el pedido antiguo conserva sus valores.

Estos pasos manuales no se ejecutaron en esta fase (ver `test-report.md` §8).

## 5. Mensajes de error frecuentes

| Mensaje                                                                        | Causa                                                              | Solución                                                         |
| ------------------------------------------------------------------------------ | ------------------------------------------------------------------ | ---------------------------------------------------------------- |
| `[AVISO] DATABASE_URL_TEST no está definida…`                                  | Falta la variable de pruebas con BD                                | Ver 4.3                                                          |
| `'flutter' no se reconoce…`                                                    | Flutter no está en el PATH                                         | Usar `C:\src\flutter\bin\flutter.bat` o agregarlo al PATH         |
| `error C1083: ... 'atlstr.h'` al compilar                                      | Falta el componente C++ ATL de Visual Studio                       | Instalarlo desde Visual Studio Installer                         |

## 6. Preguntas frecuentes

- **¿Las pruebas tocan la base de datos real?** No. Las pruebas unitarias y de API usan dobles; las de integración solo el esquema `test` y se omiten si falta `DATABASE_URL_TEST`.
- **¿Por qué la cobertura del backend no incluye `server.js`?** Es el arranque del proceso; no se prueba de forma automática.
- **¿La latencia medida incluye la base de datos?** No; ver `test-report.md` §5.

## 7. Soporte

Defectos y observaciones con responsable: `docs/06-qa/test-report.md` §6. Preguntas abiertas: §9 del mismo documento.
