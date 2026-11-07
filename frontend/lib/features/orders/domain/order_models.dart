/// Tipos de pizza en un item del pedido.
abstract final class PizzaTypes {
  static const custom = 'CUSTOM';
  static const preset = 'PRESET';
}

/// Estados del pedido (Pendiente -> En preparacion -> Entregado).
enum OrderStatus {
  pending('PENDING', 'Pendiente'),
  inPreparation('IN_PREPARATION', 'En preparación'),
  delivered('DELIVERED', 'Entregado');

  const OrderStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static OrderStatus fromApi(String value) =>
      OrderStatus.values.firstWhere((s) => s.apiValue == value, orElse: () => pending);

  /// Siguiente estado permitido, o null si ya esta entregado.
  OrderStatus? get next => switch (this) {
        OrderStatus.pending => OrderStatus.inPreparation,
        OrderStatus.inPreparation => OrderStatus.delivered,
        OrderStatus.delivered => null,
      };
}

/// Porciones de un ingrediente enviadas al API (toppings o extras).
class PortionInput {
  const PortionInput({required this.ingredientId, required this.portions});
  final String ingredientId;
  final int portions;

  Map<String, dynamic> toJson() => {'ingredientId': ingredientId, 'portions': portions};
}

/// Item de pizza para `/orders/quote` y `/orders` (PizzaItemInput del contrato).
class PizzaItemInput {
  const PizzaItemInput({
    required this.type,
    required this.sizeCode,
    this.doughId,
    this.sauceId,
    this.toppings = const [],
    this.presetPizzaId,
    this.extras = const [],
    this.quantity = 1,
  });

  final String type;
  final String sizeCode;
  final String? doughId;
  final String? sauceId;
  final List<PortionInput> toppings;
  final String? presetPizzaId;
  final List<PortionInput> extras;
  final int quantity;

  bool get isPreset => type == PizzaTypes.preset;

  /// Una linea predefinida sin extras puede fusionarse con otra igual (suma cantidad).
  bool canMergeWith(PizzaItemInput other) =>
      isPreset &&
      other.isPreset &&
      extras.isEmpty &&
      other.extras.isEmpty &&
      presetPizzaId == other.presetPizzaId &&
      sizeCode == other.sizeCode;

  PizzaItemInput withQuantity(int q) => PizzaItemInput(
        type: type,
        sizeCode: sizeCode,
        doughId: doughId,
        sauceId: sauceId,
        toppings: toppings,
        presetPizzaId: presetPizzaId,
        extras: extras,
        quantity: q,
      );

  PizzaItemInput withSize(String code) => PizzaItemInput(
        type: type,
        sizeCode: code,
        doughId: doughId,
        sauceId: sauceId,
        toppings: toppings,
        presetPizzaId: presetPizzaId,
        extras: extras,
        quantity: quantity,
      );

  Map<String, dynamic> toJson() {
    if (isPreset) {
      return {
        'type': type,
        'presetPizzaId': presetPizzaId,
        'sizeCode': sizeCode,
        'extras': extras.map((e) => e.toJson()).toList(),
        'quantity': quantity,
      };
    }
    return {
      'type': type,
      'sizeCode': sizeCode,
      if (doughId != null) 'doughId': doughId,
      if (sauceId != null) 'sauceId': sauceId,
      'toppings': toppings.map((e) => e.toJson()).toList(),
      'quantity': quantity,
    };
  }
}

/// Violacion de reglas de armado (api-contract.md §1.3).
class Violation {
  const Violation({
    required this.code,
    required this.message,
    this.itemIndex,
    this.ingredientId,
    this.meta = const {},
  });
  final String code;
  final String message;
  final int? itemIndex;
  final String? ingredientId;
  final Map<String, dynamic> meta;

  factory Violation.fromJson(Map<String, dynamic> json) => Violation(
        code: json['code'] as String? ?? '',
        message: json['message'] as String? ?? '',
        itemIndex: (json['itemIndex'] as num?)?.toInt(),
        ingredientId: json['ingredientId'] as String?,
        meta: json['meta'] is Map ? Map<String, dynamic>.from(json['meta'] as Map) : const {},
      );

  static List<Violation> listFrom(Object? raw) => ((raw as List?) ?? const [])
      .whereType<Map>()
      .map((e) => Violation.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

/// Componente (masa, salsa o ingrediente) de una pizza valorada.
class PricedComponent {
  const PricedComponent({
    required this.ingredientId,
    required this.code,
    required this.name,
    required this.component,
    required this.categoryCode,
    required this.recipePortions,
    required this.portions,
    required this.unitPrice,
    required this.unitCalories,
    required this.vatRatePercent,
    required this.lineAmount,
    required this.lineCalories,
  });
  final String ingredientId;
  final String code;
  final String name;
  final String component;
  final String categoryCode;
  final int recipePortions;
  final int portions;
  final String unitPrice;
  final int unitCalories;
  final String vatRatePercent;
  final String lineAmount;
  final int lineCalories;

  int get extraPortions => portions - recipePortions;

  factory PricedComponent.fromJson(Map<String, dynamic> json) => PricedComponent(
        ingredientId: json['ingredientId'] as String? ?? '',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        component: json['component'] as String? ?? 'TOPPING',
        categoryCode: json['categoryCode'] as String? ?? '',
        recipePortions: (json['recipePortions'] as num?)?.toInt() ?? 0,
        portions: (json['portions'] as num?)?.toInt() ?? 1,
        unitPrice: json['unitPrice']?.toString() ?? '0.00',
        unitCalories: (json['unitCalories'] as num?)?.toInt() ?? 0,
        vatRatePercent: json['vatRatePercent']?.toString() ?? '0.00',
        lineAmount: json['lineAmount']?.toString() ?? '0.00',
        lineCalories: (json['lineCalories'] as num?)?.toInt() ?? 0,
      );
}

/// Referencia a la predefinida en un item (snapshot).
class PresetRef {
  const PresetRef({required this.id, required this.code, required this.name});
  final String id;
  final String code;
  final String name;

  factory PresetRef.fromJson(Map<String, dynamic> json) => PresetRef(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );
}

/// Pizza valorada (PricedPizza). En `OrderDetail` no trae `valid`/`violations`
/// y usa `lineNumber` (base 1) en lugar de `index` (base 0).
class PricedPizza {
  const PricedPizza({
    required this.index,
    required this.type,
    required this.presetPizza,
    required this.sizeCode,
    required this.sizeName,
    required this.quantity,
    required this.components,
    required this.unitPrice,
    required this.unitCalories,
    required this.unitSubtotalVat15,
    required this.unitSubtotalVat0,
    required this.lineSubtotal,
    required this.lineCalories,
    this.valid = true,
    this.violations = const [],
  });

  final int index;
  final String type;
  final PresetRef? presetPizza;
  final String sizeCode;
  final String sizeName;
  final int quantity;
  final List<PricedComponent> components;
  final String unitPrice;
  final int unitCalories;
  final String unitSubtotalVat15;
  final String unitSubtotalVat0;
  final String lineSubtotal;
  final int lineCalories;
  final bool valid;
  final List<Violation> violations;

  bool get isPreset => type == PizzaTypes.preset;

  /// "Personalizada" o "`nombre` (predefinida)".
  String get kindLabel =>
      isPreset ? '${presetPizza?.name ?? 'Predefinida'} (predefinida)' : 'Personalizada';

  factory PricedPizza.fromJson(Map<String, dynamic> json) {
    final size = (json['size'] as Map?) ?? const {};
    final index = json.containsKey('index')
        ? (json['index'] as num).toInt()
        : ((json['lineNumber'] as num?)?.toInt() ?? 1) - 1;
    return PricedPizza(
      index: index,
      type: json['type'] as String? ?? PizzaTypes.custom,
      presetPizza: json['presetPizza'] is Map
          ? PresetRef.fromJson(Map<String, dynamic>.from(json['presetPizza'] as Map))
          : null,
      sizeCode: size['code'] as String? ?? '',
      sizeName: size['name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      components: ((json['components'] as List?) ?? const [])
          .map((e) => PricedComponent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      unitPrice: json['unitPrice']?.toString() ?? '0.00',
      unitCalories: (json['unitCalories'] as num?)?.toInt() ?? 0,
      unitSubtotalVat15: json['unitSubtotalVat15']?.toString() ?? '0.00',
      unitSubtotalVat0: json['unitSubtotalVat0']?.toString() ?? '0.00',
      lineSubtotal: json['lineSubtotal']?.toString() ?? '0.00',
      lineCalories: (json['lineCalories'] as num?)?.toInt() ?? 0,
      valid: json['valid'] as bool? ?? true,
      violations: Violation.listFrom(json['violations']),
    );
  }
}

/// Totales del pedido (todos los valores vienen del API).
class Totals {
  const Totals({
    required this.subtotalVat15,
    required this.subtotalVat0,
    required this.vat15,
    required this.total,
    required this.totalCalories,
  });
  final String subtotalVat15;
  final String subtotalVat0;
  final String vat15;
  final String total;
  final int totalCalories;

  factory Totals.fromJson(Map<String, dynamic> json) => Totals(
        subtotalVat15: json['subtotalVat15']?.toString() ?? '0.00',
        subtotalVat0: json['subtotalVat0']?.toString() ?? '0.00',
        vat15: json['vat15']?.toString() ?? '0.00',
        total: json['total']?.toString() ?? '0.00',
        totalCalories: (json['totalCalories'] as num?)?.toInt() ?? 0,
      );
}

/// Requerimiento de stock agregado informado por la cotizacion.
class StockNeed {
  const StockNeed({
    required this.ingredientId,
    required this.name,
    required this.required,
    required this.available,
  });
  final String ingredientId;
  final String name;
  final int required;
  final int available;

  factory StockNeed.fromJson(Map<String, dynamic> json) => StockNeed(
        ingredientId: json['ingredientId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        required: (json['required'] as num?)?.toInt() ?? 0,
        available: (json['available'] as num?)?.toInt() ?? 0,
      );
}

/// Resultado de `POST /orders/quote`.
class QuoteResult {
  const QuoteResult({
    required this.valid,
    required this.violations,
    required this.items,
    required this.totals,
    this.stock = const [],
  });
  final bool valid;
  final List<Violation> violations;
  final List<PricedPizza> items;
  final Totals totals;
  final List<StockNeed> stock;

  factory QuoteResult.fromJson(Map<String, dynamic> json) => QuoteResult(
        valid: json['valid'] as bool? ?? false,
        violations: Violation.listFrom(json['violations']),
        items: ((json['items'] as List?) ?? const [])
            .map((e) => PricedPizza.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        totals: Totals.fromJson(Map<String, dynamic>.from((json['totals'] as Map?) ?? const {})),
        stock: ((json['stock'] as List?) ?? const [])
            .map((e) => StockNeed.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  /// Todas las violaciones (raiz + por item) para mostrar en el panel o banner.
  List<Violation> get allViolations => [
        for (final item in items) ...item.violations,
        ...violations,
      ];
}

/// Datos del cliente (snapshot).
class CustomerInfo {
  const CustomerInfo({required this.id, required this.fullName, required this.email});
  final String id;
  final String fullName;
  final String email;

  factory CustomerInfo.fromJson(Map<String, dynamic> json) => CustomerInfo(
        id: json['id'] as String? ?? '',
        fullName: json['fullName'] as String? ?? '',
        email: json['email'] as String? ?? '',
      );
}

/// Fila de lista de pedidos (OrderSummary).
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.orderNumber,
    required this.createdAt,
    required this.status,
    required this.customer,
    required this.pizzaCount,
    required this.totalCalories,
    required this.total,
  });
  final String id;
  final String orderNumber;
  final DateTime createdAt;
  final OrderStatus status;
  final CustomerInfo customer;
  final int pizzaCount;
  final int totalCalories;
  final String total;

  factory OrderSummary.fromJson(Map<String, dynamic> json) => OrderSummary(
        id: json['id'] as String,
        orderNumber: json['orderNumber'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        status: OrderStatus.fromApi(json['status'] as String),
        customer: CustomerInfo.fromJson(Map<String, dynamic>.from((json['customer'] as Map?) ?? const {})),
        pizzaCount: (json['pizzaCount'] as num?)?.toInt() ?? 0,
        totalCalories: (json['totalCalories'] as num?)?.toInt() ?? 0,
        total: json['total']?.toString() ?? '0.00',
      );
}

/// Entrada del historial de estados.
class StatusHistoryEntry {
  const StatusHistoryEntry({
    required this.fromStatus,
    required this.toStatus,
    required this.changedAt,
    required this.changedByName,
  });
  final OrderStatus? fromStatus;
  final OrderStatus toStatus;
  final DateTime changedAt;
  final String? changedByName;

  factory StatusHistoryEntry.fromJson(Map<String, dynamic> json) => StatusHistoryEntry(
        fromStatus: json['fromStatus'] == null ? null : OrderStatus.fromApi(json['fromStatus'] as String),
        toStatus: OrderStatus.fromApi(json['toStatus'] as String),
        changedAt: DateTime.parse(json['changedAt'] as String),
        changedByName: json['changedBy'] is Map ? (json['changedBy'] as Map)['fullName'] as String? : null,
      );
}

/// Comprobante completo (OrderDetail), construido solo con snapshots.
class OrderDetail {
  const OrderDetail({
    required this.summary,
    required this.statusChangedAt,
    required this.pizzas,
    required this.totals,
    required this.statusHistory,
  });
  final OrderSummary summary;
  final DateTime statusChangedAt;
  final List<PricedPizza> pizzas;
  final Totals totals;
  final List<StatusHistoryEntry> statusHistory;

  String get id => summary.id;
  String get orderNumber => summary.orderNumber;
  OrderStatus get status => summary.status;
  CustomerInfo get customer => summary.customer;
  DateTime get createdAt => summary.createdAt;

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final summary = OrderSummary.fromJson(json);
    return OrderDetail(
      summary: summary,
      statusChangedAt: json['statusChangedAt'] == null
          ? summary.createdAt
          : DateTime.parse(json['statusChangedAt'] as String),
      pizzas: ((json['pizzas'] as List?) ?? const [])
          .map((e) => PricedPizza.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      totals: Totals.fromJson(Map<String, dynamic>.from((json['totals'] as Map?) ?? const {})),
      statusHistory: ((json['statusHistory'] as List?) ?? const [])
          .map((e) => StatusHistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
