---
name: testing-strategy
description: Estrategia de pruebas para backend Node y app Flutter (pirámide, herramientas, cobertura, criterios de salida).
---
# Estrategia de pruebas

- Pirámide: muchas unitarias, algunas de integración (API + BD de prueba), pocas E2E.
- Backend: Vitest + Supertest; BD PostgreSQL de pruebas separada (`DB_NAME` distinto, p. ej. `<proyecto>_test`); nunca usar la base de desarrollo; limpiar entre tests.
- Flutter: `flutter_test` (unitarias y widget), `integration_test` para el flujo principal.
- Cada historia de usuario tiene al menos un caso trazable (ID en el nombre del test).
- Casos obligatorios: camino feliz, validación, no autenticado, no autorizado, no encontrado, concurrencia básica.
- Criterio de salida: 0 fallos, cobertura ≥ 70 % en servicios del backend, `flutter analyze` sin errores.
- Reportar resultados reales; nunca declarar éxito sin ejecutar las pruebas.
