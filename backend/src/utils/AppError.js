export class AppError extends Error {
  /**
   * @param {number} status HTTP status
   * @param {string} code constante del contrato (api-contract §1.2)
   * @param {string} message texto en español para el usuario
   * @param {Array} details arreglo (puede estar vacío)
   */
  constructor(status, code, message, details = []) {
    super(message);
    this.name = 'AppError';
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

export const notFound = (message = 'Recurso no encontrado.') => new AppError(404, 'NOT_FOUND', message);
export const forbidden = (message = 'No tienes permiso para realizar esta acción.') =>
  new AppError(403, 'FORBIDDEN', message);
