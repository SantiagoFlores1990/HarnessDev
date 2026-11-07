import { ORDER_NUMBER_PREFIX } from '../config/constants.js';

/** GP-AAAAMMDD-NNNN; si el correlativo supera 9999 crece a 5 dígitos (no se trunca). */
export function formatOrderNumber(ymd, sequence) {
  return `${ORDER_NUMBER_PREFIX}-${ymd.replaceAll('-', '')}-${String(sequence).padStart(4, '0')}`;
}
