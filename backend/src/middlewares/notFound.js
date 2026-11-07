import { AppError } from "../utils/AppError.js";

export const notFoundRoute = (req, _res, next) =>
  next(
    new AppError(
      404,
      "ROUTE_NOT_FOUND",
      `Ruta no encontrada: ${req.method} ${req.path}`,
    ),
  );
