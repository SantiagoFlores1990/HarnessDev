# ADR-006: Autenticación JWT con access + refresh rotativo

- **Estado:** Aceptado · **Fecha:** 2026-11-06

## Contexto

RF-02/RF-03: login obligatorio para pedir, autorización por rol y por dueño. Skill `nodejs-express-api`: JWT access (15 min) + refresh, bcrypt coste ≥ 12. App de escritorio sin cookies de navegador. `env.template` ya prevé `JWT_SECRET` y `JWT_REFRESH_SECRET`.

## Decisión

- Access token JWT HS256 (`JWT_SECRET`, 15 min) con `sub`, `role`, `type:"access"`; verificado por `requireAuth` sin consultar BD.
- Refresh token JWT HS256 (`JWT_REFRESH_SECRET`, 7 días) con `jti`; en BD solo su hash SHA-256 (`refresh_tokens`). Rotación en cada `/auth/refresh`; reutilización de un token rotado → revocación de todos los del usuario. `/auth/logout` revoca.
- Contraseñas con bcrypt (`bcryptjs`, ya en `package.json`), coste `BCRYPT_COST` (def. 12), longitud 8..72.
- Registro público solo crea `CLIENT` (S-14); el admin lo crea el seed.
- Autorización: `requireRole` por ruta; filtro por dueño en `order.service`; pedido ajeno → 404.
- Flutter guarda ambos tokens en `flutter_secure_storage` y refresca en el interceptor de dio ante `401 TOKEN_EXPIRED` (un solo refresh concurrente).

## Alternativas

- **Sesiones en servidor con cookie:** natural en web, incómodo en escritorio con dio y no aporta en un monolito local.
- **Solo access token de larga duración:** sin revocación ni logout real.
- **Refresh opaco aleatorio (no JWT):** igual de válido; se elige JWT por reutilizar `JWT_REFRESH_SECRET` ya previsto y validar expiración sin BD antes de buscar el hash.

## Consecuencias

- (+) Stateless en cada petición; revocación posible vía refresh.
- (−) Un access token robado vale hasta 15 min; un cambio de rol se refleja al refrescar.
- (−) Tabla `refresh_tokens` crece; se purgan los expirados en el login (borrado de `expires_at < now()` del usuario).
