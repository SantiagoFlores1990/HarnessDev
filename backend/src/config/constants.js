// Reglas de negocio fijas (prompt del proyecto + supuestos S-xx).
export const MAX_PORTIONS_PER_INGREDIENT = 3;
export const MIN_DISTINCT_TOPPINGS = 3;
export const MAX_PIZZAS_PER_LINE = 20;
export const MAX_ITEMS_PER_ORDER = 50;
export const MAX_TOPPINGS_PER_PIZZA = 30;
export const ORDER_NUMBER_PREFIX = 'GP';
export const VAT_STANDARD_PERCENT = 15;
export const MAX_STOCK_VALUE = 1_000_000; // límite técnico para evitar desbordar INT4

export const SIZE_CODES = ['INDIVIDUAL', 'MEDIUM', 'FAMILY'];
export const CATEGORY_CODES = ['DOUGH', 'SAUCE', 'CHEESE', 'MEAT', 'VEGETABLE', 'OTHER'];
export const TOPPING_CATEGORY_CODES = ['CHEESE', 'MEAT', 'VEGETABLE', 'OTHER'];
export const VAT_CODES = ['VAT_15', 'VAT_0'];
export const ORDER_STATUSES = ['PENDING', 'IN_PREPARATION', 'DELIVERED'];

// Transiciones válidas de estado (solo hacia adelante).
export const STATUS_TRANSITIONS = {
  PENDING: ['IN_PREPARATION'],
  IN_PREPARATION: ['DELIVERED'],
  DELIVERED: [],
};

export const ROLES = { ADMIN: 'ADMIN', CLIENT: 'CLIENT' };
