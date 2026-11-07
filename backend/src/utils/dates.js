const pad = (n, len = 2) => String(n).padStart(len, '0');

/** Fecha local del servidor como YYYY-MM-DD (S-24). */
export function localDateString(date = new Date()) {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

/** YYYY-MM-DD -> Date UTC medianoche (para columnas @db.Date). */
export const dateOnlyToDate = (ymd) => new Date(`${ymd}T00:00:00.000Z`);

/** Date de columna @db.Date -> YYYY-MM-DD. */
export const dateToDateOnly = (date) => date.toISOString().slice(0, 10);

export const toIso = (date) => (date ? date.toISOString() : null);
