---
name: flutter-multiplatform
description: Cómo estructurar una app Flutter que corra en móvil (Android/iOS) y desktop (Windows/Linux/macOS) con layouts adaptativos.
---
# Flutter multiplataforma

- Crear con `flutter create --platforms=android,ios,windows,linux,macos,web .`
- Estructura: `lib/core/{api,theme,router,widgets}` y `lib/features/<feature>/{data,domain,presentation}`.
- Responsive: `LayoutBuilder`/`MediaQuery`; <600 móvil (`NavigationBar`), ≥1024 desktop (`NavigationRail`, paneles laterales).
- Desktop: soportar teclado (`Shortcuts`/`Actions`), foco visible, hover, ventanas redimensionables; considerar `window_manager`.
- Material 3, `ThemeData` centralizado, claro/oscuro.
- API base con `String.fromEnvironment('API_URL')`; en Android emulador usar `10.0.2.2`.
- Token en `flutter_secure_storage`; no usar `shared_preferences` para secretos.
- Evitar `dart:io` en código que deba compilar a web, o aislarlo con imports condicionales.
- Comandos: `flutter run -d windows|android|<device>`, `flutter build windows|apk|linux|macos`.
