# Frontend — Good Pizza (Flutter, solo Windows)

Aplicación de escritorio para Windows, en español, Material 3 en modo claro con paleta azul marino, USD con 2 decimales. Código en `frontend/`. Móvil, web, Linux y macOS están fuera de alcance. Contrato de API: `docs/02-architecture/api-contract.md`; diseño: `docs/03-design/`; backend: `docs/04-backend/README.md`.

## Requisitos

| Requisito                     | Detalle                                                                                                                                                                                                                                                                                         |
| ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Flutter                       | Probado con Flutter 3.47.9 (stable) y Dart 3.13.7. Si `flutter` no está en el PATH: `C:\src\flutter\bin\flutter.bat`.                                                                                                                                                                           |
| Windows                       | Windows 10/11 de 64 bits.                                                                                                                                                                                                                                                                       |
| Visual Studio                 | Visual Studio 2022 o Build Tools con la carga de trabajo **Desarrollo para el escritorio con C++** y el componente **C++ ATL para las últimas herramientas de compilación v143 (x86 y x64)**. Sin ATL, `flutter build windows` y `flutter run -d windows` fallan (ver "Solución de problemas"). Con el componente instalado, la compilación funciona (verificado en la fase 6). |
| Modo desarrollador de Windows | Necesario para que Flutter cree enlaces simbólicos de plugins (Configuración > Privacidad y seguridad > Para programadores).                                                                                                                                                                    |
| Backend                       | La API debe estar en ejecución (`cd backend && npm run dev`, por defecto `http://localhost:3000/api/v1`).                                                                                                                                                                                       |

## Cómo ejecutar en Windows

```bash
cd frontend
flutter pub get
flutter run -d windows                       # API en http://localhost:3000/api/v1
flutter run -d windows --dart-define=API_URL=http://192.168.1.50:3000/api/v1   # otra API
flutter build windows --release --dart-define=API_URL=http://localhost:3000/api/v1
```

El ejecutable de `build windows` queda en `frontend/build/windows/x64/runner/<Debug|Release>/good_pizza.exe`. Ventana inicial 1280 x 800; el tamaño mínimo 1024 x 680 es solo recomendado (por debajo aparece scroll, no se recorta).

## URL de la API por entorno (`--dart-define`)

| Variable  | Valor por defecto              | Uso                                                                                                               |
| --------- | ------------------------------ | ----------------------------------------------------------------------------------------------------------------- |
| `API_URL` | `http://localhost:3000/api/v1` | URL base de la API (incluye `/api/v1`). Se lee con `String.fromEnvironment` en `lib/core/config/app_config.dart`. |

El frontend no necesita ninguna variable del backend ni lee `backend/.env.local`. No hay secretos en el código: los tokens de sesión se guardan en `flutter_secure_storage` (Credential Manager de Windows).

## Cuentas de prueba

El seed del backend crea 1 administrador y 1 cliente (emails por defecto `admin@goodpizza.local` y `cliente@goodpizza.local`). Las contraseñas las define quien ejecuta el seed (variables `SEED_ADMIN_PASSWORD` / `SEED_CLIENT_PASSWORD`) o se imprimen una sola vez en la consola del seed. También puede registrarse un cliente nuevo desde la pantalla "Crear cuenta".

## Pruebas

```bash
cd frontend
flutter analyze            # sin errores ni avisos
flutter test               # 225 pruebas (unitarias, de widget y de flujo); verificado en la fase 6
flutter test --coverage    # cobertura en coverage/lcov.info
flutter test test/flows    # solo el flujo "personalizar pizza hasta generar la orden"
```

Las pruebas no necesitan backend ni base de datos: usan repositorios falsos (`test/helpers/fakes.dart`) y `ProviderScope` con overrides. Detalle y resultados reales en `pruebas-unitarias.md`.

## Atajos de teclado

`Ctrl+1..4` destinos del menú · `F5` / `Ctrl+R` actualizar · `F1` ayuda de atajos · `Alt+←` volver · `Ctrl+Shift+Q` cerrar sesión · `Ctrl+Enter` agregar pizza / confirmar pedido / avanzar estado · `Ctrl+N` nuevo (admin) · `Ctrl+S` guardar (formularios) · `Ctrl+F` buscar (ingredientes) · `Esc` cerrar diálogo.

## Solución de problemas

| Síntoma                                                                                                      | Causa y solución                                                                                                                                                                                                                                 |
| ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `error C1083: No se puede abrir el archivo incluir: 'atlstr.h'` al compilar `flutter_secure_storage_windows` | Falta ATL. Abrir **Visual Studio Installer > Modificar** (Build Tools 2022), pestaña **Componentes individuales**, marcar **C++ ATL para las últimas herramientas de compilación v143 (x86 y x64)** e instalar. Luego `flutter clean` y repetir. |
| `Building with plugins requires symlink support`                                                             | Activar el **Modo desarrollador** de Windows y reiniciar la terminal.                                                                                                                                                                            |
| "No se pudo conectar con el servidor. Verifica que el servicio esté en ejecución"                            | El backend no está levantado o `API_URL` apunta a otra dirección/puerto. Probar `GET <API_URL>/health`.                                                                                                                                          |
| Pantalla de login tras un tiempo                                                                             | La sesión expiró (refresh token de 7 días rotativo): iniciar sesión de nuevo.                                                                                                                                                                    |

## Estructura

```
frontend/lib/
  main.dart, app.dart              ProviderScope + MaterialApp.router (tema, locale es)
  core/{api,config,storage,theme,router,widgets,utils,layout}
  features/<x>/{data,domain,presentation}
    auth  catalog  preset_pizzas  pizza_builder  cart  orders  admin
frontend/assets/brand/             logotipo SVG (copiado de docs/03-design/assets)
frontend/test/{core,features,flows,helpers}
```

## Documentos de la fase

`entregable.md`, `flujo.md`, `diagrama-er.md`, `pruebas-unitarias.md`, `manual-usuario.md`, `documentacion-tecnica.md` en esta carpeta.
