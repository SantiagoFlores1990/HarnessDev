import { ZodError } from "zod";
import { Prisma } from "@prisma/client";
import { AppError } from "../utils/AppError.js";
import { logger } from "../lib/logger.js";

const body = (code, message, details = []) => ({
  error: { code, message, details },
});

/** Traduce ZodError a la lista de detalles del contrato. */
export function zodDetails(err) {
  return err.issues.map((i) => ({
    path: i.path.join("."),
    message: i.message,
  }));
}

// Middleware central: todo error sale como { error: { code, message, details } } (api-contract §1.1).
export function errorHandler(err, req, res, _next) {
  if (err instanceof AppError) {
    return res
      .status(err.status)
      .json(body(err.code, err.message, err.details));
  }
  if (err instanceof ZodError) {
    const details = zodDetails(err);
    const message =
      details.length === 1
        ? `Los datos enviados no son válidos: ${details[0].message}`
        : "Los datos enviados no son válidos.";
    return res.status(400).json(body("VALIDATION_ERROR", message, details));
  }
  // body-parser: JSON mal formado o cuerpo demasiado grande
  if (err?.type === "entity.parse.failed") {
    return res
      .status(400)
      .json(
        body(
          "VALIDATION_ERROR",
          "El cuerpo de la solicitud no es JSON válido.",
        ),
      );
  }
  if (err?.type === "entity.too.large") {
    return res
      .status(400)
      .json(
        body(
          "VALIDATION_ERROR",
          "El cuerpo de la solicitud supera el límite de 100 KB.",
        ),
      );
  }
  if (
    err instanceof Prisma.PrismaClientKnownRequestError &&
    err.code === "P2025"
  ) {
    return res.status(404).json(body("NOT_FOUND", "Recurso no encontrado."));
  }
  logger.error(
    {
      err: { name: err?.name, message: err?.message, stack: err?.stack },
      path: req.path,
    },
    "Error no controlado",
  );
  return res
    .status(500)
    .json(
      body("INTERNAL_ERROR", "Ocurrió un error inesperado. Intenta de nuevo."),
    );
}
