import rateLimit from "express-rate-limit";
import { AppError } from "../utils/AppError.js";

const handler = (_req, _res, next) =>
  next(
    new AppError(
      429,
      "RATE_LIMITED",
      "Demasiadas solicitudes. Intenta de nuevo en unos minutos.",
    ),
  );

export const createLimiter = ({ windowMs, max }) =>
  rateLimit({
    windowMs,
    max,
    standardHeaders: true,
    legacyHeaders: false,
    handler,
  });

export const createGlobalLimiter = (env) =>
  createLimiter({
    windowMs: env.RATE_LIMIT_WINDOW_MS,
    max: env.RATE_LIMIT_MAX,
  });

export const createAuthLimiter = (env) =>
  createLimiter({
    windowMs: env.RATE_LIMIT_WINDOW_MS,
    max: env.AUTH_RATE_LIMIT_MAX,
  });
