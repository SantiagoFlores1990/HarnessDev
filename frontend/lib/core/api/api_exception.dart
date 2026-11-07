import 'package:dio/dio.dart';

/// Codigos de error del contrato (api-contract.md §1.2), 24 en total.
abstract final class ErrorCodes {
  static const validation = 'VALIDATION_ERROR';
  static const unauthenticated = 'UNAUTHENTICATED';
  static const tokenExpired = 'TOKEN_EXPIRED';
  static const invalidCredentials = 'INVALID_CREDENTIALS';
  static const invalidRefreshToken = 'INVALID_REFRESH_TOKEN';
  static const forbidden = 'FORBIDDEN';
  static const notFound = 'NOT_FOUND';
  static const routeNotFound = 'ROUTE_NOT_FOUND';
  static const emailExists = 'EMAIL_ALREADY_EXISTS';
  static const ingredientCodeExists = 'INGREDIENT_CODE_EXISTS';
  static const presetCodeExists = 'PRESET_CODE_EXISTS';
  static const presetNameExists = 'PRESET_NAME_EXISTS';
  static const insufficientStock = 'INSUFFICIENT_STOCK';
  static const priceChanged = 'PRICE_CHANGED';
  static const pizzaRulesViolated = 'PIZZA_RULES_VIOLATED';
  static const missingSizeValues = 'MISSING_SIZE_VALUES';
  static const invalidRecipe = 'INVALID_RECIPE';
  static const categoryLocked = 'INGREDIENT_CATEGORY_LOCKED';
  static const invalidTransition = 'INVALID_STATUS_TRANSITION';
  static const invalidVatRate = 'INVALID_VAT_RATE';
  static const stockWouldBeNegative = 'STOCK_WOULD_BE_NEGATIVE';
  static const rateLimited = 'RATE_LIMITED';
  static const internal = 'INTERNAL_ERROR';
  static const serviceUnavailable = 'SERVICE_UNAVAILABLE';

  /// Codigos locales (no vienen del servidor).
  static const network = 'NETWORK_ERROR';
  static const cancelled = 'CANCELLED';

  static const all = <String>[
    validation, unauthenticated, tokenExpired, invalidCredentials, invalidRefreshToken,
    forbidden, notFound, routeNotFound, emailExists, ingredientCodeExists,
    presetCodeExists, presetNameExists, insufficientStock, priceChanged,
    pizzaRulesViolated, missingSizeValues, invalidRecipe, categoryLocked,
    invalidTransition, invalidVatRate, stockWouldBeNegative, rateLimited,
    internal, serviceUnavailable,
  ];
}

const String genericErrorMessage = 'Ocurrió un error inesperado. Inténtalo de nuevo.';
const String networkErrorMessage =
    'No se pudo conectar con el servidor. Verifica que el servicio esté en ejecución e inténtalo de nuevo.';

/// Mensajes de respaldo por `code` (screens.md §6.1). La UI decide por `code`, nunca por `message`.
const Map<String, String> _messagesByCode = {
  ErrorCodes.validation: 'Revisa los datos ingresados.',
  ErrorCodes.unauthenticated: 'Inicia sesión para continuar.',
  ErrorCodes.tokenExpired: 'Tu sesión expiró. Inicia sesión de nuevo.',
  ErrorCodes.invalidCredentials: 'Email o contraseña incorrectos.',
  ErrorCodes.invalidRefreshToken: 'Tu sesión expiró. Inicia sesión de nuevo.',
  ErrorCodes.forbidden: 'No tienes permiso para realizar esta acción.',
  ErrorCodes.notFound: 'No encontramos lo que buscas. Puede que ya no esté disponible.',
  ErrorCodes.routeNotFound:
      'Ocurrió un problema interno de la aplicación. Actualiza e inténtalo de nuevo.',
  ErrorCodes.emailExists: 'Este email ya está registrado.',
  ErrorCodes.ingredientCodeExists: 'Ya existe un ingrediente con ese código.',
  ErrorCodes.presetCodeExists: 'Ya existe una pizza con ese código.',
  ErrorCodes.presetNameExists: 'Ya existe una pizza con ese nombre.',
  ErrorCodes.insufficientStock: 'No hay stock suficiente para completar el pedido.',
  ErrorCodes.priceChanged: 'El precio cambió. Revisa el nuevo total antes de confirmar.',
  ErrorCodes.pizzaRulesViolated: 'Alguna pizza no cumple las reglas de armado.',
  ErrorCodes.missingSizeValues: 'Define precio y calorías para los tres tamaños.',
  ErrorCodes.invalidRecipe: 'La receta no es válida.',
  ErrorCodes.categoryLocked:
      'No se puede cambiar la categoría: el ingrediente se usa en pizzas predefinidas.',
  ErrorCodes.invalidTransition:
      'El pedido ya cambió de estado. Actualiza para ver el estado actual.',
  ErrorCodes.invalidVatRate: 'Elige una tarifa de IVA válida (15 % o 0 %).',
  ErrorCodes.stockWouldBeNegative: 'El ajuste dejaría el stock por debajo de 0.',
  ErrorCodes.rateLimited: 'Demasiadas solicitudes. Espera unos minutos e inténtalo de nuevo.',
  ErrorCodes.internal: genericErrorMessage,
  ErrorCodes.serviceUnavailable:
      'El servicio no está disponible en este momento. Inténtalo de nuevo en unos minutos.',
};

/// Error de la API ya normalizado: `{ error: { code, message, details } }`.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    this.statusCode,
    this.serverMessage,
    this.details = const [],
  });

  final String code;
  final int? statusCode;
  final String? serverMessage;
  final List<dynamic> details;

  bool get isNetwork => code == ErrorCodes.network;
  bool get isCancelled => code == ErrorCodes.cancelled;
  bool get isNotFound => code == ErrorCodes.notFound;

  /// Mensaje en espanol apto para mostrar. Nunca muestra el codigo ni el stack.
  String get userMessage {
    if (isNetwork) return networkErrorMessage;
    return _messagesByCode[code] ?? genericErrorMessage;
  }

  /// Detalles de tipo mapa (descarta elementos que no lo sean).
  List<Map<String, dynamic>> get detailMaps =>
      details.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  /// Errores por campo para `VALIDATION_ERROR`: `path` -> `message`.
  Map<String, String> get fieldErrors {
    final result = <String, String>{};
    for (final d in detailMaps) {
      final path = d['path'];
      final message = d['message'];
      if (path is String && message is String) result.putIfAbsent(path, () => message);
    }
    return result;
  }

  /// Lineas "No hay stock suficiente de X: solicitado N, disponible M." de `INSUFFICIENT_STOCK`.
  List<String> get stockLines {
    final lines = <String>[];
    for (final d in detailMaps) {
      final name = d['name'];
      if (name == null) continue;
      lines.add(
        'No hay stock suficiente de $name: solicitado ${d['requested']}, disponible ${d['available']}.',
      );
    }
    return lines;
  }

  /// Nuevo total de `PRICE_CHANGED` (`details[0].quote.totals.total`).
  String? get newTotalFromPriceChanged {
    for (final d in detailMaps) {
      final quote = d['quote'];
      if (quote is Map && quote['totals'] is Map) {
        return (quote['totals'] as Map)['total']?.toString();
      }
    }
    return null;
  }

  static ApiException fromDio(DioException e) {
    if (e.type == DioExceptionType.cancel) {
      return const ApiException(code: ErrorCodes.cancelled);
    }
    final response = e.response;
    final data = response?.data;
    if (response != null && data is Map && data['error'] is Map) {
      final error = data['error'] as Map;
      return ApiException(
        code: (error['code'] as String?) ?? ErrorCodes.internal,
        statusCode: response.statusCode,
        serverMessage: error['message'] as String?,
        details: (error['details'] as List?) ?? const [],
      );
    }
    if (response != null) {
      final status = response.statusCode ?? 0;
      return ApiException(
        code: status == 503 ? ErrorCodes.serviceUnavailable : ErrorCodes.internal,
        statusCode: status,
      );
    }
    return const ApiException(code: ErrorCodes.network);
  }

  @override
  String toString() => 'ApiException($code, status: $statusCode)';
}

/// Ejecuta una llamada dio y convierte `DioException` en [ApiException].
Future<T> apiCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
}

/// Mensaje legible para cualquier error capturado en la UI.
String errorMessageOf(Object error) =>
    error is ApiException ? error.userMessage : genericErrorMessage;
