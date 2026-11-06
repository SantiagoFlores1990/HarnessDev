---
name: security-checklist
description: Lista de verificación de seguridad (OWASP Top 10) aplicada al stack Node + Flutter.
---
# Checklist de seguridad

- [ ] Auth: hash bcrypt, expiración de JWT, refresh rotativo, bloqueo/limitación de intentos.
- [ ] Autorización por recurso (IDOR): el usuario solo accede a sus pedidos.
- [ ] Validación y saneado de todo input (Zod); consultas parametrizadas (Prisma).
- [ ] CORS restrictivo, `helmet`, rate limiting, límite de tamaño de body.
- [ ] Sin secretos en el repo; `.env` ignorado; `.env.example` sin valores reales.
- [ ] Errores sin stack traces ni detalles internos en producción.
- [ ] Dependencias: `npm audit`, `flutter pub outdated`; sin paquetes abandonados.
- [ ] Flutter: token en almacenamiento seguro, HTTPS en producción, sin logs de datos sensibles.
- [ ] Logs sin PII/credenciales; backups cifrados.
