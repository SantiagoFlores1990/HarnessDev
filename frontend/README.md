# Frontend (Flutter, solo Windows) — Good Pizza

Aplicación de escritorio Windows en español (Material 3, tema azul marino, modo claro). Consume la API REST `/api/v1` del backend de este repositorio.

La guía completa (cómo ejecutar, `--dart-define`, pruebas, solución de problemas) está en [`docs/05-frontend/README.md`](../docs/05-frontend/README.md).

Resumen rápido:

```
cd frontend
flutter pub get
flutter run -d windows --dart-define=API_URL=http://localhost:3000/api/v1
flutter analyze
flutter test
```

Creado con `flutter create --org com.pizzeria --project-name good_pizza --platforms=windows .` (nombre visible: "Good Pizza").
