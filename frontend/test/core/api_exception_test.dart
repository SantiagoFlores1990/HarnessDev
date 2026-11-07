import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:good_pizza/core/api/api_exception.dart';
import 'package:good_pizza/features/orders/domain/order_models.dart';
import 'package:good_pizza/features/orders/domain/violation_text.dart';

DioException _dioError(int status, Map<String, dynamic> body) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: status, data: body),
      type: DioExceptionType.badResponse,
    );

void main() {
  group('WT-23 ApiException', () {
    // Mensajes de screens.md §6.1 (respaldo por code).
    const expected = <String, String>{
      'VALIDATION_ERROR': 'Revisa los datos ingresados.',
      'UNAUTHENTICATED': 'Inicia sesión para continuar.',
      'INVALID_CREDENTIALS': 'Email o contraseña incorrectos.',
      'INVALID_REFRESH_TOKEN': 'Tu sesión expiró. Inicia sesión de nuevo.',
      'FORBIDDEN': 'No tienes permiso para realizar esta acción.',
      'NOT_FOUND': 'No encontramos lo que buscas. Puede que ya no esté disponible.',
      'ROUTE_NOT_FOUND': 'Ocurrió un problema interno de la aplicación. Actualiza e inténtalo de nuevo.',
      'EMAIL_ALREADY_EXISTS': 'Este email ya está registrado.',
      'INGREDIENT_CODE_EXISTS': 'Ya existe un ingrediente con ese código.',
      'PRESET_CODE_EXISTS': 'Ya existe una pizza con ese código.',
      'PRESET_NAME_EXISTS': 'Ya existe una pizza con ese nombre.',
      'MISSING_SIZE_VALUES': 'Define precio y calorías para los tres tamaños.',
      'INVALID_STATUS_TRANSITION': 'El pedido ya cambió de estado. Actualiza para ver el estado actual.',
      'INVALID_VAT_RATE': 'Elige una tarifa de IVA válida (15 % o 0 %).',
      'STOCK_WOULD_BE_NEGATIVE': 'El ajuste dejaría el stock por debajo de 0.',
      'RATE_LIMITED': 'Demasiadas solicitudes. Espera unos minutos e inténtalo de nuevo.',
      'INTERNAL_ERROR': 'Ocurrió un error inesperado. Inténtalo de nuevo.',
      'SERVICE_UNAVAILABLE': 'El servicio no está disponible en este momento. Inténtalo de nuevo en unos minutos.',
    };

    test('el contrato define 24 codigos y todos tienen mensaje en espanol', () {
      expect(ErrorCodes.all.length, 24);
      expect(ErrorCodes.all.toSet().length, 24);
      for (final code in ErrorCodes.all) {
        final message = ApiException(code: code).userMessage;
        expect(message, isNotEmpty, reason: code);
        expect(message, isNot(contains(code)), reason: 'nunca se muestra el codigo ($code)');
      }
    });

    test('cada code se mapea al mensaje de screens.md §6.1', () {
      expected.forEach((code, message) {
        expect(ApiException(code: code).userMessage, message, reason: code);
      });
    });

    test('codigos de negocio con texto propio de respaldo', () {
      expect(const ApiException(code: 'INSUFFICIENT_STOCK').userMessage, isNotEmpty);
      expect(const ApiException(code: 'PRICE_CHANGED').userMessage, contains('precio cambió'));
      expect(const ApiException(code: 'PIZZA_RULES_VIOLATED').userMessage, isNotEmpty);
      expect(const ApiException(code: 'INVALID_RECIPE').userMessage, isNotEmpty);
      expect(const ApiException(code: 'INGREDIENT_CATEGORY_LOCKED').userMessage, contains('categoría'));
      expect(const ApiException(code: 'TOKEN_EXPIRED').userMessage, isNotEmpty);
    });

    test('codigo desconocido -> mensaje generico sin mostrar el codigo', () {
      const e = ApiException(code: 'ALGO_NUEVO');
      expect(e.userMessage, 'Ocurrió un error inesperado. Inténtalo de nuevo.');
      expect(e.userMessage, isNot(contains('ALGO_NUEVO')));
    });

    test('sin respuesta (red/timeout) -> mensaje de conexion', () {
      final e = ApiException.fromDio(DioException(
          requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError));
      expect(e.isNetwork, isTrue);
      expect(e.userMessage, startsWith('No se pudo conectar con el servidor.'));
    });

    test('cancelacion se distingue de un error real', () {
      final e = ApiException.fromDio(
          DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.cancel));
      expect(e.isCancelled, isTrue);
    });

    test('parsea {error:{code,message,details}} del API', () {
      final e = ApiException.fromDio(_dioError(409, {
        'error': {
          'code': 'INSUFFICIENT_STOCK',
          'message': 'No hay stock suficiente de Queso mozzarella: solicitado 6, disponible 4.',
          'details': [
            {'ingredientId': 'i1', 'code': 'QUE-MOZ', 'name': 'Queso mozzarella', 'requested': 6, 'available': 4},
          ],
        },
      }));
      expect(e.code, 'INSUFFICIENT_STOCK');
      expect(e.statusCode, 409);
      expect(e.stockLines, ['No hay stock suficiente de Queso mozzarella: solicitado 6, disponible 4.']);
    });

    test('VALIDATION_ERROR: errores por campo', () {
      final e = ApiException.fromDio(_dioError(400, {
        'error': {
          'code': 'VALIDATION_ERROR',
          'message': 'x',
          'details': [
            {'path': 'password', 'message': 'La contraseña debe tener al menos 8 caracteres.'},
          ],
        },
      }));
      expect(e.fieldErrors['password'], 'La contraseña debe tener al menos 8 caracteres.');
    });

    test('PRICE_CHANGED: nuevo total desde details[0].quote.totals.total', () {
      final e = ApiException.fromDio(_dioError(409, {
        'error': {
          'code': 'PRICE_CHANGED',
          'message': 'x',
          'details': [
            {'quote': {'items': [], 'totals': {'total': '22.00'}}},
          ],
        },
      }));
      expect(e.newTotalFromPriceChanged, '22.00');
    });

    test('503 sin cuerpo -> SERVICE_UNAVAILABLE; 500 sin cuerpo -> INTERNAL_ERROR', () {
      DioException bare(int s) => DioException(
            requestOptions: RequestOptions(path: '/x'),
            response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: s, data: 'oops'),
            type: DioExceptionType.badResponse,
          );
      expect(ApiException.fromDio(bare(503)).code, 'SERVICE_UNAVAILABLE');
      expect(ApiException.fromDio(bare(500)).code, 'INTERNAL_ERROR');
    });
  });

  group('violaciones de armado (screens.md §6.2)', () {
    test('los 15 codigos del contrato tienen texto de respaldo en espanol', () {
      expect(knownViolationCodes.length, 15);
      for (final code in knownViolationCodes) {
        expect(hasFallbackFor(code), isTrue, reason: code);
        expect(violationText(Violation(code: code, message: '')), isNotEmpty);
      }
    });
    test('se prefiere el mensaje del servidor', () {
      expect(
        violationText(const Violation(
            code: 'MAX_PORTIONS_EXCEEDED', message: 'Máximo 3 porciones por ingrediente (Queso mozzarella: 4).')),
        'Máximo 3 porciones por ingrediente (Queso mozzarella: 4).',
      );
    });
  });
}
