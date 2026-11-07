/// Configuracion por entorno. La URL de la API se define al compilar o ejecutar:
/// `flutter run -d windows --dart-define=API_URL=http://localhost:3000/api/v1`.
abstract final class AppConfig {
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );
  static const String appName = 'Good Pizza';
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
