/** Fábrica de violaciones (api-contract §1.3). */
export function violation(
  code,
  message,
  { itemIndex = null, ingredientId = null, meta = {} } = {},
) {
  return { code, message, itemIndex, ingredientId, meta };
}
