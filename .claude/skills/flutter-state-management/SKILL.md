---
name: flutter-state-management
description: Gestión de estado en Flutter con Riverpod, repositorios y manejo de estados de carga, vacío y error.
---
# Estado con Riverpod

- `ProviderScope` en `main`; `AsyncNotifier`/`FutureProvider` para datos remotos.
- Repositorio por feature (`data/`) que envuelve `dio`; los widgets nunca llaman a `dio` directamente.
- Modelos inmutables (`freezed` + `json_serializable` o clases `const` a mano).
- UI siempre maneja `AsyncValue`: `loading`, `error` (con reintento) y `data` (con estado vacío).
- Estado de formularios y carrito en `Notifier` local a la feature; persistir solo lo necesario.
- Pruebas: `ProviderContainer` con overrides y repositorios falsos.
